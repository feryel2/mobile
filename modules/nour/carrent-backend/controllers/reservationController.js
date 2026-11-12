const mongoose = require('mongoose');
const { isDeepStrictEqual } = require('node:util');
const Reservation = require('../models/Reservation');
const { generateReservedDays } = require('../utils/reservationDates');
const creationDemo = require('../fixtures/reservationCreationDemo');

function isLocalDevelopmentRequest(req) {
  // Read the real connection address, not client-supplied forwarded headers.
  const address = req.socket.remoteAddress;
  const isLocalRequest = address === '127.0.0.1'
    || address === '::1'
    || address === '::ffff:127.0.0.1';

  return process.env.NODE_ENV === 'development' && isLocalRequest;
}

function parseDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }

  const date = new Date(value + 'T00:00:00.000Z');
  // Comparing the formatted date rejects impossible dates such as February 30.
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    return null;
  }

  return date;
}

exports.createReservation = async (req, res) => {
  try {
    // This fixture-based feature must never write into the normal carrent DB.
    if (!isLocalDevelopmentRequest(req)
      || process.env.ENABLE_RESERVATION_CREATION_TESTS !== 'true') {
      return res.status(403).json({ message: 'Création réservée aux tests locaux explicitement activés.' });
    }
    if (mongoose.connection.readyState !== 1) {
      return res.status(503).json({ message: 'MongoDB n’est pas connecté. Création impossible.' });
    }
    const connection = mongoose.connection;
    const options = connection.getClient().options;
    if (!/^carrent_creation_test_[a-f0-9]{32}$/.test(connection.name)
      || connection.db.databaseName !== connection.name
      || !['localhost', '127.0.0.1', '::1', '[::1]'].includes(connection.host)
      || options.directConnection !== true || options.proxyHost) {
      return res.status(403).json({
        message: 'Création autorisée uniquement dans une base temporaire de test locale, jamais carrent.'
      });
    }

    const allowedFields = ['vehicleId', 'clientId', 'pickupDate', 'returnDate',
      'pickupLocation', 'returnLocation'];
    const input = req.body;
    if (!input || typeof input !== 'object' || Array.isArray(input)
      || Object.keys(input).some(function (key) { return !allowedFields.includes(key); })) {
      return res.status(400).json({
        message: 'Envoyez uniquement les six champs autorisés. Prix, statut et jours sont calculés par le serveur.'
      });
    }
    for (const field of allowedFields) {
      if (typeof input[field] !== 'string' || input[field].trim().length === 0) {
        return res.status(400).json({ message: 'Tous les champs sont obligatoires et doivent être du texte.' });
      }
    }
    const { vehicleId, clientId, pickupDate, returnDate, pickupLocation, returnLocation } = input;
    if (!mongoose.isObjectIdOrHexString(vehicleId) || !mongoose.isObjectIdOrHexString(clientId)) {
      return res.status(400).json({ message: 'vehicleId et clientId doivent être des ObjectId valides.' });
    }
    const vehicle = creationDemo.vehicles.find(function (item) {
      return item.id === vehicleId.toLowerCase();
    });
    if (!vehicle || !creationDemo.clientIds.includes(clientId.toLowerCase())) {
      return res.status(400).json({ message: 'Véhicule ou client absent de la fixture de démonstration.' });
    }
    if (!creationDemo.locations.includes(pickupLocation)
      || !creationDemo.locations.includes(returnLocation)) {
      return res.status(400).json({ message: 'Lieu absent de la fixture de démonstration.' });
    }

    const pickup = parseDate(pickupDate);
    const end = parseDate(returnDate);
    if (!pickup || !end) {
      return res.status(400).json({ message: 'Les dates doivent être valides et au format YYYY-MM-DD.' });
    }
    let reservedDays;
    try {
      reservedDays = generateReservedDays(pickup, end);
    } catch (error) {
      return res.status(400).json({ message: 'La location doit durer de 1 à 30 jours, avec retour après le départ.' });
    }

    // Check MongoDB, not just the schema declaration. No index means no writes.
    const indexes = await Reservation.collection.indexes();
    const index = indexes.find(function (item) { return item.name === 'unique_confirmed_vehicle_day'; });
    if (!index || index.unique !== true
      || !isDeepStrictEqual(Object.entries(index.key), [['vehicleId', 1], ['reservedDays', 1]])
      || !isDeepStrictEqual(index.partialFilterExpression, { status: 'confirmed' })
      || index.sparse || index.collation || index.hidden || index.buildUUID) {
      return res.status(503).json({ message: 'Index de réservation absent ou incorrect. Création désactivée.' });
    }

    const dailyPriceMillimes = vehicle.dailyPriceMillimes;
    const totalPriceMillimes = reservedDays.length * dailyPriceMillimes;
    const newReservation = new Reservation({
      vehicleId: vehicle.id,
      clientId: clientId.toLowerCase(),
      pickupDate: pickup,
      returnDate: end,
      pickupLocation,
      returnLocation,
      reservedDays,
      dailyPriceMillimes,
      totalPriceMillimes,
      status: 'confirmed'
    });
    const savedReservation = await newReservation.save();
    res.status(201).json(savedReservation);
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({ message: 'Ce véhicule a déjà une réservation confirmée sur ces dates.' });
    }
    if (error.code === 26) {
      return res.status(503).json({ message: 'Collection ou index de réservation absent. Création désactivée.' });
    }
    if (error instanceof mongoose.Error.ValidationError) {
      return res.status(400).json({ message: 'Les informations de réservation sont invalides.' });
    }
    res.status(500).json({ message: 'Impossible de créer la réservation.' });
  }
};

