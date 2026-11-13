import 'dart:async';
import 'dart:convert';

import 'package:carrent_client/custom/reservations/available_vehicle_card.dart';
import 'package:carrent_client/models/vehicle.dart';
import 'package:carrent_client/screens/reservations/available_cars_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_search_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/reservation_drafts.dart' show clientA;

final _pickup = DateTime(2026, 11, 13);
final _return = DateTime(2026, 11, 21);
const _pickupLocation = 'Tunis - Aéroport';
const _returnLocation = 'Tunis - Centre-ville';
const _choose = 'Choisir cette voiture';

Vehicle _vehicle({
  required String id,
  required String brand,
  required String model,
  required String image,
  required double price,
  required String fuel,
  required int year,
}) {
  return Vehicle.fromJson({
    '_id': id,
    'marque': brand,
    'modele': model,
    'annee': year,
    'prix': price,
    'kilometrage': 25000,
    'carburant': fuel,
    'image': image,
    'disponible': true,
  });
}

AvailableCarsScreen _results(Future<List<Vehicle>> vehicles) {
  return AvailableCarsScreen(
    client: clientA,
    pickupDate: _pickup,
    returnDate: _return,
    pickupLocation: _pickupLocation,
    returnLocation: _returnLocation,
    vehiclesFuture: vehicles,
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(360, 640), const Size(393, 852)]) {
    testWidgets('API vehicle cards and booking handoff fit at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final first = _vehicle(
        id: '654000000000000000000001',
        brand: 'Renault',
        model: 'Mégane Estate',
        image: 'toyota yaris.png',
        price: 120.5,
        fuel: 'Hybride',
        year: 2024,
      );
      final second = _vehicle(
        id: '654000000000000000000002',
        brand: 'Škoda',
        model: 'Enyaq',
        image: 'missing-test-photo.png',
        price: 179.125,
        fuel: 'Electrique',
        year: 2025,
      );
      await tester.pumpWidget(
        MaterialApp(home: _results(Future.value([first, second]))),
      );
      await tester.pumpAndSettle();

      expect(find.text('13–21 nov. 2026'), findsOneWidget);
      expect(find.text('8 jours'), findsOneWidget);
      expect(find.text('Prise en charge : $_pickupLocation'), findsOneWidget);
      expect(find.text('Retour : $_returnLocation'), findsOneWidget);
      expect(find.text('Renault Mégane Estate'), findsOneWidget);
      expect(find.text('Hybride · 2024'), findsOneWidget);
      expect(find.text('Réf. véhicule : ${first.id}'), findsOneWidget);
      expect(
          find.text('120.500 DT / jour', findRichText: true), findsOneWidget);
      final firstCard =
          find.widgetWithText(AvailableVehicleCard, 'Renault Mégane Estate');
      final photo = tester.widget<Image>(
        find.descendant(of: firstCard, matching: find.byType(Image)),
      );
      expect((photo.image as AssetImage).assetName,
          'assets/images/toyota yaris.png');
      expect(photo.fit, BoxFit.contain);
      expect(tester.takeException(), isNull);

      final secondCard =
          find.widgetWithText(AvailableVehicleCard, 'Škoda Enyaq');
      await tester.scrollUntilVisible(secondCard, 180);
      final choose =
          find.descendant(of: secondCard, matching: find.text(_choose));
      await tester.ensureVisible(choose);
      await tester.pumpAndSettle();
      expect(find.text('Electrique · 2025'), findsOneWidget);
      expect(
          find.text('179.125 DT / jour', findRichText: true), findsOneWidget);
      expect(find.text('Réf. véhicule : ${second.id}'), findsOneWidget);
      final fallback = tester.widget<Image>(
        find.descendant(
          of: secondCard,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.semanticLabel == 'Photo générique de véhicule',
          ),
        ),
      );
      expect((fallback.image as AssetImage).assetName,
          'assets/images/default_car.png');
      expect(tester.takeException(), isNull);

      await _tapVisible(tester, choose);
      final summary = tester.widget<ReservationSummaryScreen>(
        find.byType(ReservationSummaryScreen),
      );
      expect(summary.vehicle, same(second));
      expect(summary.client, same(clientA));
      expect(summary.vehicle.id, second.id);
      expect(summary.vehicle.prix, 179.125);
      expect(summary.pickupDate, _pickup);
      expect(summary.returnDate, _return);
      expect(summary.pickupLocation, _pickupLocation);
      expect(summary.returnLocation, _returnLocation);
      expect(find.text('Vérifier ma réservation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Pending availability shows loading, then an empty response',
      (tester) async {
    final pending = Completer<List<Vehicle>>();
    await tester.pumpWidget(MaterialApp(home: _results(pending.future)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AvailableVehicleCard), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Aucun véhicule disponible sur cette période.'),
        findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
  });

  testWidgets('API failure preserves the error state and trip summary',
      (tester) async {
    final pending = Completer<List<Vehicle>>();
    await tester.pumpWidget(MaterialApp(home: _results(pending.future)));
    pending.completeError(StateError('Erreur de test'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Impossible de vérifier les disponibilités.'),
        findsOneWidget);
    expect(find.textContaining('Erreur de test'), findsOneWidget);
    expect(find.text('8 jours'), findsOneWidget);
    expect(find.byType(AvailableVehicleCard), findsNothing);
  });

  testWidgets('Modifier returns to the same team form with its fields intact',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReservationSearchScreen()));
    final search = find.byType(ReservationSearchScreen);
    final originalState = tester.state(search);
    await _tapVisible(tester, find.byKey(const Key('pickupDate')));
    final selected = tester
        .widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        )
        .initialDate!;
    await _tapVisible(tester, find.text('OK'));
    final date = '${selected.day.toString().padLeft(2, '0')}/'
        '${selected.month.toString().padLeft(2, '0')}/${selected.year}';
    expect(find.text(date), findsOneWidget);
    for (final key in ['pickupLocation', 'returnLocation']) {
      await _tapVisible(tester, find.byKey(Key(key)));
      await _tapVisible(tester, find.text(_pickupLocation).last);
    }
    Navigator.of(tester.element(search)).push(
      MaterialPageRoute<void>(builder: (context) => _results(Future.value([]))),
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Modifier'));
    expect(tester.state(search), same(originalState));
    expect(find.text(date), findsOneWidget);
    expect(find.text(_pickupLocation), findsNWidgets(2));
  });

  testWidgets('Search passes the client through live-results code to summary',
      (tester) async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home: ReservationSearchScreen(client: clientA),
      ));
      for (final key in ['pickupDate', 'returnDate']) {
        await _tapVisible(tester, find.byKey(Key(key)));
        await _tapVisible(tester, find.text('OK'));
      }
      for (final key in ['pickupLocation', 'returnLocation']) {
        await _tapVisible(tester, find.byKey(Key(key)));
        await _tapVisible(tester, find.text(_pickupLocation).last);
      }
      await _tapVisible(tester, find.text('Rechercher des voitures'));
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/vehicles/available');
      await _tapVisible(tester, find.text(_choose));
      final summary = tester.widget<ReservationSummaryScreen>(
        find.byType(ReservationSummaryScreen),
      );
      expect(summary.client, same(clientA));
      expect(summary.vehicle.id, '654000000000000000000003');
      expect(summary.pickupLocation, _pickupLocation);
      expect(summary.returnLocation, _pickupLocation);
      expect(requests, hasLength(1));
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response(
                  jsonEncode({
                    'data': [
                      {
                        '_id': '654000000000000000000003',
                        'marque': 'Renault',
                        'modele': 'Clio',
                        'prix': 120.5,
                        'annee': 2024,
                        'kilometrage': 1000,
                        'carburant': 'Essence',
                        'disponible': true,
                        'image': 'default_car.png',
                      },
                    ],
                  }),
                  200);
            }));
  });
}
