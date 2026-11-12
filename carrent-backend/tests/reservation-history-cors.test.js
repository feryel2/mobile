// Read-only HTTP checks. No reservation or index is created, changed, or deleted.
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { spawn } = require('node:child_process');
const net = require('node:net');
const path = require('node:path');
const mongoose = require('mongoose');
const historyCors = require('../middlewares/reservationHistoryCors');
const controller = require('../controllers/reservationController');
const { checkConfiguration } = require('../scripts/setupReservationIndex');

require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });

const allowedOrigin = 'http://localhost:7357';
const clientId = '000000000000000000000201';
const historyPath = '/reservations/client/' + clientId;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let httpChecks = 0;
let addressChecks = 0;

async function checkSocketRestrictions() {
  const previous = process.env.NODE_ENV;
  process.env.NODE_ENV = 'development';
  try {
    for (const address of ['127.0.0.1', '::1', '::ffff:127.0.0.1',
      '203.0.113.10', '::ffff:203.0.113.10', undefined]) {
      const req = {
        method: 'GET', socket: { remoteAddress: address }, params: { clientId },
        headers: { origin: allowedOrigin, 'x-forwarded-for': '127.0.0.1' },
        get(name) { return this.headers[name.toLowerCase()]; }
      };
      const res = {
        headers: {},
        vary(field) { this.headers.vary = field; return this; },
        set(field, value) { this.headers[field.toLowerCase()] = value; return this; },
        status(code) { this.statusCode = code; return this; },
        json(body) { this.body = body; return this; }
      };
      let nextCalls = 0;
      historyCors(req, res, function () { nextCalls++; });
      assert.equal(nextCalls, 1);
      const local = ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(address);
      assert.equal(res.headers['access-control-allow-origin'], local ? allowedOrigin : undefined);
      assert.equal(res.headers['access-control-allow-credentials'], undefined);
      if (!local) {
        // The unchanged controller must still reject the real remote address,
        // even when forwarded headers claim localhost and the Origin is allowed.
        await controller.getClientReservations(req, res);
        assert.equal(res.statusCode, 403);
      }
      addressChecks++;
    }
  } finally {
    if (previous === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previous;
  }
}

async function startServer(environment) {
  const probe = net.createServer();
  await new Promise((resolve, reject) => {
    probe.once('error', reject);
    probe.listen(0, '127.0.0.1', resolve);
  });
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  const child = spawn(process.execPath, ['server.js'], {
    cwd: path.join(__dirname, '..'), windowsHide: true, stdio: 'ignore',
    env: { ...process.env, NODE_ENV: environment, PORT: String(port),
      ENABLE_RESERVATION_CREATION_TESTS: '' }
  });
  const server = { child, base: 'http://127.0.0.1:' + port };
  server.exited = new Promise(resolve => child.once('exit', resolve));
  let startupError;
  child.once('error', error => { startupError = error; });
  try {
    for (let attempt = 0; attempt < 60; attempt++) {
      if (startupError || child.exitCode !== null) throw new Error('Verification server exited.');
      try {
        const response = await fetch(server.base + '/health', { signal: AbortSignal.timeout(500) });
        if (response.status === 200 && (await response.json()).database.connected) return server;
      } catch (error) {}
      await delay(100);
    }
    throw new Error('Verification server did not connect.');
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

async function request(server, route, status, settings = {}) {
  const response = await fetch(server.base + route, {
    method: settings.method || 'GET',
    headers: settings.origin === null ? {} : { Origin: settings.origin || allowedOrigin },
    signal: AbortSignal.timeout(3000)
  });
  assert.equal(response.status, status, (settings.method || 'GET') + ' ' + route);
  assert.equal(response.headers.get('access-control-allow-origin'), settings.cors ? allowedOrigin : null);
  assert.equal(response.headers.get('access-control-allow-credentials'), null);
  assert.equal(response.headers.get('set-cookie'), null);
  if (settings.vary) {
    assert.ok(response.headers.get('vary').split(',').map(value => value.trim().toLowerCase()).includes('origin'));
  }
  const text = await response.text();
  httpChecks++;
  return text && response.headers.get('content-type')?.includes('application/json') ? JSON.parse(text) : text;
}

async function snapshot(db) {
  const result = [];
  const collections = await db.listCollections().toArray();
  for (const info of collections.sort((a, b) => a.name.localeCompare(b.name))) {
    assert.equal(info.type, 'collection');
    const records = await db.collection(info.name).find({}).sort({ _id: 1 }).toArray();
    const indexes = await db.collection(info.name).indexes();
    result.push({ name: info.name, options: info.options,
      recordsHash: createHash('sha256').update(JSON.stringify(records)).digest('hex'),
      indexesHash: createHash('sha256').update(JSON.stringify(indexes)).digest('hex') });
  }
  return result;
}

async function runTests() {
  await checkSocketRestrictions();
  checkConfiguration(process.env.MONGO_URI, 'development');
  const client = new mongoose.mongo.MongoClient(process.env.MONGO_URI, {
    directConnection: true, serverSelectionTimeoutMS: 5000
  });
  let server;
  let before;
  try {
    await client.connect();
    const db = client.db();
    assert.equal(db.databaseName, 'carrent');
    before = await snapshot(db);
    server = await startServer('development');
    assert.deepEqual(await request(server, historyPath, 200, { cors: true, vary: true }), []);
    for (const origin of ['http://localhost:7358', 'http://127.0.0.1:7357',
      'https://localhost:7357', 'http://localhost:7357/',
      'http://localhost:7357.evil.example', 'https://example.com', 'null']) {
      assert.deepEqual(await request(server, historyPath, 200, { origin, vary: true }), []);
    }
    assert.deepEqual(await request(server, historyPath, 200, { origin: null, vary: true }), []);
    await request(server, '/reservations/client/invalid', 400, { cors: true, vary: true });

    // Other paths and methods must not inherit the history permission.
    const health = await request(server, '/health', 200);
    assert.equal(health.server, 'running');
    assert.equal(health.database.connected, true);
    const query = '/reservations/check-conflict?' + new URLSearchParams({
      vehicleId: '000000000000000000000101', pickupDate: '2026-11-10', returnDate: '2026-11-13'
    });
    assert.equal((await request(server, query, 200)).hasConflict, false);
    await request(server, '/reservations/check-conflict', 400);
    await request(server, '/reservations', 403, { method: 'POST' });
    await request(server, '/reservations/invalid/cancel', 400, { method: 'POST' });
    await request(server, '/reservations/unknown', 404);
    await request(server, historyPath, 200, { method: 'HEAD' });
    await request(server, historyPath, 200, { method: 'OPTIONS' });
    await request(server, historyPath, 404, { method: 'POST' });
    await stopServer(server);

    for (const environment of ['production', 'test', '']) {
      server = await startServer(environment);
      await request(server, historyPath, 403);
      await request(server, '/reservations/invalid/cancel', 403, { method: 'POST' });
      await request(server, '/reservations', 403, { method: 'POST' });
      assert.equal((await request(server, '/health', 200)).database.connected, true);
      assert.equal((await request(server, query, 200)).hasConflict, false);
      await stopServer(server);
    }
    console.log(httpChecks + ' HTTP CORS/regression checks and ' + addressChecks + ' socket-address checks passed.');
  } finally {
    try {
      await stopServer(server);
    } finally {
      try {
        if (before) {
          assert.deepEqual(await snapshot(client.db()), before);
          console.log('Normal carrent collections, reservation records and indexes remained unchanged.');
        }
      } finally {
        await client.close();
      }
    }
  }
}

runTests().catch(function (error) {
  console.error('CORS tests failed: ' + error.name
    + (typeof error.code === 'number' ? ' (code ' + error.code + ')' : ''));
  process.exitCode = 1;
});
