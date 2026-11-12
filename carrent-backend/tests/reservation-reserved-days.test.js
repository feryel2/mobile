// Run from carrent-backend: node tests/reservation-reserved-days.test.js
// Uses the real schema, but builds indexes and writes only in a new test database.
const assert = require('node:assert/strict');
const { randomUUID, createHash } = require('node:crypto');
const { spawn } = require('node:child_process');
const path = require('node:path');
const net = require('node:net');
const mongoose = require('mongoose');
// Already installed with the MongoDB driver; no extra dependency is installed.
const ConnectionString = require('mongodb-connection-string-url').default;
const Reservation = require('../models/Reservation');
const { generateReservedDays } = require('../utils/reservationDates');

require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let memoryCases = 0;
let databaseCases = 0;
let httpCases = 0;

function booking(vehicleId, pickupDate, returnDate, changes = {}) {
  return {
    vehicleId,
    clientId: new mongoose.Types.ObjectId(),
    pickupDate,
    returnDate,
    reservedDays: generateReservedDays(pickupDate, returnDate),
    pickupLocation: 'Temporary test location',
    returnLocation: 'Temporary test location',
    dailyPriceMillimes: 50000,
    totalPriceMillimes: 150000,
    ...changes
  };
}

async function checkMemoryValidation() {
  const input = booking(new mongoose.Types.ObjectId(), '2026-11-10', '2026-11-13');
  async function accepts(changes) {
    const document = new Reservation({ ...input, ...changes });
    await document.validate();
    memoryCases++;
    return document;
  }
  async function rejects(changes, field) {
    const document = new Reservation({ ...input, ...changes });
    await assert.rejects(document.validate(), error => {
      assert.ok(error instanceof mongoose.Error.ValidationError);
      if (field) assert.ok(Object.keys(error.errors).some(key => key.startsWith(field)));
      return true;
    });
    memoryCases++;
  }

  assert.equal(mongoose.connection.readyState, 0);
  assert.equal((await accepts({})).status, 'confirmed');
  await accepts(booking(input.vehicleId, '2026-11-10', '2026-11-11'));
  await accepts(booking(input.vehicleId, '2026-11-01', '2026-12-01'));
  await accepts(booking(input.vehicleId, '2026-12-30', '2027-01-02'));
  await accepts({ dailyPriceMillimes: 0, totalPriceMillimes: 0 });
  await accepts({ status: 'cancelled', reservedDays: undefined });
  await accepts({ status: 'cancelled', reservedDays: [] });

  for (const field of Object.keys(input)) await rejects({ [field]: undefined }, field);
  await rejects({ reservedDays: null }, 'reservedDays');
  await rejects({ reservedDays: [] }, 'reservedDays');
  await rejects({ reservedDays: input.reservedDays.slice(0, 2) }, 'reservedDays');
  await rejects({ reservedDays: [input.reservedDays[0], input.reservedDays[0], input.reservedDays[2]] }, 'reservedDays');
  await rejects({ reservedDays: [...input.reservedDays, new Date('2026-11-13T00:00:00Z')] }, 'reservedDays');
  await rejects({ reservedDays: [...input.reservedDays].reverse() }, 'reservedDays');
  await rejects({ reservedDays: ['2026-11-10', '2026-11-11', 'not-a-date'] }, 'reservedDays');
  await rejects({ reservedDays: ['2026-11-10', '2026-11-11', null] }, 'reservedDays');
  await rejects({ reservedDays: [new Date('invalid')] }, 'reservedDays');
  await rejects({ reservedDays: [new Date('2026-11-10T01:00:00Z'), ...input.reservedDays.slice(1)] }, 'reservedDays');
  await rejects({ reservedDays: '2026-11-10' }, 'reservedDays');
  // A setter must reject invalid source dates even if JavaScript could normalize them.
  await rejects({ pickupDate: '2026-02-30' }, 'pickupDate');
  await rejects({ returnDate: '2026-11-31' }, 'returnDate');
  await rejects({ pickupDate: new Date('2026-11-10T01:00:00Z') }, 'pickupDate');
  await rejects({ returnDate: input.pickupDate }, 'returnDate');
  await rejects({ returnDate: '2026-11-09' }, 'returnDate');
  await rejects(booking(input.vehicleId, '2026-03-02', '2026-03-03', {
    reservedDays: ['2026-02-30']
  }), 'reservedDays');
  const days31 = [];
  for (let day = 0; day < 31; day++) days31.push(new Date(Date.UTC(2026, 10, 1 + day)));
  await rejects({ pickupDate: '2026-11-01', returnDate: '2026-12-02', reservedDays: days31 }, 'reservedDays');
  for (const field of ['dailyPriceMillimes', 'totalPriceMillimes']) {
    await rejects({ [field]: -1 }, field);
    await rejects({ [field]: 50000.5 }, field);
  }
  await rejects({ vehicleId: 'invalid' }, 'vehicleId');
  await rejects({ clientId: 'invalid' }, 'clientId');
  await rejects({ pickupLocation: '' }, 'pickupLocation');
  await rejects({ returnLocation: '' }, 'returnLocation');
  await rejects({ status: 'pending' }, 'status');
  await rejects({ status: null }, 'status');

  const changed = await accepts({});
  changed.returnDate = '2026-11-14';
  await assert.rejects(changed.validate(), mongoose.Error.ValidationError);
  memoryCases++;
  const reactivated = await accepts({ status: 'cancelled', reservedDays: undefined });
  reactivated.status = 'confirmed';
  await assert.rejects(reactivated.validate(), mongoose.Error.ValidationError);
  memoryCases++;
  assert.equal(Reservation.schema.options.timestamps, true);
  assert.equal(Reservation.schema.options.autoIndex, false);
  assert.equal(Reservation.schema.options.autoCreate, false);
  console.log(memoryCases + ' in-memory validation cases passed. No database connection opened for these checks.');
}

