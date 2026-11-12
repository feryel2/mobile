const express = require('express');
const router = express.Router();
const reservationController = require('../controllers/reservationController');
const reservationHistoryCors = require('../middlewares/reservationHistoryCors');

router.post('/', reservationController.createReservation);
router.get('/check-conflict', reservationController.checkConflict);
router.get('/client/:clientId', reservationHistoryCors, reservationController.getClientReservations);
router.post('/:id/cancel', reservationController.cancelReservation);

module.exports = router;
