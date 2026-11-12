const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const passwordResetController = require('../controllers/passwordResetController');
const rentalController = require('../controllers/rentalController');
const emailVerificationController = require('../controllers/emailVerificationController');
const { protect, authorizeAdmin } = require('../middlewares/auth');
const upload = require('../middlewares/upload');

// Configuration upload Multer (avatar + photo du permis)
const userUploads = upload.fields([
  { name: 'avatar', maxCount: 1 },
  { name: 'driverLicensePhoto', maxCount: 1 }
]);

// --- ROUTES PUBLIQUES ---
// 1. Email verification and client registration
router.post('/email-verifications', emailVerificationController.sendCode);
router.post('/register', userController.register);
router.post('/password-reset-codes', passwordResetController.sendCode);
router.post('/password-resets', passwordResetController.resetPassword);

// 2. Connexion
router.post('/login', userController.login);
router.post('/admin-login-tickets/consume', userController.consumeAdminLoginTicket);
router.post(
  '/admin-login-tickets',
  protect,
  authorizeAdmin,
  userController.createAdminLoginTicket
);

// --- ROUTES CLIENT PROTÉGÉES (JWT) ---
// 3. Récupération des informations du profil connecté
router.get('/profile', protect, userController.getProfile);
router.put('/profile/email', protect, userController.changeEmail);

// 4. Mise à jour du profil (nom, téléphone, avatar, permis)
router.put('/profile', protect, userUploads, userController.updateProfile);

// 5. Modification du mot de passe
router.put('/change-password', protect, userController.changePassword);

// 6. Historique personnel des locations
router.get('/profile/rentals', protect, rentalController.getMyRentalHistory);

// --- ROUTES ADMINISTRATEUR (JWT + Rôle Admin) ---
// 7. Liste complète des clients avec filtres et pagination
router.get('/', protect, authorizeAdmin, userController.getAllUsers);

// 8. Profil détaillé d'un client
router.get('/:id', protect, authorizeAdmin, userController.getClientDetails);

// 9. Historique des locations d'un client
router.get('/:id/rentals', protect, authorizeAdmin, rentalController.getClientRentalHistory);

// 10. Activation / Suspension / Validation du statut d'un client
router.put('/:id/status', protect, authorizeAdmin, userController.updateUserStatus);

// 11. Suppression d'un client
router.delete('/:id', protect, authorizeAdmin, userController.deleteUser);

module.exports = router;
