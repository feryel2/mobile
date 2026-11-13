const express = require('express');
const router = express.Router();
const reservationController = require('../controllers/reservationController');
const { protect, authorizeAdmin } = require('../middlewares/auth');

router.get('/check-conflict', protect, reservationController.checkConflict);
router.get('/mine', protect, reservationController.getMyReservations);
router.get('/admin', protect, authorizeAdmin, reservationController.getAllReservations);
router.get(
  '/client/:clientId',
  protect,
  authorizeAdmin,
  reservationController.getClientReservations
);
router.post('/', protect, reservationController.createReservation);
router.post('/:id/cancel', protect, reservationController.cancelReservation);

router.post('/:id/admin-cancel', protect, authorizeAdmin, reservationController.adminCancelReservation);

module.exports = router;
