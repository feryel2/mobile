const crypto = require('crypto');
const User = require('../models/User');
const AdminLoginTicket = require('../models/AdminLoginTicket');
const EmailVerification = require('../models/EmailVerification');
const { consumeCode } = require('./emailVerificationController');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const emailPattern = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
const adminLoginTicketLifetimeMs = 60 * 1000;

function isValidPhone(phone) {
  const digits = phone.replace(/\D/g, '');
  return /^[+()\d.\-\s]+$/.test(phone) && digits.length >= 7 && digits.length <= 15;
}

function hashAdminLoginTicket(ticket) {
  return crypto.createHash('sha256').update(ticket).digest('hex');
}

// Générateur de Token JWT
const generateToken = (userId, role) => {
  return jwt.sign(
    { id: userId, role: role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

// 1. Inscription d'un nouveau client (POST /api/users/register)
exports.register = async (req, res) => {
  try {
    const {
      fullname,
      email: submittedEmail,
      password,
      phone,
      driverLicenseNumber,
      emailVerificationCode
    } = req.body;
    const email = typeof submittedEmail === 'string'
      ? submittedEmail.trim().toLowerCase()
      : '';

    if (
      typeof fullname !== 'string' || !fullname.trim()
      || !email || typeof password !== 'string' || !password
      || typeof phone !== 'string' || !phone.trim()
    ) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez remplir tous les champs obligatoires (nom, email, mot de passe, téléphone).'
      });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Un compte existe déjà avec cette adresse email.'
      });
    }

    if (typeof emailVerificationCode !== 'string' || !/^\d{6}$/.test(emailVerificationCode)) {
      return res.status(400).json({
        success: false,
        message: 'Saisissez le code de vérification reçu par email.'
      });
    }

    const verification = await consumeCode(email, emailVerificationCode);
    if (!verification.valid) {
      return res.status(400).json({
        success: false,
        message: verification.message
      });
    }

    const newUser = new User({
      fullname: fullname.trim(),
      email,
      password,
      phone: phone.trim(),
      emailVerified: true,
      driverLicense: {
        number: typeof driverLicenseNumber === 'string' ? driverLicenseNumber.trim() : ''
      },
      status: typeof driverLicenseNumber === 'string' && driverLicenseNumber.trim()
        ? 'pending_approval'
        : 'active'
    });

    await newUser.save();
    await EmailVerification.deleteOne({ _id: verification.verification._id });

    const token = generateToken(newUser._id, newUser.role);

    return res.status(201).json({
      success: true,
      message: 'Inscription réussie avec succès !',
      token,
      user: newUser
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Un compte existe déjà avec cette adresse email.'
      });
    }
    if (error instanceof mongoose.Error.ValidationError) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
    return res.status(500).json({
      success: false,
      message: "Erreur lors de l'inscription.",
      error: error.message
    });
  }
};

// 2. Connexion d'un utilisateur (POST /api/users/login)
exports.login = async (req, res) => {
  try {
    const { email: submittedEmail, password } = req.body;
    const email = typeof submittedEmail === 'string'
      ? submittedEmail.trim().toLowerCase()
      : '';

    console.log(`Tentative de connexion reçue pour l'email: "${email}"`);

    if (!email || !password) {
      console.log('Login échoué : email ou mot de passe manquant');
      return res.status(400).json({
        success: false,
        message: 'Veuillez saisir votre email et votre mot de passe.'
      });
    }

    const user = await User.findOne({ email });
    if (!user) {
      console.log(`Login échoué : utilisateur introuvable pour "${email}"`);
      return res.status(401).json({
        success: false,
        message: 'Identifiants invalides (email ou mot de passe incorrect).'
      });
    }

    const isMatch = await user.comparePassword(password);
    console.log(`Résultat comparaison mot de passe pour "${email}": ${isMatch}`);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Identifiants invalides (email ou mot de passe incorrect).'
      });
    }

    if (user.status === 'suspended') {
      return res.status(403).json({
        success: false,
        message: 'Votre compte a été suspendu par un administrateur.'
      });
    }

    if (user.emailVerified === false) {
      return res.status(403).json({
        success: false,
        message: 'Votre adresse email doit être vérifiée avant de vous connecter.'
      });
    }

    const token = generateToken(user._id, user.role);

    return res.status(200).json({
      success: true,
      message: 'Connexion réussie',
      token,
      user
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la connexion.',
      error: error.message
    });
  }
};

