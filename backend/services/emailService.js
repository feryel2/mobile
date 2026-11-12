const nodemailer = require('nodemailer');

const getTransporter = () => {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
  if (!SMTP_HOST || !SMTP_PORT || !SMTP_USER || !SMTP_PASS) {
    const error = new Error('Le service email n’est pas configuré. Renseignez les paramètres SMTP dans le fichier .env.');
    error.code = 'EMAIL_NOT_CONFIGURED';
    throw error;
  }

  return nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT),
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user: SMTP_USER, pass: SMTP_PASS }
  });
};

exports.sendVerificationCode = async (email, code) => {
  const transporter = getTransporter();
  await transporter.sendMail({
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to: email,
    subject: 'Votre code de vérification CarRent',
    text: `Votre code CarRent est ${code}. Il expire dans 10 minutes. Si vous n’êtes pas à l’origine de cette demande, ignorez cet email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;color:#1e293b"><h1 style="color:#0052cc">CarRent</h1><p>Utilisez ce code pour vérifier votre adresse email et créer votre compte :</p><p style="font-size:30px;font-weight:bold;letter-spacing:8px;color:#0052cc">${code}</p><p>Ce code expire dans 10 minutes. Si vous n’êtes pas à l’origine de cette demande, ignorez cet email.</p></div>`
  });
};

exports.sendPasswordResetCode = async (email, code) => {
  const transporter = getTransporter();
  await transporter.sendMail({
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to: email,
    subject: 'Réinitialisation de votre mot de passe CarRent',
    text: `Votre code de réinitialisation CarRent est ${code}. Il expire dans 10 minutes. Si vous n’êtes pas à l’origine de cette demande, ignorez cet email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;color:#1e293b"><h1 style="color:#0052cc">CarRent</h1><p>Utilisez ce code pour réinitialiser votre mot de passe :</p><p style="font-size:30px;font-weight:bold;letter-spacing:8px;color:#0052cc">${code}</p><p>Ce code expire dans 10 minutes. Si vous n’êtes pas à l’origine de cette demande, ignorez cet email.</p></div>`
  });
};