async function normalDatabaseSnapshot(client) {
  const db = client.db();
  const exists = await db.listCollections({ name: 'reservations' }, { nameOnly: true }).toArray();
  if (!exists.length) return { exists: false };
  const records = await db.collection('reservations').find({}).sort({ _id: 1 }).toArray();
  const indexes = await db.collection('reservations').indexes();
  return {
    exists: true,
    recordsHash: createHash('sha256').update(JSON.stringify(records)).digest('hex'),
    indexesHash: createHash('sha256').update(JSON.stringify(indexes)).digest('hex')
  };
}

async function startTestServer(uri) {
  const probe = net.createServer();
  await new Promise((resolve, reject) => {
    probe.once('error', reject);
    probe.listen(0, '127.0.0.1', resolve);
  });
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  const child = spawn(process.execPath, ['server.js'], {
    cwd: path.join(__dirname, '..'),
    env: { ...process.env, MONGO_URI: uri, PORT: String(port), NODE_ENV: 'development' },
    windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe']
  });
  child.stdout.on('data', function () {});
  child.stderr.on('data', function () {});
  const server = { child, base: 'http://127.0.0.1:' + port };
  try {
    for (let attempt = 0; attempt < 60; attempt++) {
      try {
        const response = await fetch(server.base + '/health', { signal: AbortSignal.timeout(1000) });
        const health = await response.json();
        if (response.status === 200 && health.database.connected) return server;
      } catch (error) {
        if (child.exitCode !== null) throw new Error('Temporary server exited.');
      }
      await delay(100);
    }
    throw new Error('Temporary server did not connect.');
  } catch (error) {
    await stopTestServer(server);
    throw error;
  }
}

async function stopTestServer(server) {
  if (server && server.child.exitCode === null && server.child.signalCode === null) {
    await new Promise(resolve => {
      server.child.once('exit', resolve);
      server.child.kill();
    });
  }
}

async function request(server, route, status, method = 'GET') {
  const response = await fetch(server.base + route, { method, signal: AbortSignal.timeout(5000) });
  assert.equal(response.status, status, route);
  httpCases++;
  return await response.json();
}

