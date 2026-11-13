const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const Reservation = require('../models/Reservation');
const User = require('../models/User');
const Vehicle = require('../models/Vehicle');
const { app } = require('../server');

const adminId = new mongoose.Types.ObjectId();
const clientId = new mongoose.Types.ObjectId();
const otherClientId = new mongoose.Types.ObjectId();
const vehicleId = new mongoose.Types.ObjectId();
const otherVehicleId = new mongoose.Types.ObjectId();
const reservationId = new mongoose.Types.ObjectId();
const otherReservationId = new mongoose.Types.ObjectId();
const reason = 'Véhicule en réparation.';

function day(offset) {
  const date = new Date();
  date.setUTCHours(0, 0, 0, 0);
  date.setUTCDate(date.getUTCDate() + offset);
  return date;
}

async function setup(context) {
  const secret = 'car-rent-cancellation-fixture-key-for-tests';
  const previousSecret = process.env.JWT_SECRET;
  process.env.JWT_SECRET = secret;
  context.after(() => {
    if (previousSecret === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = previousSecret;
  });

  const bookings = [
    new Reservation({
      _id: reservationId,
      clientId,
      vehicleId,
      status: 'confirmed',
      pickupDate: day(2),
      returnDate: day(3),
      reservedDays: [day(2)],
      pickupLocation: 'Tunis',
      returnLocation: 'La Marsa',
      dailyPriceMillimes: 125000,
      totalPriceMillimes: 125000
    }),
    new Reservation({
      _id: otherReservationId,
      clientId: otherClientId,
      vehicleId: otherVehicleId,
      status: 'confirmed',
      pickupDate: day(2),
      returnDate: day(3),
      reservedDays: [day(2)],
      pickupLocation: 'Tunis',
      returnLocation: 'La Marsa',
      dailyPriceMillimes: 95000,
      totalPriceMillimes: 95000
    })
  ];

  function matches(booking, filter) {
    return (!filter._id || booking._id.equals(filter._id))
      && (!filter.clientId || booking.clientId.equals(filter.clientId))
      && (!filter.vehicleId || booking.vehicleId.equals(filter.vehicleId))
      && (!filter.status || booking.status === filter.status)
      && (!filter.reservedDays || booking.reservedDays.some((day) =>
        filter.reservedDays.$in.some((requested) => +requested === +day)));
  }

  const update = context.mock.method(Reservation, 'findOneAndUpdate',
    async (filter, changes, options) => {
      assert.deepEqual(options, { returnDocument: 'after', runValidators: true });
      const booking = bookings.find((item) => matches(item, filter));
      if (booking) booking.set(changes.$set);
      return booking;
    });
  context.mock.method(Reservation, 'findById', (id) => ({
    select: async () => bookings.find((item) => item._id.equals(id))
  }));
  context.mock.method(Reservation.prototype, 'populate', async function () {
    return this;
  });
  context.mock.method(Reservation, 'find', (filter) => {
    let rows = bookings.filter((item) => matches(item, filter)).map((item) => item.toObject());
    return {
      select(fields) {
        assert.equal(fields, '-cancelledBy');
        rows = rows.map(({ cancelledBy, ...row }) => row);
        return this;
      },
      sort() { return this; },
      populate() { return this; },
      then(resolve, reject) { return Promise.resolve(rows).then(resolve, reject); }
    };
  });
  context.mock.method(Reservation, 'exists', async (filter) =>
    bookings.find((item) => matches(item, filter)) ?? null);
  context.mock.method(Reservation, 'distinct', async (field, filter) =>
    bookings.filter((item) => matches(item, filter)).map((item) => item[field]));
  context.mock.method(Vehicle, 'find', (filter) => ({
    sort: async () => [vehicleId, otherVehicleId]
      .filter((id) => filter.disponible && !filter._id.$nin.some((blocked) => id.equals(blocked)))
      .map((_id) => ({ _id }))
  }));
  context.mock.method(User, 'findById', async (id) => ({
    _id: new mongoose.Types.ObjectId(id),
    role: adminId.equals(id) ? 'admin' : 'client',
    status: 'active'
  }));

  const server = app.listen(0, '127.0.0.1');
  context.after(() => new Promise((resolve) => server.close(resolve)));
  await new Promise((resolve) => server.once('listening', resolve));
  const baseUrl = 'http://127.0.0.1:' + server.address().port + '/api';

  async function request(path, { as, method = 'GET', body } = {}) {
    const headers = { 'Content-Type': 'application/json' };
    if (as) headers.Authorization = 'Bearer ' + jwt.sign({ id: as }, secret);
    const response = await fetch(baseUrl + path, {
      method, headers, body: JSON.stringify(body)
    });
    return { status: response.status, body: await response.json() };
  }

  function cancel(body, { as = adminId, id = reservationId, action = 'admin-cancel' } = {}) {
    return request('/reservations/' + id + '/' + action, { as, method: 'POST', body });
  }

  return { bookings, update, request, cancel };
}

test('admin cancellation records the reason, time and authenticated administrator', async (context) => {
  const { bookings, cancel, request } = await setup(context);
  const original = bookings[0].toObject();
  const startedAt = Date.now();
  const result = await cancel({
    reason: '  ' + reason + '  ',
    cancelledBy: clientId
  });

  assert.equal(result.status, 200);
  const saved = bookings[0].toObject();
  assert.equal(saved.status, 'cancelled');
  assert.equal(saved.cancellationReason, reason);
  assert.ok(saved.cancelledBy.equals(adminId));
  assert.equal(saved.cancelledByRole, 'admin');
  assert.ok(saved.cancelledAt instanceof Date);
  assert.ok(+saved.cancelledAt >= startedAt && +saved.cancelledAt <= Date.now());
  assert.equal(result.body.data.cancellationReason, reason);
  for (const field of [
    'vehicleId', 'clientId', 'pickupDate', 'returnDate', 'reservedDays',
    'pickupLocation', 'returnLocation', 'dailyPriceMillimes', 'totalPriceMillimes'
  ]) {
    assert.deepEqual(saved[field], original[field]);
  }

  const adminList = await request('/reservations/admin', { as: adminId });
  assert.equal(adminList.status, 200);
  assert.equal(adminList.body.data[0].cancellationReason, reason);
  assert.equal(adminList.body.data[0].cancelledBy, adminId.toString());

  const mine = await request('/reservations/mine', { as: clientId });
  assert.equal(mine.status, 200);
  assert.equal(mine.body.data.length, 1);
  assert.equal(mine.body.data[0].cancellationReason, reason);
  assert.equal(mine.body.data[0].cancelledByRole, 'admin');
  assert.equal(mine.body.data[0].cancelledAt, saved.cancelledAt.toISOString());
  assert.equal('cancelledBy' in mine.body.data[0], false);

  const other = await request('/reservations/mine', { as: otherClientId });
  assert.equal(other.status, 200);
  assert.deepEqual(other.body.data.map((booking) => booking._id), [otherReservationId.toString()]);
  assert.equal('cancellationReason' in other.body.data[0], false);
});

test('admin cancellation validates reason and reservation ID before writing', async (context) => {
  const { cancel, update } = await setup(context);
  for (const body of [undefined, {}, { reason: '  \t ' }, { reason: 12 }, { reason: 'x'.repeat(501) }]) {
    assert.equal((await cancel(body)).status, 400);
  }
  assert.equal((await cancel({ reason }, { id: 'invalid' })).status, 400);
  assert.equal(update.mock.callCount(), 0);
  assert.equal((await cancel({ reason: 'x'.repeat(500) })).status, 200);
});

test('admin cancellation requires authentication and an administrator role', async (context) => {
  const { cancel, update } = await setup(context);
  assert.equal((await cancel({ reason }, { as: null })).status, 401);
  assert.equal((await cancel({ reason }, { as: clientId })).status, 403);
  assert.equal((await cancel({}, { action: 'cancel' })).status, 403);
  assert.equal(update.mock.callCount(), 0);
});

test('unknown reservations return 404 and repeated cancellation keeps the first reason', async (context) => {
  const { bookings, cancel } = await setup(context);
  assert.equal((await cancel({ reason }, { id: new mongoose.Types.ObjectId() })).status, 404);
  const results = await Promise.all([
    cancel({ reason }),
    cancel({ reason: 'Autre motif.' })
  ]);
  assert.deepEqual(results.map((result) => result.status).sort(), [200, 409]);
  const first = results.find((result) => result.status === 200).body.data;
  assert.equal((await cancel({ reason: 'Encore un motif.' })).status, 409);
  assert.equal(bookings[0].cancellationReason, first.cancellationReason);
  assert.equal(bookings[0].cancelledAt.toISOString(), first.cancelledAt);
});

test('admin cancellation releases the vehicle and leaves other confirmed bookings blocking', async (context) => {
  const { cancel, request } = await setup(context);
  const dates = '?pickupDate=' + day(2).toISOString().slice(0, 10)
    + '&returnDate=' + day(3).toISOString().slice(0, 10);
  const availableBefore = await request('/vehicles/available' + dates);
  assert.equal(availableBefore.status, 200);
  assert.deepEqual(availableBefore.body.data, []);

  assert.equal((await cancel({ reason })).status, 200);

  const availableAfter = await request('/vehicles/available' + dates);
  assert.equal(availableAfter.status, 200);
  assert.deepEqual(availableAfter.body.data, [{ _id: vehicleId.toString() }]);

  const ownConflict = await request('/reservations/check-conflict' + dates + '&vehicleId=' + vehicleId,
    { as: clientId });
  assert.equal(ownConflict.body.hasConflict, false);
  const otherConflict = await request('/reservations/check-conflict' + dates + '&vehicleId=' + otherVehicleId,
    { as: clientId });
  assert.equal(otherConflict.body.hasConflict, true);
});

test('client cancellation still allows only the owner and records no admin details', async (context) => {
  const { bookings, cancel } = await setup(context);
  assert.equal((await cancel({}, { action: 'cancel', as: otherClientId })).status, 403);
  const result = await cancel({ reason }, { action: 'cancel', as: clientId });
  assert.equal(result.status, 200);
  assert.equal(bookings[0].status, 'cancelled');
  assert.equal(bookings[0].cancellationReason, undefined);
  assert.equal(bookings[0].cancelledBy, undefined);
  assert.equal((await cancel({}, { action: 'cancel', as: clientId })).status, 409);
});