exports.createAdminLoginTicket = async (req, res) => {
  if (req.user?.role !== 'admin' || req.user.status !== 'active') {
    return res.status(403).json({
      success: false,
      message: 'Un compte administrateur actif est nécessaire.'
    });
  }

  try {
    const now = new Date();
    const ticket = crypto.randomBytes(32).toString('hex');
    await AdminLoginTicket.deleteMany({ expiresAt: { $lte: now } });
    await AdminLoginTicket.create({
      ticketHash: hashAdminLoginTicket(ticket),
      userId: req.user._id,
      expiresAt: new Date(now.getTime() + adminLoginTicketLifetimeMs)
    });
    return res.status(201).json({
      success: true,
      ticket
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Impossible de préparer la connexion au tableau de bord.'
    });
  }
};

exports.consumeAdminLoginTicket = async (req, res) => {
  const { ticket } = req.body || {};
  if (typeof ticket !== 'string' || !/^[a-f0-9]{64}$/i.test(ticket)) {
    return res.status(400).json({
      success: false,
      message: 'Lien de connexion administrateur invalide ou expiré.'
    });
  }

  try {
    const loginTicket = await AdminLoginTicket.findOneAndDelete({
      ticketHash: hashAdminLoginTicket(ticket),
      expiresAt: { $gt: new Date() }
    });
    if (!loginTicket) {
      return res.status(401).json({
        success: false,
        message: 'Lien de connexion administrateur invalide ou expiré.'
      });
    }

    const user = await User.findById(loginTicket.userId);
    if (!user || user.role !== 'admin' || user.status !== 'active') {
      return res.status(401).json({
        success: false,
        message: 'Le compte administrateur n’est plus autorisé.'
      });
    }

    return res.status(200).json({
      success: true,
      token: generateToken(user._id, user.role)
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Impossible de finaliser la connexion administrateur.'
    });
  }
};

// 3. Récupération du profil connecté (GET /api/users/profile)
exports.getProfile = async (req, res) => {
  try {
    // req.user est déjà alimenté par le middleware protect
    return res.status(200).json({
      success: true,
      user: req.user
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération du profil.',
      error: error.message
    });
  }
};

// 4. Mise à jour du profil (PUT /api/users/profile)
exports.updateProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    const {
      fullname,
      email,
      phone,
      driverLicenseNumber,
      driverLicenseIssuedDate
    } = req.body;
    for (const [field, value] of Object.entries({ fullname, email, phone, driverLicenseNumber })) {
      if (value !== undefined && typeof value !== 'string') {
        return res.status(400).json({
          success: false,
          message: `Le champ ${field} doit être une chaîne de caractères.`
        });
      }
    }
    let licenseChanged = false;

    if (fullname !== undefined) user.fullname = fullname.trim();
    if (phone !== undefined) user.phone = phone.trim();
    if (email !== undefined) {
      const normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail !== user.email) {
        return res.status(400).json({
          success: false,
          message: 'Vérifiez la nouvelle adresse email avant de la modifier.'
        });
      }
    }

    if (driverLicenseNumber !== undefined) {
      const number = driverLicenseNumber.trim();
      licenseChanged ||= number !== user.driverLicense.number;
      user.driverLicense.number = number;
    }
    if (driverLicenseIssuedDate !== undefined) {
      const issuedDate = driverLicenseIssuedDate ? new Date(driverLicenseIssuedDate) : null;
      if (issuedDate && Number.isNaN(issuedDate.getTime())) {
        return res.status(400).json({
          success: false,
          message: 'La date de délivrance du permis est invalide.'
        });
      }
      licenseChanged ||= (issuedDate?.getTime() ?? null)
        !== (user.driverLicense.issuedDate?.getTime() ?? null);
      user.driverLicense.issuedDate = issuedDate;
    }

    // Gestion des fichiers uploadés par Multer
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    if (req.files) {
      if (req.files.avatar && req.files.avatar.length > 0) {
        user.avatar = `${baseUrl}/uploads/${req.files.avatar[0].filename}`;
      }
      if (req.files.driverLicensePhoto && req.files.driverLicensePhoto.length > 0) {
        user.driverLicense.photoUrl = `${baseUrl}/uploads/${req.files.driverLicensePhoto[0].filename}`;
        licenseChanged = true;
      }
    }

    if (licenseChanged && user.status !== 'suspended') {
      user.status = 'pending_approval';
    }

    await user.save();

    return res.status(200).json({
      success: true,
      message: 'Profil mis à jour avec succès',
      user
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Cette adresse email est déjà utilisée.'
      });
    }
    if (error instanceof mongoose.Error.ValidationError) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise à jour du profil.',
      error: error.message
    });
  }
};

