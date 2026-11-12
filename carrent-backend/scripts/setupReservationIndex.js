// Default: inspect only. --apply must be explicitly requested after review.
const path = require('node:path');
const { isDeepStrictEqual } = require('node:util');
const mongoose = require('mongoose');
const Reservation = require('../models/Reservation');
const { parseUtcDate } = require('../utils/reservationDates');

const INDEX_NAME = 'unique_confirmed_vehicle_day';
const [indexKeys, indexOptions] = Reservation.schema.indexes().find(function (index) {
  return index[1].name === INDEX_NAME;
});

function checkConfiguration(uri, environment) {
  if (environment !== 'development') {
    throw new Error('Stopped: NODE_ENV must be explicitly set to development.');
  }
  let address;
  try {
    address = new URL(uri);
  } catch (error) {
    throw new Error('Stopped: configure a valid local MONGO_URI.');
  }
  if (address.protocol !== 'mongodb:'
    || !['localhost', '127.0.0.1', '[::1]'].includes(address.hostname.toLowerCase())) {
    throw new Error('Stopped: only a single localhost MongoDB address is allowed.');
  }
  if (address.pathname !== '/carrent' || address.hash) {
    throw new Error('Stopped: the selected database must be exactly carrent.');
  }
  for (const key of address.searchParams.keys()) {
    if (key.toLowerCase().startsWith('proxy')) {
      throw new Error('Stopped: MongoDB proxy options are not allowed.');
    }
  }
}

function isRequiredIndex(index) {
  const allowed = ['v', 'ns', 'name', 'key', 'unique', 'partialFilterExpression'];
  return index.name === INDEX_NAME
    && isDeepStrictEqual(Object.entries(index.key), Object.entries(indexKeys))
    && index.unique === true
    && isDeepStrictEqual(index.partialFilterExpression, { status: 'confirmed' })
    && Object.keys(index).every(function (key) { return allowed.includes(key); });
}

function isNormalIdIndex(index) {
  const allowed = ['v', 'ns', 'name', 'key', 'unique'];
  return index.name === '_id_'
    && isDeepStrictEqual(index.key, { _id: 1 })
    && (index.unique === undefined || index.unique === true)
    && Object.keys(index).every(function (key) { return allowed.includes(key); });
}

async function requiresMigration(record) {
  // Check stored BSON types first: Mongoose casts/defaults must not hide old data.
  if (!(record._id instanceof mongoose.Types.ObjectId)
    || !(record.vehicleId instanceof mongoose.Types.ObjectId)
    || !(record.clientId instanceof mongoose.Types.ObjectId)
    || !['confirmed', 'cancelled'].includes(record.status)) return true;
  for (const field of ['pickupLocation', 'returnLocation']) {
    if (typeof record[field] !== 'string' || record[field].length === 0) return true;
  }
  for (const field of ['dailyPriceMillimes', 'totalPriceMillimes']) {
    if (!Number.isInteger(record[field]) || record[field] < 0) return true;
  }
  for (const field of ['createdAt', 'updatedAt']) {
    if (!(record[field] instanceof Date) || Number.isNaN(record[field].getTime())) return true;
  }
  try {
    for (const field of ['pickupDate', 'returnDate']) {
      if (!(record[field] instanceof Date)) return true;
      parseUtcDate(record[field]);
    }
    if (record.reservedDays !== undefined && record.reservedDays !== null) {
      if (!Array.isArray(record.reservedDays)) return true;
      for (const day of record.reservedDays) {
        if (!(day instanceof Date)) return true;
        parseUtcDate(day);
      }
    }
    // Hydration and validation are in memory. No save() or update is performed.
    await Reservation.hydrate(record).validate();
    return false;
  } catch (error) {
    if (error instanceof mongoose.Error.ValidationError) return true;
    // parseUtcDate rejects invalid stored UTC calendar dates.
    if (error.message === 'Calendar dates must be valid UTC midnights.') return true;
    throw error;
  }
}

