// Fixture-based writes are allowed only in this run's new temporary database.
const assert = require('node:assert/strict');
const { randomUUID, createHash } = require('node:crypto');
const { spawn } = require('node:child_process');
const net = require('node:net');
const path = require('node:path');
const mongoose = require('mongoose');
// Already installed by the MongoDB driver; no new package is needed.
const ConnectionString = require('mongodb-connection-string-url').default;
const Reservation = require('../models/Reservation');
const controller = require('../controllers/reservationController');
const demo = require('../fixtures/reservationCreationDemo');
const { checkConfiguration } = require('../scripts/setupReservationIndex');

require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let httpChecks = 0;
let localGuardChecks = 0;

function input(changes = {}) {
  return {
    vehicleId: demo.vehicles[0].id, clientId: demo.clientIds[0],
    pickupDate: '2026-11-10', returnDate: '2026-11-13',
    pickupLocation: demo.locations[0], returnLocation: demo.locations[1], ...changes
  };
}

async function checkRemoteRequests() {
  const previousEnvironment = process.env.NODE_ENV;
  const previousFlag = process.env.ENABLE_RESERVATION_CREATION_TESTS;
  try {
    process.env.NODE_ENV = 'development';
    process.env.ENABLE_RESERVATION_CREATION_TESTS = 'true';
    for (const address of ['203.0.113.10', '::ffff:203.0.113.10', undefined]) {
      const req = { socket: { remoteAddress: address }, body: input(),
        headers: { 'x-forwarded-for': '127.0.0.1' } };
      const res = {
        status(code) { this.statusCode = code; return this; },
        json(body) { this.body = body; return this; }
      };
      await controller.createReservation(req, res);
      assert.equal(res.statusCode, 403);
      localGuardChecks++;
    }
    assert.equal(mongoose.connection.readyState, 0);
  } finally {
    if (previousEnvironment === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousEnvironment;
    if (previousFlag === undefined) delete process.env.ENABLE_RESERVATION_CREATION_TESTS;
    else process.env.ENABLE_RESERVATION_CREATION_TESTS = previousFlag;
  }
}

async function unusedPort() {
  const probe = net.createServer();
  await new Promise((resolve, reject) => {
    probe.once('error', reject);
    probe.listen(0, '127.0.0.1', resolve);
  });
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  return port;
}

async function startServer(uri, settings = {}) {
  const port = await unusedPort();
  const child = spawn(process.execPath, ['server.js'], {
    cwd: path.join(__dirname, '..'), windowsHide: true, stdio: 'ignore',
    env: { ...process.env, MONGO_URI: uri, PORT: String(port),
      NODE_ENV: settings.environment === undefined ? 'development' : settings.environment,
      ENABLE_RESERVATION_CREATION_TESTS: settings.flag === undefined ? 'true' : settings.flag }
  });
  const server = { child, base: 'http://127.0.0.1:' + port };
  server.exited = new Promise(resolve => child.once('exit', resolve));
  let startupError;
  child.once('error', error => { startupError = error; });
  try {
    for (let attempt = 0; attempt < 80; attempt++) {
      if (startupError || child.exitCode !== null) throw new Error('Test server could not start.');
      try {
        const response = await fetch(server.base + '/health', { signal: AbortSignal.timeout(500) });
        const health = await response.json();
        if (response.status === 200 && (settings.disconnected
          ? health.database.status === 'disconnected' : health.database.connected)) return server;
      } catch (error) {}
      await delay(100);
    }
    throw new Error('Test server did not reach the expected database state.');
  } catch (error) {
    await stopServer(server);
    throw error;
  }
}

async function stopServer(server) {
  if (server && server.child.exitCode === null && server.child.signalCode === null) {
    server.child.kill();
    await server.exited;
  }
}

async function request(server, route, status, method = 'GET', body) {
  const response = await fetch(server.base + route, {
    method, headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(5000)
  });
  if (Array.isArray(status)) assert.ok(status.includes(response.status));
  else assert.equal(response.status, status, method + ' ' + route);
  const data = await response.json();
  httpChecks++;
  return { status: response.status, data };
}

async function normalSnapshot(db) {
  const collections = await db.listCollections().toArray();
  const snapshot = [];
  for (const info of collections.sort((a, b) => a.name.localeCompare(b.name))) {
    assert.equal(info.type, 'collection');
    const records = await db.collection(info.name).find({}).sort({ _id: 1 }).toArray();
    const indexes = await db.collection(info.name).indexes();
    snapshot.push({ name: info.name, options: info.options,
      recordsHash: createHash('sha256').update(JSON.stringify(records)).digest('hex'),
      indexesHash: createHash('sha256').update(JSON.stringify(indexes)).digest('hex') });
  }
  return snapshot;
}

async function runTests() {
  await checkRemoteRequests();
  const databaseName = 'carrent_creation_test_' + randomUUID().replaceAll('-', '');
  let connection;
  let normalClient;
  let normalBefore;
  let server;
  let createdByThisRun = false;
  let step = 'database safety checks';

  function assertOwnedDatabase() {
    assert.match(databaseName, /^carrent_creation_test_[a-f0-9]{32}$/);
    assert.equal(connection.name, databaseName);
    assert.equal(connection.db.databaseName, databaseName);
    assert.equal(createdByThisRun, true);
  }

  try {
    checkConfiguration(process.env.MONGO_URI, 'development');
    normalClient = new mongoose.mongo.MongoClient(process.env.MONGO_URI, {
      directConnection: true, serverSelectionTimeoutMS: 5000
    });
    await normalClient.connect();
    assert.equal(normalClient.db().databaseName, 'carrent');
    normalBefore = await normalSnapshot(normalClient.db());

    const uri = new ConnectionString(process.env.MONGO_URI);
    if (uri.username && !uri.searchParams.has('authSource')) {
      uri.searchParams.set('authSource', uri.pathname.slice(1) || 'admin');
    }
    uri.pathname = '/' + databaseName;
    uri.searchParams.set('directConnection', 'true');
    assert.equal(new ConnectionString(uri.toString()).pathname, '/' + databaseName);
    connection = mongoose.createConnection(uri.toString(), {
      autoCreate: false, autoIndex: false, serverSelectionTimeoutMS: 5000
    });
    await connection.asPromise();
    assert.equal(connection.name, databaseName);
    const db = connection.db;
    const existing = await db.admin().listDatabases({ nameOnly: true, filter: { name: databaseName } });
    assert.equal(existing.databases.length, 0, 'Refusing to reuse an existing database.');
    await db.createCollection('test_ownership');
    createdByThisRun = true;
    assertOwnedDatabase();

    step = 'missing collection and index must disable writes';
    server = await startServer(uri.toString());
    await request(server, '/reservations', 503, 'POST', input());
    assert.equal((await db.listCollections({ name: 'reservations' }).toArray()).length, 0);
    await stopServer(server);
    const collection = await db.createCollection('reservations');
    server = await startServer(uri.toString());
    await request(server, '/reservations', 503, 'POST', input());
    assert.equal(await collection.countDocuments(), 0);
    await stopServer(server);

    step = 'a wrongly defined index must disable writes';
    await collection.createIndex({ vehicleId: 1, reservedDays: 1 }, {
      name: 'unique_confirmed_vehicle_day', unique: true,
      partialFilterExpression: { status: 'cancelled' }
    });
    server = await startServer(uri.toString());
    await request(server, '/reservations', 503, 'POST', input());
    assert.equal(await collection.countDocuments(), 0);
    await stopServer(server);
    assertOwnedDatabase();
    await collection.dropIndex('unique_confirmed_vehicle_day');

    step = 'explicit correct index build before allowing successful writes';
    const TestReservation = connection.model('Reservation', Reservation.schema, 'reservations');
    await TestReservation.createIndexes();
    const index = (await collection.indexes()).find(item => item.name === 'unique_confirmed_vehicle_day');
    assert.ok(index);
    assert.equal(index.unique, true);
    assert.deepEqual(Object.entries(index.key), [['vehicleId', 1], ['reservedDays', 1]]);
    assert.deepEqual(index.partialFilterExpression, { status: 'confirmed' });
    console.log('Temporary unique index built and verified before any successful creation.');
    server = await startServer(uri.toString());

    step = 'successful saves, trusted rates, totals and different vehicles';
    assert.equal((await request(server, '/health', 200)).data.database.connected, true);
    const saved = [];
    for (let i = 0; i < 3; i++) {
      const body = input({ vehicleId: demo.vehicles[i].id, clientId: demo.clientIds[i % 2] });
      const reservation = (await request(server, '/reservations', 201, 'POST', body)).data;
      assert.equal(reservation.vehicleId, body.vehicleId);
      assert.equal(reservation.clientId, body.clientId);
      assert.equal(reservation.pickupLocation, body.pickupLocation);
      assert.equal(reservation.returnLocation, body.returnLocation);
      assert.equal(reservation.dailyPriceMillimes, [50000, 70000, 40000][i]);
      assert.equal(reservation.totalPriceMillimes, [150000, 210000, 120000][i]);
      assert.equal(reservation.status, 'confirmed');
      assert.deepEqual(reservation.reservedDays.map(day => day.slice(0, 10)),
        ['2026-11-10', '2026-11-11', '2026-11-12']);
      assert.equal(reservation.pickupDate, '2026-11-10T00:00:00.000Z');
      assert.equal(reservation.returnDate, '2026-11-13T00:00:00.000Z');
      assert.ok(mongoose.isObjectIdOrHexString(reservation._id));
      assert.ok(reservation.createdAt && reservation.updatedAt);
      const stored = await collection.findOne({ _id: new mongoose.Types.ObjectId(reservation._id) });
      assert.ok(stored.vehicleId instanceof mongoose.Types.ObjectId);
      assert.ok(stored.reservedDays[0] instanceof Date);
      saved.push(reservation);
    }
    assert.equal(await collection.countDocuments(), 3);

    step = 'existing client history filters and sorts the saved reservations';
    const history = (await request(server, '/reservations/client/' + demo.clientIds[0], 200)).data;
    assert.equal(history.length, 2);
    assert.ok(history.every(item => item.clientId === demo.clientIds[0]));
    assert.ok(new Date(history[0].createdAt) >= new Date(history[1].createdAt));
    const otherHistory = (await request(server, '/reservations/client/' + demo.clientIds[1], 200)).data;
    assert.deepEqual(otherHistory.map(item => item._id), [saved[1]._id]);

    step = 'one-day and 30-day bounds';
    const oneDay = (await request(server, '/reservations', 201, 'POST', input({
      pickupDate: '2026-11-20', returnDate: '2026-11-21'
    }))).data;
    assert.equal(oneDay.reservedDays.length, 1);
    assert.equal(oneDay.totalPriceMillimes, 50000);
    const thirtyDays = (await request(server, '/reservations', 201, 'POST', input({
      pickupDate: '2026-12-01', returnDate: '2026-12-31'
    }))).data;
    assert.equal(thirtyDays.reservedDays.length, 30);
    assert.equal(thirtyDays.totalPriceMillimes, 1500000);

    step = 'invalid input and backend-controlled fields never save';
    const beforeInvalid = await collection.countDocuments();
    const invalidInputs = [
      {}, undefined, [],
      input({ vehicleId: 'bad' }), input({ clientId: 'bad' }),
      input({ vehicleId: new mongoose.Types.ObjectId().toHexString() }),
      input({ clientId: new mongoose.Types.ObjectId().toHexString() }),
      input({ vehicleId: { $ne: null } }), input({ clientId: null }),
      input({ pickupLocation: 'Unknown location' }), input({ returnLocation: 'Unknown location' }),
      input({ pickupLocation: '   ' }),
      input({ pickupDate: '2026-02-30' }), input({ returnDate: '2026-11-31' }),
      input({ pickupDate: '2026-11-10T00:00:00.000Z' }), input({ pickupDate: '2026-1-10' }),
      input({ returnDate: '2026-11-10' }), input({ returnDate: '2026-11-09' }),
      input({ pickupDate: '2026-11-01', returnDate: '2026-12-02' }),
      input({ dailyPriceMillimes: 1 }), input({ totalPriceMillimes: 1 }),
      input({ status: 'cancelled' }), input({ reservedDays: [] }),
      input({ _id: new mongoose.Types.ObjectId().toHexString() }), input({ unexpectedField: true })
    ];
    for (const field of Object.keys(input())) {
      const missing = input();
      delete missing[field];
      invalidInputs.push(missing);
    }
    for (const body of invalidInputs) await request(server, '/reservations', 400, 'POST', body);
    assert.equal(await collection.countDocuments(), beforeInvalid);

    step = 'overlap is 409, adjacent dates are allowed';
    await request(server, '/reservations', 409, 'POST', input({ pickupDate: '2026-11-12', returnDate: '2026-11-15' }));
    await request(server, '/reservations', 201, 'POST', input({ pickupDate: '2026-11-13', returnDate: '2026-11-15' }));
    const query = '/reservations/check-conflict?' + new URLSearchParams({
      vehicleId: demo.vehicles[0].id, pickupDate: '2026-11-11', returnDate: '2026-11-12'
    });
    assert.equal((await request(server, query, 200)).data.hasConflict, true);

    step = 'simultaneous overlapping HTTP requests';
    assertOwnedDatabase();
    await collection.deleteMany({});
    const simultaneous = await Promise.all([
      request(server, '/reservations', [201, 409], 'POST', input()),
      request(server, '/reservations', [201, 409], 'POST', input({
        clientId: demo.clientIds[1], pickupDate: '2026-11-12', returnDate: '2026-11-15'
      }))
    ]);
    assert.deepEqual(simultaneous.map(item => item.status).sort(), [201, 409]);
    assert.equal(await collection.countDocuments(), 1);
    console.log('Simultaneous HTTP requests: exactly one 201, one 409, and one stored document.');

    step = 'cancellation releases dates and preserves history';
    assertOwnedDatabase();
    await collection.deleteMany({});
    const original = (await request(server, '/reservations', 201, 'POST', input())).data;
    const cancelled = (await request(server, '/reservations/' + original._id + '/cancel', 200, 'POST')).data;
    assert.equal(cancelled.reservation.status, 'cancelled');
    assert.equal(cancelled.reservation.reservedDays.length, 3);
    assert.equal((await request(server, query, 200)).data.hasConflict, false);
    await request(server, '/reservations/' + original._id + '/cancel', 200, 'POST');
    const replacement = (await request(server, '/reservations', 201, 'POST', input())).data;
    assert.equal((await request(server, query, 200)).data.hasConflict, true);
    const afterCancel = (await request(server, '/reservations/client/' + demo.clientIds[0], 200)).data;
    assert.equal(afterCancel.length, 2);
    assert.equal(afterCancel.find(item => item._id === original._id).status, 'cancelled');
    assert.equal(afterCancel.find(item => item._id === replacement._id).status, 'confirmed');
    assert.equal(await collection.countDocuments(), 2);
    await request(server, '/reservations/client/bad', 400);
    await request(server, '/reservations/bad/cancel', 400, 'POST');
    await request(server, '/reservations/' + new mongoose.Types.ObjectId() + '/cancel', 404, 'POST');
    await request(server, '/reservations/check-conflict', 400);
    await stopServer(server);

    step = 'flag and environment restrictions';
    const beforeBlocked = await collection.countDocuments();
    for (const settings of [{ flag: '' }, { flag: 'false' }, { environment: 'production' },
      { environment: 'test' }, { environment: '' }]) {
      server = await startServer(uri.toString(), settings);
      await request(server, '/reservations', 403, 'POST', input());
      if (settings.environment === 'production') {
        await request(server, '/reservations/client/' + demo.clientIds[0], 403);
        await request(server, '/reservations/' + original._id + '/cancel', 403, 'POST');
        assert.equal((await request(server, '/health', 200)).data.database.connected, true);
      }
      await stopServer(server);
    }
    assert.equal(await collection.countDocuments(), beforeBlocked);

    step = 'normal carrent database refuses creation even with the flag enabled';
    const normalUri = new ConnectionString(process.env.MONGO_URI);
    normalUri.searchParams.set('directConnection', 'true');
    assert.equal(normalUri.pathname, '/carrent');
    server = await startServer(normalUri.toString());
    await request(server, '/reservations', 403, 'POST', input());
    assert.equal((await request(server, '/health', 200)).data.database.connected, true);
    await stopServer(server);
    assert.deepEqual(await normalSnapshot(normalClient.db()), normalBefore);

    step = 'a non-direct connection refuses fixture creation';
    const nonDirect = new ConnectionString(uri.toString());
    nonDirect.searchParams.set('directConnection', 'false');
    server = await startServer(nonDirect.toString());
    await request(server, '/reservations', 403, 'POST', input());
    await stopServer(server);
    assert.equal(await collection.countDocuments(), beforeBlocked);

    step = 'disconnected MongoDB refuses creation';
    const disconnectedUri = new ConnectionString(uri.toString());
    disconnectedUri.hosts = ['127.0.0.1:' + await unusedPort()];
    server = await startServer(disconnectedUri.toString(), { disconnected: true });
    await request(server, '/reservations', 503, 'POST', input());
    await stopServer(server);
    console.log(httpChecks + ' HTTP checks and ' + localGuardChecks + ' remote-address guard checks passed.');
  } catch (error) {
    console.error('FAILED during ' + step + ': ' + error.name
      + (typeof error.code === 'number' ? ' (code ' + error.code + ')' : ''));
    throw error;
  } finally {
    try {
      await stopServer(server);
      if (connection) {
        try {
          if (createdByThisRun) {
            assertOwnedDatabase();
            await connection.dropDatabase();
            const left = await connection.db.admin().listDatabases({ nameOnly: true, filter: { name: databaseName } });
            assert.equal(left.databases.length, 0);
            console.log('This run\'s temporary database and all fixture reservations removed.');
          }
        } finally {
          await connection.close();
        }
      }
      if (normalClient && normalBefore) {
        assert.deepEqual(await normalSnapshot(normalClient.db()), normalBefore);
        console.log('Normal carrent collections, records and indexes remained unchanged.');
      }
    } finally {
      if (normalClient) await normalClient.close();
    }
  }
}

runTests().catch(function (error) {
  console.error('Creation tests or cleanup failed: ' + error.name
    + (typeof error.code === 'number' ? ' (code ' + error.code + ')' : ''));
  process.exitCode = 1;
});
