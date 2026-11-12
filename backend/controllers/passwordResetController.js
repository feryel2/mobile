const crypto = require('crypto');
const User = require('../models/User');
const PasswordResetCode = require('../models/PasswordResetCode');
const emailService = require('../services/emailService');

const emailPattern = /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,})+$/;
const codeLifetimeMs = 10 * 60 * 1000;
const resendDelayMs = 60 * 1000;
const maxAttempts = 5;
const ipWindowMs = 15 * 60 * 1000;
const maxRequestsPerIp = 10;
const ipRequests = new Map();
const genericMessage =
  'Si un compte correspond à cette adresse, un code de réinitialisation sera envoyé.';

function hashCode(email, code) {
  const secret = process.env.PASSWORD_RESET_SECRET
    || process.env.EMAIL_VERIFICATION_SECRET
    || process.env.JWT_SECRET
    || '';
  return crypto.createHmac('sha256', secret).update(`${email}:${code}`).digest('hex');
}

function allowIpRequest(ip, now) {
  for (const [key, request] of ipRequests) {
    if (now - request.windowStart >= ipWindowMs) ipRequests.delete(key);
  }

  const key = ip || 'unknown';
  const request = ipRequests.get(key);
  if (request && now - request.windowStart < ipWindowMs) {
    if (request.count >= maxRequestsPerIp) return false;
    request.count += 1;
  } else {
    ipRequests.set(key, { windowStart: now, count: 1 });
  }
  return true;
}

function invalidCodeResponse(res) {
  return res.status(400).json({
    success: false,
    message: 'Code invalide ou expiré. Demandez un nouveau code.'
  });
}

exports.sendCode = async (req, res) => {
  try {
    const now = Date.now();
    if (!allowIpRequest(req.ip || req.socket?.remoteAddress, now)) {
      return res.status(429).json({
        success: false,
        message: 'Trop de demandes. Réessayez dans quelques minutes.'
      });
    }

    const submittedEmail = req.body?.email;
    const email = typeof submittedEmail === 'string'
      ? submittedEmail.trim().toLowerCase()
      : '';
    if (!emailPattern.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez saisir une adresse email valide.'
      });
    }

    if (
      !process.env.SMTP_HOST
      || !process.env.SMTP_PORT
      || !process.env.SMTP_USER
      || !process.env.SMTP_PASS
    ) {
      return res.status(503).json({
        success: false,
        message: 'Le service email n’est pas configuré.'
      });
    }

    const userExists = await User.exists({ email });
    if (!userExists) {
      return res.status(200).json({
        success: true,
        message: genericMessage,
        resendAfterSeconds: resendDelayMs / 1000
      });
    }

    const nowDate = new Date(now);
    const existing = await PasswordResetCode.findOne({ email });
    if (existing && nowDate.getTime() - existing.lastSentAt.getTime() < resendDelayMs) {
      return res.status(200).json({
        success: true,
        message: genericMessage,
        resendAfterSeconds: resendDelayMs / 1000
      });
    }

    const code = crypto.randomInt(0, 1000000).toString().padStart(6, '0');
    const codeHash = hashCode(email, code);
    await PasswordResetCode.findOneAndUpdate(
      { email },
      {
        email,
        codeHash,
        expiresAt: new Date(now + codeLifetimeMs),
        lastSentAt: nowDate,
        attempts: 0
      },
      { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true }
    );

    try {
      await emailService.sendPasswordResetCode(email, code);
    } catch (error) {
      await PasswordResetCode.deleteOne({ email, codeHash });
      if (error.code === 'EMAIL_NOT_CONFIGURED') {
        return res.status(503).json({
          success: false,
          message: error.message
        });
      }
      console.error('Échec de l’envoi du code de réinitialisation :', error.message);
      return res.status(502).json({
        success: false,
        message: 'Impossible d’envoyer le code. Vérifiez la configuration email ou réessayez plus tard.'
      });
    }

    return res.status(200).json({
      success: true,
      message: genericMessage,
      expiresInSeconds: codeLifetimeMs / 1000,
      resendAfterSeconds: resendDelayMs / 1000
    });
  } catch (error) {
    console.error('Erreur lors de la demande de réinitialisation :', error.message);
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la demande de réinitialisation.'
    });
  }
};

exports.resetPassword = async (req, res) => {
  try {
    const submittedEmail = req.body?.email;
    const email = typeof submittedEmail === 'string'
      ? submittedEmail.trim().toLowerCase()
      : '';
    const { code, newPassword } = req.body || {};

    if (!emailPattern.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez saisir une adresse email valide.'
      });
    }
    if (typeof code !== 'string' || !/^\d{6}$/.test(code)) {
      return res.status(400).json({
        success: false,
        message: 'Saisissez le code à 6 chiffres reçu par email.'
      });
    }
    if (typeof newPassword !== 'string' || newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Le nouveau mot de passe doit comporter au moins 6 caractères.'
      });
    }

    const resetCode = await PasswordResetCode.findOne({ email });
    const now = new Date();
    if (
      !resetCode
      || resetCode.expiresAt <= now
      || resetCode.attempts >= maxAttempts
    ) {
      return invalidCodeResponse(res);
    }

    const candidateHash = Buffer.from(hashCode(email, code), 'hex');
    const savedHash = Buffer.from(resetCode.codeHash, 'hex');
    if (
      candidateHash.length !== savedHash.length
      || !crypto.timingSafeEqual(candidateHash, savedHash)
    ) {
      await PasswordResetCode.updateOne(
        {
          _id: resetCode._id,
          attempts: { $lt: maxAttempts },
          expiresAt: { $gt: now }
        },
        { $inc: { attempts: 1 } }
      );
      return invalidCodeResponse(res);
    }

    const user = await User.findOne({ email });
    if (!user) {
      await PasswordResetCode.deleteOne({ _id: resetCode._id });
      return invalidCodeResponse(res);
    }

    const consumed = await PasswordResetCode.deleteOne({
      _id: resetCode._id,
      codeHash: resetCode.codeHash,
      attempts: { $lt: maxAttempts },
      expiresAt: { $gt: now }
    });
    if (consumed.deletedCount !== 1) return invalidCodeResponse(res);

    user.password = newPassword;
    await user.save();

    return res.status(200).json({
      success: true,
      message: 'Mot de passe réinitialisé. Vous pouvez maintenant vous connecter.'
    });
  } catch (error) {
    console.error('Erreur lors de la réinitialisation du mot de passe :', error.message);
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la réinitialisation du mot de passe.'
    });
  }
};