async function inspectReservations(db) {
  const collections = await db.listCollections({ name: 'reservations' }).toArray();
  const report = {
    collectionExists: collections.length === 1,
    collectionNeedsReview: false,
    documents: 0,
    documentsNeedingMigration: 0,
    overlappingVehicleDays: 0,
    correctIndexExists: false,
    unexpectedIndexes: 0,
    ready: false
  };
  if (report.collectionExists) {
    const info = collections[0];
    report.collectionNeedsReview = info.type !== 'collection'
      || Object.keys(info.options || {}).length !== 0;
    if (!report.collectionNeedsReview) {
      const collection = db.collection('reservations');
      const indexes = await collection.indexes();
      report.correctIndexExists = indexes.some(isRequiredIndex);
      report.unexpectedIndexes = indexes.filter(function (index) {
        return !isNormalIdIndex(index) && !isRequiredIndex(index);
      }).length;
      const occupiedDays = new Set();
      for await (const record of collection.find({})) {
        report.documents++;
        if (await requiresMigration(record)) {
          report.documentsNeedingMigration++;
          continue;
        }
        if (record.status === 'confirmed') {
          for (const day of record.reservedDays) {
            const key = record.vehicleId.toHexString() + ':' + day.getTime();
            if (occupiedDays.has(key)) report.overlappingVehicleDays++;
            occupiedDays.add(key);
          }
        }
      }
    }
  }
  report.ready = !report.collectionNeedsReview && report.documentsNeedingMigration === 0
    && report.overlappingVehicleDays === 0 && report.unexpectedIndexes === 0;
  return report;
}

// The CLI checks the target first. Tests call this same operation only with their
// own verified, uniquely named temporary database; there is no CLI test bypass.
async function setupIndex(db, apply = false) {
  const report = await inspectReservations(db);
  const result = { report, changed: false, verified: report.correctIndexExists };
  if (!apply || !report.ready || report.correctIndexExists) return result;

  if (!report.collectionExists) await db.createCollection('reservations');
  await db.collection('reservations').createIndex(indexKeys, indexOptions);
  const after = await inspectReservations(db);
  if (!after.ready || !after.correctIndexExists) {
    throw new Error('Installed index could not be verified. Manual review required.');
  }
  result.report = after;
  result.changed = true;
  result.verified = true;
  return result;
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== '--apply')) {
    console.error('Usage: node scripts/setupReservationIndex.js [--apply]');
    process.exitCode = 1;
    return;
  }
  require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });
  try {
    checkConfiguration(process.env.MONGO_URI, process.env.NODE_ENV);
  } catch (error) {
    // These messages are fixed safety messages, never the URI or driver errors.
    console.error(error.message);
    process.exitCode = 1;
    return;
  }

  let connection;
  try {
    connection = mongoose.createConnection(process.env.MONGO_URI, {
      autoCreate: false,
      autoIndex: false,
      // Stay on the checked local address instead of discovering other hosts.
      directConnection: true,
      serverSelectionTimeoutMS: 5000
    });
    await connection.asPromise();
    if (connection.name !== 'carrent' || connection.db.databaseName !== 'carrent'
      || !['localhost', '127.0.0.1', '::1', '[::1]'].includes(connection.host)) {
      console.error('Stopped: the connected target is not local carrent.');
      process.exitCode = 1;
      return;
    }
    const apply = args[0] === '--apply';
    console.log('Target verified: local MongoDB / carrent / development.');
    console.log(apply ? 'Mode: explicit index installation.' : 'Mode: read-only inspection.');
    const result = await setupIndex(connection.db, apply);
    console.log(JSON.stringify(result.report, null, 2));
    if (!result.report.ready) {
      console.error('Stopped: manual review required. No documents or indexes were changed.');
      process.exitCode = 1;
    } else if (result.verified) {
      console.log(result.changed ? 'Required index installed and verified.'
        : 'Required index already exists. No rebuild was needed.');
    } else {
      console.log('Ready for a separately approved --apply. Nothing was changed.');
    }
  } catch (error) {
    // Driver error messages can contain credentials. Print only safe identifiers.
    console.error('Maintenance stopped: ' + error.name
      + (typeof error.code === 'number' ? ' (code ' + error.code + ')' : '')
      + '. Check configuration/access or request manual review.');
    process.exitCode = 1;
  } finally {
    if (connection) await connection.close();
  }
}

module.exports = { checkConfiguration, inspectReservations, setupIndex };

if (require.main === module) {
  main().catch(function () {
    console.error('Maintenance or connection cleanup failed. No credentials are displayed.');
    process.exitCode = 1;
  });
}