exports.changeEmail = async (req, res) => {
  try {
    const email = typeof req.body.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : '';
    const { code } = req.body;

    if (!emailPattern.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez saisir une adresse email valide.'
      });
    }
    if (typeof code !== 'string' || !/^\d{6}$/.test(code)) {
      return res.status(400).json({
        success: false,
        message: 'Saisissez le code de vérification à 6 chiffres.'
      });
    }
    if (email === req.user.email) {
      return res.status(400).json({
        success: false,
        message: 'Cette adresse email est déjà associée à votre compte.'
      });
    }

    const existingEmail = await User.findOne({
      email,
      _id: { $ne: req.user._id }
    }).select('_id');
    if (existingEmail) {
      return res.status(409).json({
        success: false,
        message: 'Cette adresse email est déjà utilisée.'
      });
    }

    const verification = await consumeCode(email, code);
    if (!verification.valid) {
      return res.status(400).json({
        success: false,
        message: verification.message
      });
    }

    req.user.email = email;
    req.user.emailVerified = true;
    await req.user.save();
    await EmailVerification.deleteOne({ _id: verification.verification._id });

    return res.status(200).json({
      success: true,
      message: 'Adresse email modifiée et vérifiée avec succès.',
      user: req.user
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Cette adresse email est déjà utilisée.'
      });
    }
    if (error instanceof mongoose.Error.ValidationError) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la modification de l’adresse email.',
      error: error.message
    });
  }
};

// 5. Modification du mot de passe (PUT /api/users/change-password)
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez saisir le mot de passe actuel et le nouveau mot de passe.'
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Le nouveau mot de passe doit comporter au moins 6 caractères.'
      });
    }

    const user = await User.findById(req.user._id);
    const isMatch = await user.comparePassword(currentPassword);

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: 'Le mot de passe actuel est incorrect.'
      });
    }

    user.password = newPassword;
    await user.save();

    return res.status(200).json({
      success: true,
      message: 'Mot de passe modifié avec succès.'
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la modification du mot de passe.',
      error: error.message
    });
  }
};

// 6. [ADMIN] Liste complète des clients avec filtres et pagination (GET /api/users)
exports.getAllUsers = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 10));
    const skip = (page - 1) * limit;

    const { search, status } = req.query;
    const query = { role: 'client' };

    // Filtrer par statut
    if (status) {
      query.status = status;
    }

    // Recherche plein texte par mot clé (nom, email, téléphone, n° permis)
    if (search) {
      const escapedSearch = String(search).slice(0, 100).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const searchRegex = new RegExp(escapedSearch, 'i');
      query.$or = [
        { fullname: searchRegex },
        { email: searchRegex },
        { phone: searchRegex },
        { 'driverLicense.number': searchRegex }
      ];
    }

    const [users, total] = await Promise.all([
      User.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      User.countDocuments(query)
    ]);

    // Statistiques rapides globales pour le Dashboard Admin
    const [totalClients, activeCount, pendingCount, suspendedCount] = await Promise.all([
      User.countDocuments({ role: 'client' }),
      User.countDocuments({ role: 'client', status: 'active' }),
      User.countDocuments({ role: 'client', status: 'pending_approval' }),
      User.countDocuments({ role: 'client', status: 'suspended' })
    ]);

    return res.status(200).json({
      success: true,
      data: users,
      pagination: {
        total,
        page,
        totalPages: Math.ceil(total / limit),
        limit
      },
      stats: {
        totalClients,
        activeCount,
        pendingCount,
        suspendedCount
      }
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des utilisateurs.',
      error: error.message
    });
  }
};

exports.getClientDetails = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Identifiant client invalide.'
      });
    }

    const user = await User.findOne({
      _id: req.params.id,
      role: 'client'
    }).select('-password');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Client introuvable.'
      });
    }

    return res.status(200).json({ success: true, user });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération du profil client.',
      error: error.message
    });
  }
};

// 7. [ADMIN] Activation / Suspension d'un compte client (PUT /api/users/:id/status)
exports.updateUserStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: 'Identifiant client invalide.'
      });
    }

    const validStatuses = ['active', 'suspended', 'pending_approval'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Statut invalide. Les valeurs possibles sont : ${validStatuses.join(', ')}`
      });
    }

    const user = await User.findOneAndUpdate(
      { _id: id, role: 'client' },
      { status },
      { new: true, runValidators: true }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur introuvable'
      });
    }

    return res.status(200).json({
      success: true,
      message: `Le statut de l'utilisateur a été mis à jour vers '${status}'.`,
      user
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise à jour du statut.',
      error: error.message
    });
  }
};

