const test = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');

const Reservation = require('../models/Reservation');
const { parseUtcDate, generateReservedDays } = require('../utils/reservationDates');

test('reservation days include pickup day and exclude return day', () => {
  const days = generateReservedDays('2026-11-20', '2026-11-23');

  assert.deepEqual(
    days.map((date) => date.toISOString()),
    [
      '2026-11-20T00:00:00.000Z',
      '2026-11-21T00:00:00.000Z',
      '2026-11-22T00:00:00.000Z'
    ]
  );
});

test('invalid dates and rental periods outside 1–30 days are rejected', () => {
  assert.throws(() => parseUtcDate('2026-02-30'));
  assert.throws(() => generateReservedDays('2026-11-20', '2026-11-20'));
  assert.throws(() => generateReservedDays('2026-11-01', '2026-12-02'));
});

test('confirmed reservations require the exact reserved calendar days', async () => {
  const start = '2026-11-20';
  const end = '2026-11-23';
  const base = {
    vehicleId: new mongoose.Types.ObjectId(),
    clientId: new mongoose.Types.ObjectId(),
    pickupDate: start,
    returnDate: end,
    reservedDays: generateReservedDays(start, end),
    pickupLocation: 'Tunis',
    returnLocation: 'Tunis',
    dailyPriceMillimes: 120000,
    totalPriceMillimes: 360000,
    status: 'confirmed'
  };

  await new Reservation(base).validate();
  await assert.rejects(
    new Reservation({ ...base, reservedDays: base.reservedDays.slice(0, 2) }).validate(),
    mongoose.Error.ValidationError
  );
});
