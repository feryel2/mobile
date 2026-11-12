const mongoose = require('mongoose');
const Reservation = require('../models/Reservation');
const User = require('../models/User');
const Vehicle = require('../models/Vehicle');
const { parseUtcDate, generateReservedDays } = require('../utils/reservationDates');

const vehicleFields = 'marque modele immatriculation image prix';

function parseDate(value) {
  try {
    return parseUtcDate(value);
  } catch (error) {
    return null;
  }
}

function parseRentalPeriod(pickupValue, returnValue) {
  const pickupDate = parseDate(pickupValue);
  const returnDate = parseDate(returnValue);
  if (!pickupDate || !returnDate) return null;

  try {
    const reservedDays = generateReservedDays(pickupDate, returnDate);
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    if (pickupDate < today) return null;
    return { pickupDate, returnDate, reservedDays };
  } catch (error) {
    return null;
  }
}

exports.createReservation = async (req, res) => {
  try {
    if (req.user.role !== 'client' || req.user.status !== 'active') {
      return res.status(403).json({
        success: false,
        message: 'Un compte client actif est nécessaire pour réserver.'
      });
    }

    const allowedFields = [
      'vehicleId',
      'pickupDate',
      'returnDate',
      'pickupLocation',
      'returnLocation'
    ];
    const input = req.body;
    if (!input || typeof input !== 'object' || Array.isArray(input)
      || Object.keys(input).some((key) => !allowedFields.includes(key))) {
      return res.status(400).json({
        success: false,
        message: 'Les champs de réservation sont invalides.'
      });
    }

    const { vehicleId, pickupDate, returnDate, pickupLocation, returnLocation } = input;
    if (typeof vehicleId !== 'string' || !mongoose.isObjectIdOrHexString(vehicleId)
      || typeof pickupLocation !== 'string' || !pickupLocation.trim()
      || typeof returnLocation !== 'string' || !returnLocation.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Véhicule et lieux de prise en charge/retour sont obligatoires.'
      });
    }

    const period = parseRentalPeriod(pickupDate, returnDate);
    if (!period) {
      return res.status(400).json({
        success: false,
        message: 'Dates invalides : choisissez une période future de 1 à 30 jours.'
      });
    }

    const vehicle = await Vehicle.findOne({ _id: vehicleId, disponible: true });
    if (!vehicle) {
      return res.status(404).json({
        success: false,
        message: 'Ce véhicule est introuvable ou indisponible.'
      });
    }

    const dailyPriceMillimes = Math.round(vehicle.prix * 1000);
    const totalPriceMillimes = dailyPriceMillimes * period.reservedDays.length;
    if (!Number.isSafeInteger(dailyPriceMillimes)
      || !Number.isSafeInteger(totalPriceMillimes)) {
      return res.status(400).json({
        success: false,
        message: 'Le prix du véhicule ne permet pas de calculer cette réservation.'
      });
    }

    const reservation = await Reservation.create({
      vehicleId: vehicle._id,
      clientId: req.user._id,
      pickupDate: period.pickupDate,
      returnDate: period.returnDate,
      reservedDays: period.reservedDays,
      pickupLocation: pickupLocation.trim(),
      returnLocation: returnLocation.trim(),
      dailyPriceMillimes,
      totalPriceMillimes,
      status: 'confirmed'
    });

    await reservation.populate('vehicleId', vehicleFields);
    return res.status(201).json({ success: true, data: reservation });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Ce véhicule vient d’être réservé sur une partie de ces dates.'
      });
    }
    if (error instanceof mongoose.Error.ValidationError) {
      return res.status(400).json({
        success: false,
        message: 'Les informations de réservation sont invalides.'
      });
    }
    return res.status(500).json({
      success: false,
      message: 'Impossible de créer la réservation.'
    });
  }
};

exports.checkConflict = async (req, res) => {
  const { vehicleId, pickupDate, returnDate } = req.query;
  if (typeof vehicleId !== 'string' || !mongoose.isObjectIdOrHexString(vehicleId)) {
    return res.status(400).json({ success: false, message: 'Identifiant véhicule invalide.' });
  }

  const period = parseRentalPeriod(pickupDate, returnDate);
  if (!period) {
    return res.status(400).json({
      success: false,
      message: 'Dates invalides : choisissez une période future de 1 à 30 jours.'
    });
  }

  try {
    const conflict = await Reservation.exists({
      vehicleId,
      status: 'confirmed',
      reservedDays: { $in: period.reservedDays }
    });
    return res.status(200).json({ success: true, hasConflict: Boolean(conflict) });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Impossible de vérifier les disponibilités.'
    });
  }
};

exports.getMyReservations = async (req, res) => {
  try {
    const reservations = await Reservation.find({ clientId: req.user._id })
      .sort({ pickupDate: -1, createdAt: -1 })
      .populate('vehicleId', vehicleFields);
    return res.status(200).json({ success: true, data: reservations });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Impossible de récupérer vos réservations.'
    });
  }
};

exports.getClientReservations = async (req, res) => {
  if (!mongoose.isObjectIdOrHexString(req.params.clientId)) {
    return res.status(400).json({ success: false, message: 'Identifiant client invalide.' });
  }

  try {
    const client = await User.findOne({
      _id: req.params.clientId,
      role: 'client'
    }).select('_id');
    if (!client) {
      return res.status(404).json({ success: false, message: 'Client introuvable.' });
    }

    const reservations = await Reservation.find({ clientId: client._id })
      .sort({ pickupDate: -1, createdAt: -1 })
      .populate('vehicleId', vehicleFields);
    return res.status(200).json({ success: true, data: reservations });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Impossible de récupérer les réservations du client.'
    });
  }
};

exports.cancelReservation = async (req, res) => {
  if (!mongoose.isObjectIdOrHexString(req.params.id)) {
    return res.status(400).json({ success: false, message: 'Identifiant de réservation invalide.' });
  }

  try {
    const reservation = await Reservation.findById(req.params.id);
    if (!reservation) {
      return res.status(404).json({ success: false, message: 'Réservation introuvable.' });
    }
    if (req.user.role !== 'admin'
      && !reservation.clientId.equals(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez pas annuler cette réservation.'
      });
    }
    if (reservation.status !== 'confirmed') {
      return res.status(409).json({
        success: false,
        message: 'Cette réservation ne peut plus être annulée.'
      });
    }

    reservation.status = 'cancelled';
    await reservation.save();
    await reservation.populate('vehicleId', vehicleFields);
    return res.status(200).json({ success: true, data: reservation });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Impossible d’annuler cette réservation.'
    });
  }
};
