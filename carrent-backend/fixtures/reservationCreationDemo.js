// BACKEND TEST FIXTURE ONLY. These IDs are not real Vehicle or Client records.
// Replace these lookups with the group's shared models in a later task.
const vehicles = [
  { id: '000000000000000000000101', name: 'Toyota Corolla', dailyPriceMillimes: 50000 },
  { id: '000000000000000000000102', name: 'Hyundai Tucson', dailyPriceMillimes: 70000 },
  { id: '000000000000000000000103', name: 'Kia Picanto', dailyPriceMillimes: 40000 }
];

const clientIds = ['000000000000000000000201', '000000000000000000000202'];
const locations = ['Tunis - Aéroport', 'Tunis - Centre'];

module.exports = { vehicles, clientIds, locations };