exports.checkConflict = async (req, res) => {
  try {
    const { vehicleId, pickupDate, returnDate } = req.query;

    if (!vehicleId || !pickupDate || !returnDate) {
      return res.status(400).json({
        message: 'vehicleId, pickupDate et returnDate sont obligatoires.'
      });
    }

    if (typeof vehicleId !== 'string' || !mongoose.isObjectIdOrHexString(vehicleId)) {
      return res.status(400).json({ message: 'vehicleId doit être un ObjectId valide.' });
    }

    const requestedPickupDate = parseDate(pickupDate);
    const requestedReturnDate = parseDate(returnDate);

    if (!requestedPickupDate || !requestedReturnDate) {
      return res.status(400).json({
        message: 'Les dates doivent être valides et au format YYYY-MM-DD.'
      });
    }

    if (requestedReturnDate <= requestedPickupDate) {
      return res.status(400).json({
        message: 'La date de retour doit être après la date de prise en charge.'
      });
    }

    if (mongoose.connection.readyState !== 1) {
      return res.status(503).json({
        message: 'MongoDB n’est pas connecté. La vérification est impossible.'
      });
    }

    // Pickup is inclusive and return is exclusive: touching dates do not overlap.
    const conflict = await Reservation.findOne({
      vehicleId,
      status: 'confirmed',
      pickupDate: { $lt: requestedReturnDate },
      returnDate: { $gt: requestedPickupDate }
    }).select('_id');

    res.status(200).json({
      hasConflict: Boolean(conflict),
      message: 'Ce résultat concerne uniquement les réservations confirmées, '
        + 'pas la disponibilité complète du véhicule.'
    });
  } catch (error) {
    res.status(500).json({
      message: 'Impossible de vérifier les conflits de réservation.'
    });
  }
};

exports.getClientReservations = async (req, res) => {
  try {
    // Temporary local-development guard, not authentication or ownership checks.
    if (!isLocalDevelopmentRequest(req)) {
      return res.status(403).json({
        message: 'Cet historique est réservé au développement local. '
          + 'L’authentification et le contrôle du propriétaire sont requis avant déploiement.'
      });
    }

    const { clientId } = req.params;

    if (typeof clientId !== 'string' || !mongoose.isObjectIdOrHexString(clientId)) {
      return res.status(400).json({ message: 'clientId doit être un ObjectId valide.' });
    }

    if (mongoose.connection.readyState !== 1) {
      return res.status(503).json({
        message: 'MongoDB n’est pas connecté. La lecture de l’historique est impossible.'
      });
    }

    // No status filter: return both confirmed and cancelled reservations.
    const reservations = await Reservation.find({ clientId }).sort({ createdAt: -1 });
    res.status(200).json(reservations);
  } catch (error) {
    res.status(500).json({
      message: 'Impossible de récupérer les réservations du client.'
    });
  }
};

exports.cancelReservation = async (req, res) => {
  try {
    if (!isLocalDevelopmentRequest(req)) {
      return res.status(403).json({
        message: 'Cette annulation est réservée au développement local. '
          + 'L’authentification et le contrôle du propriétaire sont requis avant déploiement.'
      });
    }

    const { id } = req.params;

    if (typeof id !== 'string' || !mongoose.isObjectIdOrHexString(id)) {
      return res.status(400).json({
        message: 'L’identifiant de réservation doit être un ObjectId valide.'
      });
    }

    if (mongoose.connection.readyState !== 1) {
      return res.status(503).json({
        message: 'MongoDB n’est pas connecté. L’annulation est impossible.'
      });
    }

    const reservation = await Reservation.findById(id);

    if (!reservation) {
      return res.status(404).json({ message: 'Réservation introuvable.' });
    }

    if (reservation.status === 'cancelled') {
      return res.status(200).json({
        message: 'Cette réservation est déjà annulée.',
        reservation
      });
    }

    if (reservation.status !== 'confirmed') {
      return res.status(409).json({
        message: 'Le statut de cette réservation ne permet pas son annulation.'
      });
    }

    reservation.status = 'cancelled';
    const updatedReservation = await reservation.save();

    res.status(200).json({
      message: 'Réservation annulée avec succès.',
      reservation: updatedReservation
    });
  } catch (error) {
    res.status(500).json({ message: 'Impossible d’annuler la réservation.' });
  }
};