// [ADMIN] Mise à jour des coordonnées d'un client (PUT /api/users/:id)
exports.updateClientByAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: 'Identifiant client invalide.'
      });
    }

    if (req.body.email !== undefined) {
      return res.status(400).json({
        success: false,
        message: 'Le changement d’e-mail doit passer par le parcours de vérification.'
      });
    }

    const { fullname, phone, driverLicenseNumber } = req.body;
    if (
      fullname === undefined &&
      phone === undefined &&
      driverLicenseNumber === undefined
    ) {
      return res.status(400).json({
        success: false,
        message: 'Aucune information à modifier.'
      });
    }

    for (const [field, value] of Object.entries({
      fullname,
      phone,
      driverLicenseNumber
    })) {
      if (value !== undefined && typeof value !== 'string') {
        return res.status(400).json({
          success: false,
          message: `Le champ ${field} doit être une chaîne de caractères.`
        });
      }
    }

    const user = await User.findOne({ _id: id, role: 'client' });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Client introuvable.'
      });
    }

    if (fullname !== undefined) {
      const normalizedName = fullname.trim();
      if (normalizedName.length < 2 || normalizedName.length > 80) {
        return res.status(400).json({
          success: false,
          message: 'Le nom doit contenir entre 2 et 80 caractères.'
        });
      }
      user.fullname = normalizedName;
    }

    if (phone !== undefined) {
      const normalizedPhone = phone.trim();
      if (!isValidPhone(normalizedPhone)) {
        return res.status(400).json({
          success: false,
          message: 'Le numéro doit contenir entre 7 et 15 chiffres.'
        });
      }
      user.phone = normalizedPhone;
    }

    if (driverLicenseNumber !== undefined) {
      const normalizedNumber = driverLicenseNumber.trim();
      if (normalizedNumber.length > 100) {
        return res.status(400).json({
          success: false,
          message: 'Le numéro de permis ne peut pas dépasser 100 caractères.'
        });
      }
      if (normalizedNumber !== user.driverLicense.number) {
        user.driverLicense.number = normalizedNumber;
        if (user.status !== 'suspended') {
          user.status = 'pending_approval';
        }
      }
    }

    await user.save();
    return res.status(200).json({
      success: true,
      message: 'Client mis à jour avec succès.',
      user
    });
  } catch (error) {
    if (error instanceof mongoose.Error.ValidationError) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise à jour du client.',
      error: error.message
    });
  }
};

// 8. [ADMIN] Suppression d'un client (DELETE /api/users/:id)
exports.deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: 'Identifiant client invalide.'
      });
    }
    const user = await User.findOneAndDelete({ _id: id, role: 'client' });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur introuvable'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Client supprimé avec succès'
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la suppression.',
      error: error.message
    });
  }
};

// 9. [ADMIN] Création directe d'un client (POST /api/users)
exports.createClientByAdmin = async (req, res) => {
  try {
    const { fullname, email, password, phone, driverLicenseNumber } = req.body;
    if (
      typeof fullname !== 'string' ||
      typeof email !== 'string' ||
      typeof password !== 'string' ||
      typeof phone !== 'string'
    ) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez remplir tous les champs obligatoires (nom, email, mot de passe, téléphone).'
      });
    }

    const normalizedName = fullname.trim();
    const trimmedEmail = email.trim().toLowerCase();
    const normalizedPhone = phone.trim();
    if (
      normalizedName.length < 2 ||
      normalizedName.length > 80 ||
      !emailPattern.test(trimmedEmail) ||
      password.length < 6 ||
      !isValidPhone(normalizedPhone) ||
      (driverLicenseNumber !== undefined &&
        (typeof driverLicenseNumber !== 'string' ||
          driverLicenseNumber.trim().length > 100))
    ) {
      return res.status(400).json({
        success: false,
        message: 'Vérifiez le nom, l’e-mail, le mot de passe et le numéro de téléphone.'
      });
    }

    const existing = await User.findOne({ email: trimmedEmail });
    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'Un compte existe déjà avec cet email.'
      });
    }

    const newUser = new User({
      fullname: normalizedName,
      email: trimmedEmail,
      password,
      phone: normalizedPhone,
      role: 'client',
      status: 'active',
      emailVerified: true,
      driverLicense: {
        number: driverLicenseNumber ? driverLicenseNumber.trim() : ''
      }
    });
    await newUser.save();

    return res.status(201).json({
      success: true,
      message: 'Client créé avec succès.',
      user: newUser
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Un compte existe déjà avec cet email.'
      });
    }
    if (error instanceof mongoose.Error.ValidationError) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
    return res.status(500).json({
      success: false,
      message: error.message || 'Erreur lors de la création du client.'
    });
  }
};
