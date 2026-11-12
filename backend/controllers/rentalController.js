const mongoose = require('mongoose');
const Rental = require('../models/Rental');
const Reservation = require('../models/Reservation');
const User = require('../models/User');

async function rentalHistory(clientId) {
  const [legacyRentals, reservations] = await Promise.all([
    Rental.find({ client: clientId }).sort({ startDate: -1, createdAt: -1 }).lean(),
    Reservation.find({ clientId })
      .sort({ pickupDate: -1, createdAt: -1 })
      .populate('vehicleId', 'marque modele immatriculation image')
      .lean()
  ]);

  const reservationRentals = reservations.map((reservation) => {
    const vehicle = reservation.vehicleId || {};
    return {
      _id: reservation._id,
      client: reservation.clientId,
      vehicle: {
        name: [vehicle.marque, vehicle.modele].filter(Boolean).join(' ') || 'Véhicule',
        registration: vehicle.immatriculation || '',
        imageUrl: vehicle.image || ''
      },
      startDate: reservation.pickupDate,
      endDate: reservation.returnDate,
      totalPrice: reservation.totalPriceMillimes / 1000,
      currency: 'TND',
      status: reservation.status,
      createdAt: reservation.createdAt
    };
  });

  return [...legacyRentals, ...reservationRentals]
    .sort((left, right) => new Date(right.startDate) - new Date(left.startDate));
}

exports.getMyRentalHistory = async (req, res) => {
  try {
    const rentals = await rentalHistory(req.user._id);
    return res.status(200).json({ success: true, data: rentals });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération de votre historique.'
    });
  }
};

exports.getClientRentalHistory = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ success: false, message: 'Identifiant client invalide.' });
    }

    const client = await User.findOne({ _id: req.params.id, role: 'client' }).select('_id');
    if (!client) {
      return res.status(404).json({ success: false, message: 'Client introuvable.' });
    }

    const rentals = await rentalHistory(client._id);
    return res.status(200).json({ success: true, data: rentals });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération de l’historique du client.'
    });
  }
};
