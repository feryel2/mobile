import 'package:carrent/screens/reservations/reservation_confirmation_demo_screen.dart';
import 'package:carrent/screens/reservations/reservation_history_screen.dart';
import 'package:carrent/screens/reservations/reservation_summary_screen.dart';
import 'package:carrent/custom/reservations/reservation_card.dart';
import 'package:carrent/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openConfirmationDialog(WidgetTester tester) async {
  // iPhone 16 logical screen size, matching the student's manual preview.
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ReservationSummaryScreen(
        vehicleName: 'Toyota Corolla',
        vehicleCategory: 'Berline',
        dailyPrice: 50,
        pickupDate: DateTime(2026, 11, 10),
        returnDate: DateTime(2026, 11, 18),
        pickupLocation: 'Tunis - Aéroport',
        returnLocation: 'Tunis - Aéroport',
      ),
    ),
  );
  expect(find.text('Durée : 8 jours'), findsOneWidget);
  expect(find.text('400 DT'), findsOneWidget);
  await tester.ensureVisible(find.byKey(const Key('confirmDemoReservation')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirmDemoReservation')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Dialog shows the selected details and Cancel keeps the summary',
    (tester) async {
      await openConfirmationDialog(tester);
      final dialog = find.byType(AlertDialog);

      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text('Toyota Corolla')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Prise en charge : 10/11/2026'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Retour : 18/11/2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Total estimé (démo) : 400 DT'),
        ),
        findsOneWidget,
      );
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.byType(ReservationConfirmationDemoScreen), findsNothing);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ReservationSummaryScreen), findsOneWidget);
      expect(find.byType(ReservationConfirmationDemoScreen), findsNothing);
      expect(find.text('400 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Continue opens demo, history remains static, and Back returns normally',
    (tester) async {
      await openConfirmationDialog(tester);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.byType(ReservationConfirmationDemoScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Confirmation (démo)'), findsOneWidget);
      expect(
        find.text(
          'Ceci est une démonstration. '
          'Aucune réservation n’a été enregistrée.',
        ),
        findsOneWidget,
      );
      expect(find.text('Votre voiture n’est pas réservée.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Voir les réservations (démo)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir les réservations (démo)'));
      await tester.pumpAndSettle();

      expect(find.byType(ReservationHistoryScreen), findsOneWidget);
      expect(find.text('Mes Réservations'), findsOneWidget);
      expect(find.text('Données de démonstration'), findsOneWidget);
      expect(
        find.text(
          'Exemples fixes, sans lien avec votre confirmation. '
          'Aucune réservation n’a été enregistrée.',
        ),
        findsOneWidget,
      );
      // The earlier 400 DT demo was not saved: this is a separate fixed example.
      final exampleCard = tester.widget<ReservationCard>(
        find.widgetWithText(ReservationCard, 'Toyota Corolla'),
      );
      expect(exampleCard.totalPrice, 150);
      expect(exampleCard.pickupDate, DateTime(2026, 10, 10));
      expect(exampleCard.returnDate, DateTime(2026, 10, 13));
      expect(find.text('400 DT'), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationHistoryScreen), findsNothing);
      expect(find.byType(ReservationConfirmationDemoScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ReservationSummaryScreen), findsOneWidget);
      expect(find.byType(ReservationConfirmationDemoScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('400 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
