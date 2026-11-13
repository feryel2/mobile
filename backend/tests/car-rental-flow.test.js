const test = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');

const Reservation = require('../models/Reservation');
const Vehicle = require('../models/Vehicle');
const reservationController = require('../controllers/reservationController');
const vehicleController = require('../controllers/vehicleController');

function response() {
  return {
    statusCode: 200,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    }
  };
}

function futureDate(offset) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + offset);
  return date.toISOString().slice(0, 10);
}

test('reservation uses the authenticated client and vehicle price', async () => {
  const vehicleId = new mongoose.Types.ObjectId();
  const clientId = new mongoose.Types.ObjectId();
  const originalFindOne = Vehicle.findOne;
  const originalCreate = Reservation.create;
  let created;

  Vehicle.findOne = async (query) => {
    assert.equal(query._id.toString(), vehicleId.toString());
    assert.equal(query.disponible, true);
    return { _id: vehicleId, prix: 120.5 };
  };
  Reservation.create = async (document) => {
    created = document;
    return {
      ...document,
      _id: new mongoose.Types.ObjectId(),
      populate: async () => {}
    };
  };

  try {
    const res = response();
    await reservationController.createReservation({
      user: { _id: clientId, role: 'client', status: 'active' },
      body: {
        vehicleId: vehicleId.toString(),
        pickupDate: futureDate(2),
        returnDate: futureDate(5),
        pickupLocation: 'Tunis',
        returnLocation: 'Aéroport'
      }
    }, res);

    assert.equal(res.statusCode, 201);
    assert.equal(created.clientId.toString(), clientId.toString());
    assert.equal(created.dailyPriceMillimes, 120500);
    assert.equal(created.totalPriceMillimes, 361500);
    assert.equal(created.reservedDays.length, 3);
  } finally {
    Vehicle.findOne = originalFindOne;
    Reservation.create = originalCreate;
  }
});

test('availability excludes vehicles reserved on any requested day', async () => {
  const reservedVehicleId = new mongoose.Types.ObjectId();
  const availableVehicle = { _id: new mongoose.Types.ObjectId() };
  const pickupDate = futureDate(2);
  const middleDate = futureDate(3);
  const returnDate = futureDate(4);
  const originalDistinct = Reservation.distinct;
  const originalFind = Vehicle.find;
  let vehicleQuery;

  Reservation.distinct = async (field, query) => {
    assert.equal(field, 'vehicleId');
    assert.equal(query.status, 'confirmed');
    assert.deepEqual(query.reservedDays.$in, [new Date(pickupDate), new Date(middleDate)]);
    return [reservedVehicleId];
  };
  Vehicle.find = (query) => {
    vehicleQuery = query;
    return { sort: async () => [availableVehicle] };
  };

  try {
    const res = response();
    await vehicleController.listAvailable({
      query: {
        pickupDate,
        returnDate
      }
    }, res);

    assert.equal(res.statusCode, 200);
    assert.deepEqual(vehicleQuery._id.$nin, [reservedVehicleId]);
    assert.equal(vehicleQuery.disponible, true);
    assert.deepEqual(res.body.data, [availableVehicle]);
  } finally {
    Reservation.distinct = originalDistinct;
    Vehicle.find = originalFind;
  }
});

test('clients cannot choose another reservation owner', async () => {
  const originalCreate = Reservation.create;
  let wasCreated = false;
  Reservation.create = async () => {
    wasCreated = true;
  };

  try {
    const res = response();
    await reservationController.createReservation({
      user: {
        _id: new mongoose.Types.ObjectId(),
        role: 'client',
        status: 'active'
      },
      body: {
        vehicleId: new mongoose.Types.ObjectId().toString(),
        clientId: new mongoose.Types.ObjectId().toString(),
        pickupDate: futureDate(2),
        returnDate: futureDate(3),
        pickupLocation: 'Tunis',
        returnLocation: 'Tunis'
      }
    }, res);

    assert.equal(res.statusCode, 400);
    assert.equal(wasCreated, false);
  } finally {
    Reservation.create = originalCreate;
  }
});
