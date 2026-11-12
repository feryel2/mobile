// Provisional group rule: whole UTC calendar days, from 1 to 30 days.
const MAX_RENTAL_DAYS = 30;

function parseUtcDate(value) {
  // Leave missing values for Mongoose's required validators.
  if (value === undefined || value === null) return value;

  let date;
  if (value instanceof Date) {
    date = new Date(value);
  } else {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new Error('Use a UTC calendar date in YYYY-MM-DD format.');
    }
    date = new Date(value + 'T00:00:00.000Z');
    if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
      throw new Error('The calendar date is invalid.');
    }
  }

  if (Number.isNaN(date.getTime()) || date.getUTCHours() !== 0
    || date.getUTCMinutes() !== 0 || date.getUTCSeconds() !== 0
    || date.getUTCMilliseconds() !== 0) {
    throw new Error('Calendar dates must be valid UTC midnights.');
  }
  return date;
}

function generateReservedDays(pickupDate, returnDate) {
  const pickup = parseUtcDate(pickupDate);
  const end = parseUtcDate(returnDate);
  if (!pickup || !end) throw new Error('Both rental dates are required.');

  const numberOfDays = (end.getTime() - pickup.getTime()) / (24 * 60 * 60 * 1000);
  if (numberOfDays <= 0 || numberOfDays > MAX_RENTAL_DAYS) {
    throw new Error('A rental must last between 1 and 30 calendar days.');
  }

  const reservedDays = [];
  const current = new Date(pickup);
  while (current < end) {
    reservedDays.push(new Date(current));
    current.setUTCDate(current.getUTCDate() + 1);
  }
  return reservedDays;
}

module.exports = { parseUtcDate, generateReservedDays };
