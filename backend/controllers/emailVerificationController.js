const crypto = require('crypto');
const EmailVerification = require('../models/EmailVerification');
const User = require('../models/User');
const { sendVerificationCode } = require('../services/emailService');

const emailPattern = /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,})+$/;
const codeLifetimeMs = 10 * 60 * 1000;
const resendDelayMs = 60 * 1000;
const maxAttempts = 5;
const ipWindowMs = 15 * 60 * 1000;
const maxRequestsPerIp = 10;
const ipRequests = new Map();

const hashCode = (email, code) => crypto
  .createHmac('sha256', process.env.EMAIL_VERIFICATION_SECRET || process.env.JWT_SECRET || '')
  .update(`${email}:${code}`)
  .digest('hex');

exports.sendCode = async (req, res) => {
  try {
    const now = Date.now();
    for (const [ip, request] of ipRequests) {
      if (now - request.windowStart >= ipWindowMs) ipRequests.delete(ip);
    }
    const ip = req.ip;
    const request = ipRequests.get(ip);
    if (request && now - request.windowStart < ipWindowMs) {
      if (request.count >= maxRequestsPerIp) {
        return res.status(429).json({
          success: false,
          message: 'Trop de demandes depuis cette connexion. Réessayez dans quelques minutes.'
        });
      }
      request.count += 1;
    } else {
      ipRequests.set(ip, { windowStart: now, count: 1 });
    }

    const email = typeof req.body.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : '';
    if (!emailPattern.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez saisir une adresse email valide.'
      });
    }

    if (await User.exists({ email })) {
      return res.status(409).json({
        success: false,
        message: 'Un compte existe déjà avec cette adresse email.'
      });
    }

    const nowDate = new Date();
    const existing = await EmailVerification.findOne({ email });
    if (existing && nowDate.getTime() - existing.lastSentAt.getTime() < resendDelayMs) {
      return res.status(429).json({
        success: false,
        message: 'Veuillez attendre une minute avant de demander un nouveau code.'
      });
    }

    const code = crypto.randomInt(0, 1000000).toString().padStart(6, '0');
    await EmailVerification.findOneAndUpdate(
      { email },
      {
        email,
        codeHash: hashCode(email, code),
        expiresAt: new Date(nowDate.getTime() + codeLifetimeMs),
        lastSentAt: nowDate,
        attempts: 0
      },
      { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true }
    );

    try {
      await sendVerificationCode(email, code);
    } catch (error) {
      await EmailVerification.deleteOne({ email, codeHash: hashCode(email, code) });
      if (error.code === 'EMAIL_NOT_CONFIGURED') {
        return res.status(503).json({
          success: false,
          message: error.message
        });
      }
      console.error('Échec de l’envoi du code de vérification :', error.message);
      return res.status(502).json({
        success: false,
        message: 'Impossible d’envoyer le code de vérification. Vérifiez la configuration email ou réessayez plus tard.'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Un code de vérification a été envoyé à votre adresse email.',
      expiresInSeconds: codeLifetimeMs / 1000,
      resendAfterSeconds: resendDelayMs / 1000
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de l’envoi du code de vérification.',
      error: error.message
    });
  }
};

exports.consumeCode = async (email, code) => {
  const verification = await EmailVerification.findOne({ email });
  if (!verification || verification.expiresAt <= new Date()) {
    return { valid: false, message: 'Code expiré ou introuvable. Demandez un nouveau code.' };
  }
  if (verification.attempts >= maxAttempts) {
    return { valid: false, message: 'Trop de tentatives. Demandez un nouveau code.' };
  }

  const candidateHash = Buffer.from(hashCode(email, code), 'hex');
  const savedHash = Buffer.from(verification.codeHash, 'hex');
  if (
    candidateHash.length !== savedHash.length
    || !crypto.timingSafeEqual(candidateHash, savedHash)
  ) {
    verification.attempts += 1;
    await verification.save();
    const attemptsLeft = Math.max(0, maxAttempts - verification.attempts);
    return {
      valid: false,
      message: attemptsLeft
        ? `Code incorrect. Il vous reste ${attemptsLeft} tentative(s).`
        : 'Trop de tentatives. Demandez un nouveau code.'
    };
  }

  return { valid: true, verification };
};
