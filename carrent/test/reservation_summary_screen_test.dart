import 'package:carrent/custom/reservations/demo_car_card.dart';
import 'package:carrent/screens/reservations/available_cars_screen.dart';
import 'package:carrent/screens/reservations/reservation_summary_screen.dart';
import 'package:carrent/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Independent expected values from the group's demonstration design.
  const List<Map<String, dynamic>> expectedVehicles = [
    {
      'name': 'Toyota Corolla',
      'category': 'Berline',
      'price': 50,
      'total': 150,
    },
    {'name': 'Hyundai Tucson', 'category': 'SUV', 'price': 70, 'total': 210},
    {'name': 'Kia Picanto', 'category': 'Citadine', 'price': 40, 'total': 120},
  ];

  for (final vehicle in expectedVehicles) {
    testWidgets('Select ${vehicle['name']}, check summary, and go back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pickupDate = DateTime(2026, 11, 10);
      final returnDate = DateTime(2026, 11, 13);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AvailableCarsScreen(
            pickupDate: pickupDate,
            returnDate: returnDate,
            pickupLocation: 'Tunis - Aéroport',
            returnLocation: 'Tunis - Aéroport',
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text(vehicle['name']),
        180,
        scrollable: find.byType(Scrollable),
      );
      final card = find.widgetWithText(DemoCarCard, vehicle['name']);
      final button = find.descendant(
        of: card,
        matching: find.text('Choisir cette voiture'),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      final summary = tester.widget<ReservationSummaryScreen>(
        find.byType(ReservationSummaryScreen),
      );
      expect(summary.vehicleName, vehicle['name']);
      expect(summary.vehicleCategory, vehicle['category']);
      expect(summary.dailyPrice, vehicle['price']);
      expect(summary.pickupDate, pickupDate);
      expect(summary.returnDate, returnDate);
      expect(summary.pickupLocation, 'Tunis - Aéroport');
      expect(summary.returnLocation, 'Tunis - Aéroport');

      expect(find.text('Résumé de la réservation'), findsOneWidget);
      expect(find.text(vehicle['name']), findsOneWidget);
      expect(find.text(vehicle['category']), findsOneWidget);
      expect(find.text('${vehicle['price']} DT / jour'), findsOneWidget);
      expect(find.text('Prise en charge : 10/11/2026'), findsOneWidget);
      expect(find.text('Retour : 13/11/2026'), findsOneWidget);
      expect(
        find.text('Lieu de prise en charge : Tunis - Aéroport'),
        findsOneWidget,
      );
      expect(find.text('Durée : 3 jours'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('estimatedTotal')));
      await tester.pumpAndSettle();
      expect(find.text('${vehicle['total']} DT'), findsOneWidget);
      expect(find.text('Prix total estimé (démonstration)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationSummaryScreen), findsNothing);
      expect(find.byType(AvailableCarsScreen), findsOneWidget);
      expect(find.text(vehicle['name']), findsOneWidget);
      expect(find.text('Prise en charge : 10/11/2026'), findsOneWidget);
      expect(find.text('Retour : 13/11/2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('One calendar day costs one daily price', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationSummaryScreen(
          vehicleName: 'Toyota Corolla',
          vehicleCategory: 'Berline',
          dailyPrice: 50,
          pickupDate: DateTime(2026, 11, 10),
          returnDate: DateTime(2026, 11, 11),
          pickupLocation: 'Tunis - Aéroport',
          returnLocation: 'Tunis - Aéroport',
        ),
      ),
    );

    expect(find.text('Durée : 1 jour'), findsOneWidget);
    expect(find.text('50 DT'), findsOneWidget);
  });

  testWidgets('Duration and total work across a month and year boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationSummaryScreen(
          vehicleName: 'Toyota Corolla',
          vehicleCategory: 'Berline',
          dailyPrice: 50,
          pickupDate: DateTime(2026, 12, 30),
          returnDate: DateTime(2027, 1, 2),
          pickupLocation: 'Tunis - Aéroport',
          returnLocation: 'Tunis - Aéroport',
        ),
      ),
    );

    expect(find.text('Durée : 3 jours'), findsOneWidget);
    expect(find.text('150 DT'), findsOneWidget);
  });

  for (final returnDate in [DateTime(2026, 11, 10), DateTime(2026, 11, 9)]) {
    testWidgets('Invalid return date $returnDate does not display a price', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReservationSummaryScreen(
            vehicleName: 'Toyota Corolla',
            vehicleCategory: 'Berline',
            dailyPrice: 50,
            pickupDate: DateTime(2026, 11, 10),
            returnDate: returnDate,
            pickupLocation: 'Tunis - Aéroport',
            returnLocation: 'Tunis - Aéroport',
          ),
        ),
      );

      expect(
        find.text(
          'La date de retour doit être après la date de prise en charge.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('estimatedTotal')), findsNothing);
      expect(find.byKey(const Key('confirmDemoReservation')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
