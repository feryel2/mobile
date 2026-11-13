const mongoose = require('mongoose');
const Vehicle = require('../models/Vehicle');
const Reservation = require('../models/Reservation');
const { parseUtcDate, generateReservedDays } = require('../utils/reservationDates');

const validId = (id) => mongoose.isValidObjectId(id);

exports.listAvailable = async (req, res) => {
  let reservedDays;
  try {
    const pickupDate = parseUtcDate(req.query.pickupDate);
    const returnDate = parseUtcDate(req.query.returnDate);
    reservedDays = generateReservedDays(pickupDate, returnDate);
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    if (pickupDate < today) {
      return res.status(400).json({ message: 'La date de départ ne peut pas être passée.' });
    }
  } catch (error) {
    return res.status(400).json({
      message: 'Dates invalides : indiquez un départ et un retour valides, pour 1 à 30 jours.'
    });
  }

  try {
    const reservedVehicleIds = await Reservation.distinct('vehicleId', {
      status: 'confirmed',
      reservedDays: { $in: reservedDays }
    });
    const vehicles = await Vehicle.find({
      disponible: true,
      _id: { $nin: reservedVehicleIds }
    }).sort({ createdAt: -1 });
    return res.status(200).json({ success: true, data: vehicles });
  } catch (error) {
    return res.status(500).json({ message: 'Erreur lors du chargement des disponibilités.' });
  }
};

exports.list = async (req, res) => {
  try {
    const vehicles = await Vehicle.find().sort({ createdAt: -1 });
    res.json({ data: vehicles });
  } catch (err) { res.status(500).json({ message: 'Erreur lors du chargement des véhicules.' }); }
};

exports.getOne = async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Identifiant invalide.' });
  try {
    const vehicle = await Vehicle.findById(req.params.id);
    if (!vehicle) return res.status(404).json({ message: 'Véhicule introuvable.' });
    res.json({ data: vehicle });
  } catch (err) { res.status(500).json({ message: 'Erreur serveur.' }); }
};

exports.create = async (req, res) => {
  try {
    const vehicle = await Vehicle.create(req.body);
    res.status(201).json({ message: 'Véhicule ajouté avec succès.', data: vehicle });
  } catch (err) {
    if (err.code === 11000) return res.status(409).json({ message: "Cette immatriculation existe déjà." });
    if (err.name === 'ValidationError') {
      const messages = Object.values(err.errors).map(e => e.message);
      return res.status(400).json({ message: messages.join(' ') });
    }
    res.status(400).json({ message: err.message || 'Données invalides.' });
  }
};

exports.update = async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Identifiant invalide.' });
  try {
    const vehicle = await Vehicle.findByIdAndUpdate(req.params.id, req.body, {
      new: true, runValidators: true, context: 'query'
    });
    if (!vehicle) return res.status(404).json({ message: 'Véhicule introuvable.' });
    res.json({ message: 'Véhicule modifié avec succès.', data: vehicle });
  } catch (err) {
    if (err.code === 11000) return res.status(409).json({ message: "Cette immatriculation existe déjà." });
    if (err.name === 'ValidationError' || err.name === 'CastError')
      return res.status(400).json({ message: err.message });
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

exports.remove = async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Identifiant invalide.' });
  try {
    const hasReservations = await Reservation.exists({ vehicleId: req.params.id });
    if (hasReservations) {
      return res.status(409).json({
        message: 'Ce véhicule possède un historique de réservations. Rendez-le indisponible à la place.'
      });
    }
    const vehicle = await Vehicle.findByIdAndDelete(req.params.id);
    if (!vehicle) return res.status(404).json({ message: 'Véhicule introuvable.' });
    res.json({ message: 'Véhicule supprimé avec succès.' });
  } catch (err) { res.status(500).json({ message: 'Erreur serveur.' }); }
};
