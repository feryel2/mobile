const mongoose = require('mongoose');
const { parseUtcDate, generateReservedDays } = require('../utils/reservationDates');

const reservationSchema = new mongoose.Schema(
  {
    // Shared vehicle and client model names will be agreed with the group later.
    vehicleId: { type: mongoose.Schema.Types.ObjectId, required: true },
    clientId: { type: mongoose.Schema.Types.ObjectId, required: true },
    pickupDate: { type: Date, required: true, set: parseUtcDate },
    returnDate: {
      type: Date,
      required: true,
      set: parseUtcDate,
      validate: {
        validator: function (value) {
          // Required validation handles missing dates separately.
          if (!this.pickupDate || !value) {
            return true;
          }
          return value > this.pickupDate;
        },
        message: 'La date de retour doit être après la date de prise en charge.'
      }
    },
    reservedDays: {
      type: [Date],
      default: undefined,
      required: function () {
        return this.status === 'confirmed';
      },
      // Check original inputs before Date casting can normalize an invalid date.
      set: function (days) {
        if (days === undefined || days === null) return days;
        if (!Array.isArray(days)) throw new Error('reservedDays must be an array.');
        const dates = [];
        for (const day of days) dates.push(parseUtcDate(day));
        return dates;
      },
      validate: {
        validator: function (days) {
          if (this.status !== 'confirmed') return true;
          try {
            const expected = generateReservedDays(this.pickupDate, this.returnDate);
            if (!Array.isArray(days) || days.length !== expected.length) return false;
            for (let index = 0; index < expected.length; index++) {
              if (!(days[index] instanceof Date)
                || days[index].getTime() !== expected[index].getTime()) {
                return false;
              }
            }
            return true;
          } catch (error) {
            return false;
          }
        },
        message: 'reservedDays doit contenir exactement les jours UTC de la location, '
          + 'dans l’ordre, pour une durée de 1 à 30 jours.'
      }
    },
    pickupLocation: { type: String, required: true },
    returnLocation: { type: String, required: true },
    dailyPriceMillimes: {
      type: Number,
      required: true,
      min: 0,
      validate: {
        validator: function (value) {
          return Number.isInteger(value);
        },
        message: 'Le prix journalier doit être un nombre entier de millimes.'
      }
    },
    totalPriceMillimes: {
      type: Number,
      required: true,
      min: 0,
      validate: {
        validator: function (value) {
          return Number.isInteger(value);
        },
        message: 'Le prix total doit être un nombre entier de millimes.'
      }
    },
    status: {
      type: String,
      required: true,
      enum: ['confirmed', 'cancelled'],
      default: 'confirmed'
    }
  },
  // Defining an index must not build it in the normal database on startup.
  { timestamps: true, autoIndex: false, autoCreate: false }
);

reservationSchema.index(
  { vehicleId: 1, reservedDays: 1 },
  {
    name: 'unique_confirmed_vehicle_day',
    unique: true,
    partialFilterExpression: { status: 'confirmed' }
  }
);

module.exports = mongoose.model('Reservation', reservationSchema);
