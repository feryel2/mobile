// Tests installation only in this run's new temporary database, never carrent.
const assert = require('node:assert/strict');
const { randomUUID, createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const mongoose = require('mongoose');
const { checkConfiguration, inspectReservations, setupIndex } = require('../scripts/setupReservationIndex');
const { generateReservedDays } = require('../utils/reservationDates');

require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });

let configurationCases = 0;
let databaseCases = 0;

function checkGuards() {
  for (const host of ['127.0.0.1:27017', 'localhost:27017', '[::1]:27017']) {
    checkConfiguration('mongodb://' + host + '/carrent', 'development');
    configurationCases++;
  }
  const rejected = [
    ['mongodb://127.0.0.1/carrent', 'production'],
    ['mongodb://127.0.0.1/carrent', 'test'],
    ['mongodb://127.0.0.1/carrent', undefined],
    ['mongodb://127.0.0.1/carrent', ''],
    ['mongodb://example.com/carrent', 'development'],
    ['mongodb+srv://localhost/carrent', 'development'],
    ['mongodb://127.0.0.1/another_database', 'development'],
    ['mongodb://127.0.0.1/CarRent', 'development'],
    ['mongodb://127.0.0.1/', 'development'],
    ['mongodb://127.0.0.1/carrent#unexpected', 'development'],
    ['mongodb://127.0.0.1/carrent?proxyHost=example.com', 'development'],
    ['mongodb://127.0.0.1,example.com/carrent', 'development'],
    ['not-a-uri', 'development']
  ];
  for (const [uri, environment] of rejected) {
    assert.throws(function () { checkConfiguration(uri, environment); });
    configurationCases++;
  }

  // No CLI bypass allows --apply to target a temporary or non-local database.
  // Even these rejected --apply commands never use the normal carrent URI.
  const secret = 'DO_NOT_PRINT_THIS_PASSWORD';
  const uri = 'mongodb://tester:' + secret + '@127.0.0.1/not_carrent';
  const commands = [
    { args: ['--apply'], uri, environment: 'development' },
    { args: ['--apply'], uri, environment: 'production' },
    { args: ['--apply'], uri: 'mongodb://example.com/not_carrent', environment: 'development' },
    { args: ['--force'], uri, environment: 'development' }
  ];
  for (const command of commands) {
    const child = spawnSync(process.execPath, ['scripts/setupReservationIndex.js', ...command.args], {
      cwd: path.join(__dirname, '..'),
      env: { ...process.env, MONGO_URI: command.uri, NODE_ENV: command.environment },
      encoding: 'utf8', windowsHide: true, timeout: 10000
    });
    assert.ifError(child.error);
    assert.equal(child.status, 1);
    assert.ok(!(child.stdout + child.stderr).includes(secret));
    assert.ok(!(child.stdout + child.stderr).includes(command.uri));
    configurationCases++;
  }
  console.log(configurationCases + ' configuration/CLI safety cases passed.');
}

async function snapshot(db) {
  const exists = (await db.listCollections({ name: 'reservations' }).toArray()).length === 1;
  if (!exists) return { exists: false };
  const collection = db.collection('reservations');
  const records = await collection.find({}).sort({ _id: 1 }).toArray();
  const indexes = await collection.indexes();
  return {
    exists: true,
    recordsHash: createHash('sha256').update(JSON.stringify(records)).digest('hex'),
    indexesHash: createHash('sha256').update(JSON.stringify(indexes)).digest('hex')
  };
}

function record(changes = {}) {
  return {
    _id: new mongoose.Types.ObjectId(),
    vehicleId: new mongoose.Types.ObjectId(),
    clientId: new mongoose.Types.ObjectId(),
    pickupDate: new Date('2026-11-10T00:00:00Z'),
    returnDate: new Date('2026-11-13T00:00:00Z'),
    reservedDays: generateReservedDays('2026-11-10', '2026-11-13'),
    pickupLocation: 'Isolated test only', returnLocation: 'Isolated test only',
    dailyPriceMillimes: 50000, totalPriceMillimes: 150000, status: 'confirmed',
    createdAt: new Date(), updatedAt: new Date(), ...changes
  };
}

