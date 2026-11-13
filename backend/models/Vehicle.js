const mongoose = require('mongoose');

const vehicleSchema = new mongoose.Schema({
  marque: { type: String, required: [true, 'La marque est obligatoire'], trim: true, minlength: 2, maxlength: 40 },
  modele: { type: String, required: [true, 'Le modèle est obligatoire'], trim: true, minlength: 1, maxlength: 50 },
  immatriculation: {
    type: String, required: [true, "L'immatriculation est obligatoire"],
    trim: true, uppercase: true, unique: true, minlength: 3, maxlength: 20
  },
  annee: { type: Number, required: true, min: 1900, max: new Date().getFullYear() + 1, validate: Number.isInteger },
  prix: { type: Number, required: true, min: 0.01 },
  kilometrage: { type: Number, required: true, min: 0, validate: Number.isInteger },
  carburant: { type: String, required: true, enum: ['Essence', 'Diesel', 'Hybride', 'Electrique'] },
  disponible: { type: Boolean, default: true },
  image: { type: String, default: 'default_car.png' },

}, { timestamps: true });

module.exports = mongoose.model('Vehicle', vehicleSchema);
