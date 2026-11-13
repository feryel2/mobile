import 'package:carrent_client/models/reservation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/reservation_drafts.dart';

void main() {
  test('a draft snapshots the client, vehicle, dates and both locations', () {
    final draft = draftFor(clientA);
    final map = draft.toMap()..['id'] = 42;
    final saved = ReservationDraft.fromMap(map);

    expect(draft.id, isNull);
    expect(saved.id, 42);
    expect(saved.clientId, clientA.id);
    expect(saved.vehicleId, vehicle.id);
    expect(saved.vehicleName, 'Toyota Yaris');
    expect(saved.vehicleImage, 'toyota yaris.png');
    expect(saved.pickupLocation, 'Tunis - Aéroport');
    expect(saved.returnLocation, 'Tunis - Centre-ville');
    expect(map['pickupDate'], '2026-12-10T00:00:00.000Z');
    expect(map['returnDate'], '2026-12-13T00:00:00.000Z');
    expect(saved.toMap(), map);
  });

  test('millimes preserve fractional prices and estimates', () {
    final draft = draftFor(clientA);
    expect(draft.dailyPriceMillimes, 120500);
    expect(draft.rentalDays, 3);
    expect(draft.estimatedTotalMillimes, 361500);
    expect(ReservationDraft.formatMillimes(draft.dailyPriceMillimes),
        '120.500 DT');
    expect(ReservationDraft.formatMillimes(draft.estimatedTotalMillimes!),
        '361.500 DT');
    expect(ReservationDraft.formatMillimes(120001), '120.001 DT');
  });
}
