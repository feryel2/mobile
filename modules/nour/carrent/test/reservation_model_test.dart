import 'package:carrent/models/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/reservation_json.dart';

void main() {
  test('fromJson reads the actual backend field names and UTC dates', () {
    final reservation = Reservation.fromJson(reservationJson());
    expect(reservation.id, '111111111111111111111111');
    expect(reservation.vehicleId, '000000000000000000000101');
    expect(reservation.clientId, '000000000000000000000201');
    expect(reservation.pickupDate, DateTime.utc(2026, 11, 10));
    expect(reservation.returnDate, DateTime.utc(2026, 11, 13));
    expect(reservation.pickupDate.isUtc, isTrue);
    expect(reservation.pickupLocation, 'Tunis - Aéroport');
    expect(reservation.returnLocation, 'Tunis - Centre');
    expect(reservation.totalPriceMillimes, 150000);
    expect(reservation.status, 'confirmed');
  });

  test('cancelled status and zero millimes are valid history data', () {
    final reservation = Reservation.fromJson(
      reservationJson(
        changes: {'status': 'cancelled', 'totalPriceMillimes': 0},
      ),
    );
    expect(reservation.status, 'cancelled');
    expect(reservation.totalPriceMillimes, 0);
  });

  for (final field in [
    '_id',
    'vehicleId',
    'clientId',
    'pickupDate',
    'returnDate',
    'pickupLocation',
    'returnLocation',
    'totalPriceMillimes',
    'status',
  ]) {
    test('missing $field is rejected clearly', () {
      final json = reservationJson();
      json.remove(field);
      expect(() => Reservation.fromJson(json), throwsFormatException);
    });
  }

  final invalidValues = <Map<String, dynamic>>[
    {'_id': 'bad-id'},
    {'vehicleId': 101},
    {'clientId': null},
    {'pickupLocation': ''},
    {'returnLocation': 123},
    {'totalPriceMillimes': -1},
    {'totalPriceMillimes': 150000.5},
    {'totalPriceMillimes': '150000'},
    {'status': 'pending'},
    {'pickupDate': '2026-02-30T00:00:00.000Z'},
    {'pickupDate': '2026-11-10'},
    {'pickupDate': '2026-11-10T01:00:00.000Z'},
    {'returnDate': 'not-a-date'},
    {'returnDate': '2026-11-10T00:00:00.000Z'},
    {'returnDate': '2026-11-09T00:00:00.000Z'},
  ];
  for (var index = 0; index < invalidValues.length; index++) {
    test('invalid backend reservation ${index + 1} is rejected', () {
      expect(
        () => Reservation.fromJson(
          reservationJson(changes: invalidValues[index]),
        ),
        throwsFormatException,
      );
    });
  }
}
