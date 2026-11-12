import 'package:carrent/custom/reservations/reservation_card.dart';
import 'package:carrent/screens/reservations/reservation_history_screen.dart';
import 'package:carrent/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('iPhone 16 history shows all fixed examples and statuses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ReservationHistoryScreen(),
      ),
    );

    expect(find.text('Mes Réservations'), findsOneWidget);
    expect(find.text('Données de démonstration'), findsOneWidget);
    expect(
      find.text(
        'Exemples fixes, sans lien avec votre confirmation. '
        'Aucune réservation n’a été enregistrée.',
      ),
      findsOneWidget,
    );

    const List<Map<String, dynamic>> expectedExamples = [
      {
        'name': 'Toyota Corolla',
        'pickup': '10/10/2026',
        'return': '13/10/2026',
        'price': 150,
        'status': 'Confirmée',
      },
      {
        'name': 'Hyundai Tucson',
        'pickup': '20/11/2026',
        'return': '23/11/2026',
        'price': 210,
        'status': 'En attente',
      },
      {
        'name': 'Kia Picanto',
        'pickup': '05/10/2026',
        'return': '07/10/2026',
        'price': 80,
        'status': 'Annulée',
      },
    ];

    for (final example in expectedExamples) {
      await tester.scrollUntilVisible(
        find.text(example['name']),
        180,
        scrollable: find.byType(Scrollable),
      );
      final card = find.widgetWithText(ReservationCard, example['name']);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();

      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text('Réservation de démonstration'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Prise en charge : ${example['pickup']}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Retour : ${example['return']}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Prix total : ${example['price']} DT'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Statut : ${example['status']}'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    // The demonstration notice remains visible above the scrolling cards.
    expect(find.text('Données de démonstration').hitTestable(), findsOneWidget);
  });
}
