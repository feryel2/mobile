const test = require('node:test');
const assert = require('node:assert/strict');
const Reservation = require('../models/Reservation');
const reservationController = require('../controllers/reservationController');

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

test('admin reservation list filters status and populates client and vehicle details', async () => {
  const originalFind = Reservation.find;
  const rows = [{ _id: 'reservation-1' }];
  let filter;
  const sort = { pickupDate: -1, createdAt: -1 };
  const populates = [];
  const query = {
    sort(value) {
      assert.deepEqual(value, sort);
      return this;
    },
    populate(path, fields) {
      populates.push([path, fields]);
      return this;
    },
    then(resolve, reject) {
      return Promise.resolve(rows).then(resolve, reject);
    }
  };
  Reservation.find = (value) => {
    filter = value;
    return query;
  };

  try {
    const res = response();
    await reservationController.getAllReservations({
      query: { status: 'confirmed' }
    }, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.success, true);
    assert.deepEqual(res.body.data, rows);
    assert.deepEqual(filter, { status: 'confirmed' });
    assert.deepEqual(populates, [
      ['vehicleId', 'marque modele immatriculation image prix'],
      ['clientId', 'fullname email phone']
    ]);
  } finally {
    Reservation.find = originalFind;
  }
});

test('admin reservation list rejects unsupported filters before querying', async () => {
  const originalFind = Reservation.find;
  Reservation.find = () => {
    assert.fail('invalid status must not query reservations');
  };

  try {
    const res = response();
    await reservationController.getAllReservations({
      query: { status: 'pending' }
    }, res);

    assert.equal(res.statusCode, 400);
    assert.equal(res.body.success, false);
  } finally {
    Reservation.find = originalFind;
  }
});
