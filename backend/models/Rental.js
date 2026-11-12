const mongoose = require('mongoose');

const rentalSchema = new mongoose.Schema({
  client: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  vehicle: {
    name: { type: String, required: true, trim: true },
    registration: { type: String, trim: true, default: '' },
    imageUrl: { type: String, trim: true, default: '' }
  },
  startDate: { type: Date, required: true },
  endDate: { type: Date, required: true },
  totalPrice: { type: Number, required: true, min: 0 },
  currency: { type: String, trim: true, uppercase: true, default: 'EUR' },
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'ongoing', 'completed', 'cancelled'],
    default: 'confirmed'
  }
}, { timestamps: true });

rentalSchema.index({ client: 1, startDate: -1 });

module.exports = mongoose.model('Rental', rentalSchema);