async function runTests() {
  checkGuards();
  const databaseName = 'carrent_index_setup_test_' + randomUUID().replaceAll('-', '');
  let connection;
  let normalClient;
  let beforeNormal;
  let createdByThisRun = false;
  let step = 'connection safety';

  function assertOwnedDatabase() {
    assert.match(databaseName, /^carrent_index_setup_test_[a-f0-9]{32}$/);
    assert.equal(connection.name, databaseName);
    assert.equal(connection.db.databaseName, databaseName);
    assert.equal(createdByThisRun, true);
  }

  try {
    // The normal database is used only for before/after read-only snapshots.
    checkConfiguration(process.env.MONGO_URI, 'development');
    normalClient = new mongoose.mongo.MongoClient(process.env.MONGO_URI, {
      directConnection: true, serverSelectionTimeoutMS: 5000
    });
    await normalClient.connect();
    assert.equal(normalClient.db().databaseName, 'carrent');
    beforeNormal = await snapshot(normalClient.db());

    connection = mongoose.createConnection(process.env.MONGO_URI, {
      dbName: databaseName, autoCreate: false, autoIndex: false,
      directConnection: true, serverSelectionTimeoutMS: 5000
    });
    await connection.asPromise();
    assert.equal(connection.name, databaseName);
    const db = connection.db;
    const existing = await db.admin().listDatabases({ nameOnly: true, filter: { name: databaseName } });
    assert.equal(existing.databases.length, 0, 'Refusing to use any existing test database.');
    await db.createCollection('test_ownership');
    createdByThisRun = true;
    assertOwnedDatabase();

    // Reset only this run's reservations collection between independent scenarios.
    async function reset(options = {}) {
      assertOwnedDatabase();
      if ((await db.listCollections({ name: 'reservations' }).toArray()).length) {
        await db.collection('reservations').drop();
      }
      return await db.createCollection('reservations', options);
    }

    step = 'inspection cannot create a missing collection';
    assert.deepEqual(await snapshot(db), { exists: false });
    const inspection = await setupIndex(db);
    assert.equal(inspection.report.ready, true);
    assert.equal(inspection.report.collectionExists, false);
    assert.equal(inspection.verified, false);
    assert.equal(inspection.changed, false);
    assert.deepEqual(await snapshot(db), { exists: false });
    databaseCases++;

    step = 'explicit install creates and verifies the missing collection/index';
    const installed = await setupIndex(db, true);
    assert.equal(installed.changed, true);
    assert.equal(installed.verified, true);
    assert.equal((await inspectReservations(db)).correctIndexExists, true);
    assert.equal(await db.collection('reservations').countDocuments(), 0);
    databaseCases++;

    step = 'already installed is idempotent';
    const installedSnapshot = await snapshot(db);
    const repeated = await setupIndex(db, true);
    assert.equal(repeated.changed, false);
    assert.equal(repeated.verified, true);
    assert.deepEqual(await snapshot(db), installedSnapshot);
    databaseCases++;

    step = 'valid existing records and cancellation do not need migration';
    let collection = await reset();
    const confirmed = record();
    const cancelled = record({ vehicleId: confirmed.vehicleId, status: 'cancelled' });
    delete cancelled.reservedDays;
    await collection.insertMany([confirmed, cancelled]);
    const beforeValid = await snapshot(db);
    const validInspection = await setupIndex(db);
    assert.equal(validInspection.report.documents, 2);
    assert.equal(validInspection.report.ready, true);
    assert.deepEqual(await snapshot(db), beforeValid);
    assert.equal((await setupIndex(db, true)).verified, true);
    assert.equal((await snapshot(db)).recordsHash, beforeValid.recordsHash);
    await assert.rejects(collection.insertOne(record({ vehicleId: confirmed.vehicleId })), { code: 11000 });
    assert.equal(await collection.countDocuments(), 2);
    databaseCases++;

    step = 'migration problems block installation without touching documents';
    const invalidRecords = [
      function (value) { delete value.reservedDays; },
      function (value) { value.reservedDays = value.reservedDays.slice(0, 2); },
      function (value) { value.reservedDays[1] = value.reservedDays[0]; },
      function (value) { value.reservedDays.push(new Date('2026-11-13T00:00:00Z')); },
      function (value) { value.reservedDays[0] = new Date('2026-11-10T01:00:00Z'); },
      function (value) { value.vehicleId = value.vehicleId.toString(); },
      function (value) { value.pickupDate = '2026-11-10'; },
      function (value) { value.dailyPriceMillimes = '50000'; },
      function (value) { delete value.status; },
      function (value) { delete value.createdAt; }
    ];
    for (const makeInvalid of invalidRecords) {
      collection = await reset();
      const value = record();
      makeInvalid(value);
      await collection.insertOne(value);
      const before = await snapshot(db);
      const result = await setupIndex(db, true);
      assert.equal(result.report.ready, false);
      assert.equal(result.report.documentsNeedingMigration, 1);
      assert.equal(result.changed, false);
      assert.deepEqual(await snapshot(db), before);
      databaseCases++;
    }

    step = 'valid but overlapping records block installation';
    collection = await reset();
    const first = record();
    await collection.insertMany([first, record({ vehicleId: first.vehicleId })]);
    const beforeOverlap = await snapshot(db);
    const overlap = await setupIndex(db, true);
    assert.equal(overlap.report.documentsNeedingMigration, 0);
    assert.equal(overlap.report.overlappingVehicleDays, 3);
    assert.equal(overlap.report.ready, false);
    assert.deepEqual(await snapshot(db), beforeOverlap);
    databaseCases++;

    step = 'conflicting and unexpected indexes require manual review';
    const wrongIndexes = [
      [{ vehicleId: 1, reservedDays: 1 }, { name: 'unique_confirmed_vehicle_day' }],
      [{ vehicleId: 1, reservedDays: 1 }, { name: 'unique_confirmed_vehicle_day', unique: true }],
      [{ vehicleId: 1, reservedDays: 1 }, { name: 'different_name', unique: true, partialFilterExpression: { status: 'confirmed' } }],
      [{ clientId: 1 }, { name: 'unexpected_client_index' }],
      [{ reservedDays: 1, vehicleId: 1 }, { name: 'unique_confirmed_vehicle_day', unique: true, partialFilterExpression: { status: 'confirmed' } }]
    ];
    for (const [keys, options] of wrongIndexes) {
      collection = await reset();
      await collection.createIndex(keys, options);
      const before = await snapshot(db);
      const result = await setupIndex(db, true);
      assert.equal(result.report.ready, false);
      assert.equal(result.report.unexpectedIndexes, 1);
      assert.deepEqual(await snapshot(db), before);
      databaseCases++;
    }

    step = 'unexpected collection options require review';
    await reset({ collation: { locale: 'en' } });
    const beforeOptions = await snapshot(db);
    const optionsResult = await setupIndex(db, true);
    assert.equal(optionsResult.report.collectionNeedsReview, true);
    assert.equal(optionsResult.report.ready, false);
    assert.deepEqual(await snapshot(db), beforeOptions);
    databaseCases++;
    console.log(databaseCases + ' isolated inspection/installation cases passed.');
  } catch (error) {
    console.error('Failed during: ' + step + ' (' + error.name + ')');
    throw error;
  } finally {
    try {
      if (connection) {
        try {
          if (createdByThisRun) {
            assertOwnedDatabase();
            await connection.dropDatabase();
            const left = await connection.db.admin().listDatabases({ nameOnly: true, filter: { name: databaseName } });
            assert.equal(left.databases.length, 0);
            console.log('This run\'s temporary database and all test records removed.');
          }
        } finally {
          await connection.close();
        }
      }
      if (normalClient && beforeNormal) {
        assert.deepEqual(await snapshot(normalClient.db()), beforeNormal);
        console.log('Normal carrent reservation data and indexes remained unchanged.');
      }
    } finally {
      if (normalClient) await normalClient.close();
    }
  }
}

runTests().catch(function (error) {
  console.error('Maintenance tests or cleanup failed: ' + error.name
    + (typeof error.code === 'number' ? ' (code ' + error.code + ')' : ''));
  process.exitCode = 1;
});
