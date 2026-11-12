// Run from carrent-backend: node tests/reservation-day-uniqueness.experiment.js
// Isolated experiment only. Never imports or changes the application models.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const path = require('node:path');
const mongoose = require('mongoose');
const { generateReservedDays } = require('../utils/reservationDates');

require('dotenv').config({
  path: path.join(__dirname, '..', '.env'),
  quiet: true
});

function dateLabels(days) {
  return days.map(function (date) {
    return date.toISOString().slice(0, 10);
  });
}

async function runExperiment() {
  const databaseName = 'carrent_day_unique_test_' + randomUUID().replaceAll('-', '');
  let connection;
  let createdByThisRun = false;
  let step = 'G: UTC calendar date generation';

  try {
    assert.deepEqual(dateLabels(generateReservedDays('2026-11-10', '2026-11-13')),
      ['2026-11-10', '2026-11-11', '2026-11-12']);
    assert.deepEqual(dateLabels(generateReservedDays('2026-04-29', '2026-05-02')),
      ['2026-04-29', '2026-04-30', '2026-05-01']);
    assert.deepEqual(dateLabels(generateReservedDays('2026-12-30', '2027-01-02')),
      ['2026-12-30', '2026-12-31', '2027-01-01']);
    assert.deepEqual(dateLabels(generateReservedDays('2028-02-28', '2028-03-01')),
      ['2028-02-28', '2028-02-29']);
    assert.equal(generateReservedDays('2026-11-01', '2026-12-01').length, 30);

    const invalidRanges = [
      ['2026-11-10', '2026-11-10'],
      ['2026-11-13', '2026-11-10'],
      ['2026-11-01', '2026-12-02'],
      ['2026-02-30', '2026-03-02'],
      ['2026-11-10', '2026-11-31'],
      ['2026-1-10', '2026-11-13'],
      ['2027-02-29', '2027-03-01']
    ];
    for (const range of invalidRanges) {
      assert.throws(function () {
        generateReservedDays(range[0], range[1]);
      });
    }
    console.log('G PASS: UTC dates, return excluded, month/year/leap boundaries, and 1–30 day limit.');

    step = 'temporary database safety checks';
    assert.match(databaseName, /^carrent_day_unique_test_[a-f0-9]{32}$/);
    if (!process.env.MONGO_URI) {
      throw new Error('Configure MONGO_URI before running the database experiment.');
    }

    // dbName overrides the normal database. Automatic writes are disabled until
    // we have checked that this exact temporary database does not already exist.
    connection = mongoose.createConnection(process.env.MONGO_URI, {
      dbName: databaseName,
      autoCreate: false,
      autoIndex: false,
      serverSelectionTimeoutMS: 5000
    });
    await connection.asPromise();
    assert.equal(connection.name, databaseName);
    const existing = await connection.db.admin().listDatabases({
      nameOnly: true,
      filter: { name: databaseName }
    });
    assert.equal(existing.databases.length, 0,
      'Refusing to use or remove a database that already exists.');
    await connection.db.createCollection('experimental_reservations');
    createdByThisRun = true;
    console.log('Temporary database created: ' + databaseName);

    const experimentalSchema = new mongoose.Schema({
      vehicleId: { type: mongoose.Schema.Types.ObjectId, required: true },
      // Intentionally no complete-date-range validator: case H proves the gap.
      reservedDays: { type: [Date], required: true },
      status: {
        type: String,
        required: true,
        enum: ['confirmed', 'cancelled'],
        default: 'confirmed'
      }
    });
    experimentalSchema.index(
      { vehicleId: 1, reservedDays: 1 },
      {
        name: 'unique_confirmed_vehicle_day',
        unique: true,
        partialFilterExpression: { status: 'confirmed' }
      }
    );

    const ExperimentalReservation = connection.model(
      'ExperimentalReservation', experimentalSchema, 'experimental_reservations'
    );
    step = 'building and verifying the unique index';
    await ExperimentalReservation.createIndexes();
    const indexes = await ExperimentalReservation.collection.indexes();
    const index = indexes.find(function (item) {
      return item.name === 'unique_confirmed_vehicle_day';
    });
    assert.ok(index);
    assert.equal(index.unique, true);
    assert.deepEqual(index.key, { vehicleId: 1, reservedDays: 1 });
    assert.deepEqual(index.partialFilterExpression, { status: 'confirmed' });
    console.log('Index build completed and verified before any document inserts.');

    async function saveBooking(vehicleId, pickup, end, status = 'confirmed') {
      const reservation = new ExperimentalReservation({
        vehicleId,
        reservedDays: generateReservedDays(pickup, end),
        status
      });
      return await reservation.save();
    }

    // Each case uses fresh IDs, so earlier cases cannot affect later cases.
    step = 'A: sequential overlapping inserts';
    const vehicleA = new mongoose.Types.ObjectId();
    await saveBooking(vehicleA, '2026-11-10', '2026-11-13');
    await assert.rejects(
      saveBooking(vehicleA, '2026-11-12', '2026-11-15'), { code: 11000 }
    );
    assert.equal(await ExperimentalReservation.countDocuments({ vehicleId: vehicleA }), 1);
    console.log('A PASS: second overlapping confirmed insert rejected with code 11000.');

    step = 'B: simultaneous overlapping inserts';
    const vehicleB = new mongoose.Types.ObjectId();
    const results = await Promise.allSettled([
      saveBooking(vehicleB, '2026-11-10', '2026-11-13'),
      saveBooking(vehicleB, '2026-11-12', '2026-11-15')
    ]);
    const successes = results.filter(function (result) {
      return result.status === 'fulfilled';
    });
    const failures = results.filter(function (result) {
      return result.status === 'rejected';
    });
    assert.equal(successes.length, 1);
    assert.equal(failures.length, 1);
    assert.equal(failures[0].reason.code, 11000);
    assert.equal(await ExperimentalReservation.countDocuments({ vehicleId: vehicleB }), 1);
    console.log('B PASS: simultaneous inserts produced exactly one success and one duplicate-key error.');

    step = 'C: adjacent reservations';
    const vehicleC = new mongoose.Types.ObjectId();
    await saveBooking(vehicleC, '2026-11-10', '2026-11-13');
    await saveBooking(vehicleC, '2026-11-13', '2026-11-15');
    assert.equal(await ExperimentalReservation.countDocuments({ vehicleId: vehicleC }), 2);
    console.log('C PASS: adjacent confirmed reservations both saved.');

    step = 'D: different vehicles';
    const vehicleD1 = new mongoose.Types.ObjectId();
    const vehicleD2 = new mongoose.Types.ObjectId();
    await saveBooking(vehicleD1, '2026-11-10', '2026-11-13');
    await saveBooking(vehicleD2, '2026-11-10', '2026-11-13');
    assert.equal(await ExperimentalReservation.countDocuments({
      vehicleId: { $in: [vehicleD1, vehicleD2] }
    }), 2);
    console.log('D PASS: different vehicles can share the same dates.');

    step = 'E: cancelled reservations';
    const vehicleE = new mongoose.Types.ObjectId();
    await saveBooking(vehicleE, '2026-11-10', '2026-11-13', 'cancelled');
    await saveBooking(vehicleE, '2026-11-10', '2026-11-13');
    assert.equal(await ExperimentalReservation.countDocuments({ vehicleId: vehicleE }), 2);
    console.log('E PASS: an already cancelled reservation does not block a confirmed one.');

    step = 'F: cancellation releases indexed dates';
    const vehicleF = new mongoose.Types.ObjectId();
    const original = await saveBooking(vehicleF, '2026-11-10', '2026-11-13');
    original.status = 'cancelled';
    await original.save();
    await saveBooking(vehicleF, '2026-11-10', '2026-11-13');
    assert.equal(await ExperimentalReservation.countDocuments({ vehicleId: vehicleF }), 2);
    assert.equal((await ExperimentalReservation.findById(original._id)).status, 'cancelled');
    console.log('F PASS: changing status to cancelled releases dates and retains the old record.');

    step = 'H: incomplete reservedDays limitation';
    const vehicleH = new mongoose.Types.ObjectId();
    const intendedDays = generateReservedDays('2026-11-10', '2026-11-13');
    const incomplete = new ExperimentalReservation({
      vehicleId: vehicleH,
      reservedDays: [intendedDays[0]],
      status: 'confirmed'
    });
    await incomplete.save();
    // November 11 overlaps the intended range, but is absent from the bad array.
    await saveBooking(vehicleH, '2026-11-11', '2026-11-12');
    assert.equal(incomplete.reservedDays.length, 1);
    assert.equal(intendedDays.length, 3);
    assert.equal(await ExperimentalReservation.countDocuments({ vehicleId: vehicleH }), 2);
    console.log('H PASS: incomplete days were accepted; the index alone cannot validate the intended range.');
  } catch (error) {
    // Connection error text can contain secrets. Show only safe identifiers.
    console.error('FAILED during ' + step + ': ' + error.name
      + (error.code ? ' (code ' + error.code + ')' : ''));
    if (error instanceof assert.AssertionError) console.error(error.message);
    throw error;
  } finally {
    if (connection) {
      try {
        if (createdByThisRun) {
          assert.match(databaseName, /^carrent_day_unique_test_[a-f0-9]{32}$/);
          assert.equal(connection.name, databaseName);
          assert.equal(connection.db.databaseName, databaseName);
          await connection.dropDatabase();
          const remaining = await connection.db.admin().listDatabases({
            nameOnly: true, filter: { name: databaseName }
          });
          assert.equal(remaining.databases.length, 0);
          console.log('Cleanup PASS: this run’s temporary database and all records removed.');
        }
      } finally {
        await connection.close();
      }
    }
  }
  console.log('All cases A–H passed. No application database, model, or endpoint was changed.');
}

runExperiment().catch(function (error) {
  console.error('Experiment or cleanup failed: ' + error.name
    + (error.code ? ' (code ' + error.code + ')' : ''));
  process.exitCode = 1;
});
