const mongoose = require('mongoose');
const Rental = require('../models/Rental');
const User = require('../models/User');

const rentalHistory = async (clientId) => Rental.find({ client: clientId })
  .sort({ startDate: -1, createdAt: -1 })
  .lean();

exports.getMyRentalHistory = async (req, res) => {
  try {
    const rentals = await rentalHistory(req.user._id);
    return res.status(200).json({ success: true, data: rentals });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération de votre historique.',
      error: error.message
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
      message: 'Erreur lors de la récupération de l’historique du client.',
      error: error.message
    });
  }
};