async function runTests() {
  const databaseName = 'carrent_reserved_model_test_' + randomUUID().replaceAll('-', '');
  let connection;
  let normalClient;
  let before;
  let server;
  let createdByThisRun = false;
  let step = 'in-memory validation';
  try {
    await checkMemoryValidation();
    if (!process.env.MONGO_URI) throw new Error('MONGO_URI is required.');
    step = 'read-only normal-database snapshot and temporary database checks';
    normalClient = new mongoose.mongo.MongoClient(process.env.MONGO_URI, { serverSelectionTimeoutMS: 5000 });
    await normalClient.connect();
    before = await normalDatabaseSnapshot(normalClient);
    assert.match(databaseName, /^carrent_reserved_model_test_[a-f0-9]{32}$/);
    assert.notEqual(normalClient.db().databaseName, databaseName);
    connection = mongoose.createConnection(process.env.MONGO_URI, {
      dbName: databaseName, autoIndex: false, autoCreate: false, serverSelectionTimeoutMS: 5000
    });
    await connection.asPromise();
    assert.equal(connection.name, databaseName);
    const existing = await connection.db.admin().listDatabases({ nameOnly: true, filter: { name: databaseName } });
    assert.equal(existing.databases.length, 0);
    await connection.db.createCollection('reservations');
    createdByThisRun = true;
    const TestReservation = connection.model('Reservation', Reservation.schema, 'reservations');
    await TestReservation.init();

    // Give the actual unchanged server only the isolated database URI.
    const uri = new ConnectionString(process.env.MONGO_URI);
    if (uri.username && !uri.searchParams.has('authSource')) {
      uri.searchParams.set('authSource', uri.pathname.slice(1) || 'admin');
    }
    uri.pathname = '/' + databaseName;
    assert.equal(new ConnectionString(uri.toString()).pathname, '/' + databaseName);
    server = await startTestServer(uri.toString());
    step = 'automatic index creation remains disabled';
    let indexes = await TestReservation.collection.indexes();
    assert.deepEqual(indexes.map(index => index.name), ['_id_']);
    databaseCases++;

    step = 'explicit index build in temporary database only';
    assert.equal(connection.name, databaseName);
    await TestReservation.createIndexes();
    indexes = await TestReservation.collection.indexes();
    const index = indexes.find(item => item.name === 'unique_confirmed_vehicle_day');
    assert.ok(index);
    assert.equal(index.unique, true);
    assert.deepEqual(index.key, { vehicleId: 1, reservedDays: 1 });
    assert.deepEqual(index.partialFilterExpression, { status: 'confirmed' });
    databaseCases++;

    async function save(vehicle, pickup, end, changes = {}) {
      const document = new TestReservation(booking(vehicle, pickup, end, changes));
      return await document.save();
    }

    step = 'sequential and simultaneous conflicts';
    const vehicleA = new mongoose.Types.ObjectId();
    await save(vehicleA, '2026-11-10', '2026-11-13');
    await assert.rejects(save(vehicleA, '2026-11-12', '2026-11-15'), { code: 11000 });
    assert.equal(await TestReservation.countDocuments({ vehicleId: vehicleA }), 1);
    databaseCases++;
    const vehicleB = new mongoose.Types.ObjectId();
    const results = await Promise.allSettled([
      save(vehicleB, '2026-11-10', '2026-11-13'),
      save(vehicleB, '2026-11-12', '2026-11-15')
    ]);
    assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
    const rejected = results.filter(result => result.status === 'rejected');
    assert.equal(rejected.length, 1);
    assert.equal(rejected[0].reason.code, 11000);
    assert.equal(await TestReservation.countDocuments({ vehicleId: vehicleB }), 1);
    databaseCases++;

    step = 'adjacent bookings and different vehicles';
    const vehicleC = new mongoose.Types.ObjectId();
    await save(vehicleC, '2026-11-10', '2026-11-13');
    await save(vehicleC, '2026-11-13', '2026-11-15');
    assert.equal(await TestReservation.countDocuments({ vehicleId: vehicleC }), 2);
    databaseCases++;
    const differentA = new mongoose.Types.ObjectId();
    const differentB = new mongoose.Types.ObjectId();
    await save(differentA, '2026-11-10', '2026-11-13');
    await save(differentB, '2026-11-10', '2026-11-13');
    assert.equal(await TestReservation.countDocuments({ vehicleId: { $in: [differentA, differentB] } }), 2);
    databaseCases++;

    step = 'saving invalid date changes requires a rebuilt day list';
    const changed = await save(new mongoose.Types.ObjectId(), '2026-11-10', '2026-11-11');
    changed.returnDate = '2026-11-12';
    await assert.rejects(changed.save(), mongoose.Error.ValidationError);
    assert.equal((await TestReservation.findById(changed._id)).returnDate.toISOString().slice(0, 10), '2026-11-11');
    changed.reservedDays = generateReservedDays(changed.pickupDate, changed.returnDate);
    await changed.save();
    assert.equal((await TestReservation.findById(changed._id)).reservedDays.length, 2);
    databaseCases++;

    step = 'existing HTTP endpoints and cancellation release';
    const clientId = new mongoose.Types.ObjectId();
    const vehicleF = new mongoose.Types.ObjectId();
    const original = await save(vehicleF, '2026-11-10', '2026-11-13', { clientId });
    const query = '/reservations/check-conflict?' + new URLSearchParams({
      vehicleId: vehicleF.toString(), pickupDate: '2026-11-11', returnDate: '2026-11-12'
    });
    assert.equal((await request(server, '/health', 200)).database.connected, true);
    assert.equal((await request(server, query, 200)).hasConflict, true);
    await request(server, '/reservations/check-conflict?vehicleId=bad', 400);
    await request(server, '/reservations/client/bad', 400);
    assert.deepEqual(await request(server, '/reservations/client/' + new mongoose.Types.ObjectId(), 200), []);
    const cancelled = await request(server, '/reservations/' + original._id + '/cancel', 200, 'POST');
    assert.equal(cancelled.reservation.status, 'cancelled');
    assert.equal((await request(server, query, 200)).hasConflict, false);
    const again = await request(server, '/reservations/' + original._id + '/cancel', 200, 'POST');
    assert.equal(again.message, 'Cette réservation est déjà annulée.');
    await request(server, '/reservations/' + new mongoose.Types.ObjectId() + '/cancel', 404, 'POST');
    await request(server, '/reservations/bad/cancel', 400, 'POST');
    const replacement = await save(vehicleF, '2026-11-10', '2026-11-13', { clientId });
    assert.equal((await request(server, query, 200)).hasConflict, true);
    const history = await request(server, '/reservations/client/' + clientId, 200);
    assert.equal(history.length, 2);
    assert.equal(history.find(item => item._id === original._id.toString()).status, 'cancelled');
    assert.equal(history.find(item => item._id === replacement._id.toString()).status, 'confirmed');
    assert.equal(await TestReservation.countDocuments({ vehicleId: vehicleF }), 2);
    databaseCases++;
    console.log(databaseCases + ' database/index cases and ' + httpCases + ' HTTP checks passed.');
  } catch (error) {
    console.error('FAILED during ' + step + ': ' + error.name
      + (error.code ? ' (code ' + error.code + ')' : ''));
    if (error instanceof assert.AssertionError) console.error(error.message);
    throw error;
  } finally {
    try {
      await stopTestServer(server);
      if (connection) {
        try {
          if (createdByThisRun) {
            assert.match(databaseName, /^carrent_reserved_model_test_[a-f0-9]{32}$/);
            assert.equal(connection.name, databaseName);
            assert.equal(connection.db.databaseName, databaseName);
            await connection.dropDatabase();
            const remaining = await connection.db.admin().listDatabases({ nameOnly: true, filter: { name: databaseName } });
            assert.equal(remaining.databases.length, 0);
            console.log('Temporary database and all test records removed.');
          }
        } finally {
          await connection.close();
        }
      }
      if (normalClient && before) {
        assert.deepEqual(await normalDatabaseSnapshot(normalClient), before);
        console.log('Normal database reservation data and indexes remained unchanged.');
      }
    } finally {
      if (normalClient) await normalClient.close();
    }
  }
  console.log('Reserved-days model integration tests passed.');
}

runTests().catch(function (error) {
  console.error('Tests or cleanup failed: ' + error.name
    + (error.code ? ' (code ' + error.code + ')' : ''));
  process.exitCode = 1;
});
