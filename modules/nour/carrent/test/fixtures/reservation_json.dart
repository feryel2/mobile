// Backend-shaped JSON for automated tests only. Nothing is inserted in MongoDB.
Map<String, dynamic> reservationJson({
  Map<String, dynamic> changes = const {},
}) {
  return {
    '_id': '111111111111111111111111',
    'vehicleId': '000000000000000000000101',
    'clientId': '000000000000000000000201',
    'pickupDate': '2026-11-10T00:00:00.000Z',
    'returnDate': '2026-11-13T00:00:00.000Z',
    'pickupLocation': 'Tunis - Aéroport',
    'returnLocation': 'Tunis - Centre',
    'totalPriceMillimes': 150000,
    'status': 'confirmed',
    // Extra fields actually returned by Mongoose are ignored by the history model.
    'dailyPriceMillimes': 50000,
    'reservedDays': [
      '2026-11-10T00:00:00.000Z',
      '2026-11-11T00:00:00.000Z',
      '2026-11-12T00:00:00.000Z',
    ],
    'createdAt': '2026-11-02T12:00:00.000Z',
    'updatedAt': '2026-11-02T12:00:00.000Z',
    '__v': 0,
    ...changes,
  };
}
