const express = require('express');
const router = express.Router();
const reservationController = require('../controllers/reservationController');
const { protect, authorizeAdmin } = require('../middlewares/auth');

router.get('/check-conflict', protect, reservationController.checkConflict);
router.get('/mine', protect, reservationController.getMyReservations);
router.get(
  '/client/:clientId',
  protect,
  authorizeAdmin,
  reservationController.getClientReservations
);
router.post('/', protect, reservationController.createReservation);
router.post('/:id/cancel', protect, reservationController.cancelReservation);

module.exports = router;
