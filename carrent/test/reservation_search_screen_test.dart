import 'package:carrent/main.dart';
import 'package:carrent/screens/reservations/available_cars_screen.dart';
import 'package:carrent/screens/reservations/reservation_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _airport = 'Tunis - Aéroport';
const _departureError = 'Choisissez un lieu de départ.';
const _returnLocationError = 'Choisissez un lieu de retour.';
const _returnWindowError =
    'Choisissez une date de retour entre 1 et 30 jours après le départ.';

DateTime _daysAfter(DateTime date, int days) {
  return DateTime(date.year, date.month, date.day + days);
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _typePickerDate(WidgetTester tester, DateTime date) async {
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final input = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byType(TextField),
  );
  final localizations = MaterialLocalizations.of(tester.element(input));
  await tester.enterText(input, localizations.formatCompactDate(date));
}

Future<DateTime> _chooseDate(
  WidgetTester tester,
  String field, {
  DateTime? date,
}) async {
  await _tapVisible(tester, find.byKey(Key(field)));
  final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
  if (date != null) {
    await _typePickerDate(tester, date);
  }
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  expect(find.byType(DatePickerDialog), findsNothing);
  return date ?? picker.initialDate!;
}

Future<void> _chooseLocation(WidgetTester tester, String field) async {
  await _tapVisible(tester, find.byKey(Key(field)));
  await tester.tap(find.text(_airport).last);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester) {
  return _tapVisible(tester, find.text('Rechercher des voitures'));
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Empty form shows errors for all four required fields', (
    tester,
  ) async {
    await tester.pumpWidget(const CarRentApp());
    await _search(tester);

    expect(
      find.text('Choisissez une date de prise en charge.'),
      findsOneWidget,
    );
    expect(find.text('Choisissez une date de retour.'), findsOneWidget);
    expect(find.text(_departureError), findsOneWidget);
    expect(find.text(_returnLocationError), findsOneWidget);
    expect(find.byType(AvailableCarsScreen), findsNothing);
    expect(find.byType(ReservationSearchScreen), findsOneWidget);
  });

  testWidgets('Return date requires a pickup date first', (tester) async {
    await tester.pumpWidget(const CarRentApp());
    await _tapVisible(tester, find.byKey(const Key('returnDate')));

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(
      find.text('Choisissez d’abord la date de prise en charge.'),
      findsOneWidget,
    );
  });

  for (final hasPickupLocation in [true, false]) {
    final missingField = hasPickupLocation ? 'return' : 'pickup';
    testWidgets('Search requires the $missingField location', (tester) async {
      await tester.pumpWidget(const CarRentApp());
      await _chooseDate(tester, 'pickupDate');
      await _chooseDate(tester, 'returnDate');
      await _chooseLocation(
        tester,
        hasPickupLocation ? 'pickupLocation' : 'returnLocation',
      );
      await _search(tester);

      expect(
        find.text(hasPickupLocation ? _returnLocationError : _departureError),
        findsOneWidget,
      );
      expect(
        find.text(hasPickupLocation ? _departureError : _returnLocationError),
        findsNothing,
      );
      expect(find.byType(AvailableCarsScreen), findsNothing);
    });
  }

  for (final invalidDay in [0, -1, 31]) {
    testWidgets('Return picker rejects a rental of $invalidDay days', (
      tester,
    ) async {
      await tester.pumpWidget(const CarRentApp());
      final pickup = await _chooseDate(tester, 'pickupDate');
      await _tapVisible(tester, find.byKey(const Key('returnDate')));
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, _daysAfter(pickup, 1));
      expect(picker.lastDate, _daysAfter(pickup, 30));

      await _typePickerDate(tester, _daysAfter(pickup, invalidDay));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text(_returnWindowError), findsOneWidget);
    });
  }

  testWidgets('Thirty days shows the correct duration and opens results', (
    tester,
  ) async {
    await tester.pumpWidget(const CarRentApp());
    final pickup = await _chooseDate(tester, 'pickupDate');
    final end = _daysAfter(pickup, 30);
    await _chooseDate(tester, 'returnDate', date: end);
    await _chooseLocation(tester, 'pickupLocation');
    await _chooseLocation(tester, 'returnLocation');

    expect(find.text('30 jours de location'), findsOneWidget);
    await _search(tester);
    final results = tester.widget<AvailableCarsScreen>(
      find.byType(AvailableCarsScreen),
    );
    expect(results.returnDate, end);
  });

  for (final pickupOffset in [0, 40]) {
    testWidgets('Changing pickup clears a return outside the allowed window '
        '(pickup offset $pickupOffset)', (tester) async {
      await tester.pumpWidget(const CarRentApp());
      final today = DateUtils.dateOnly(DateTime.now());
      final pickup = _daysAfter(today, 10);
      await _chooseDate(tester, 'pickupDate', date: pickup);
      await _chooseDate(tester, 'returnDate', date: _daysAfter(pickup, 30));
      expect(find.text('30 jours de location'), findsOneWidget);

      await _chooseDate(
        tester,
        'pickupDate',
        date: _daysAfter(today, pickupOffset),
      );
      expect(find.text('JJ/MM/AAAA'), findsOneWidget);
      expect(find.text('30 jours de location'), findsNothing);
    });
  }

  testWidgets(
    'One day and both locations pass to results and Back preserves the form',
    (tester) async {
      _setViewport(tester, const Size(393, 852));
      await tester.pumpWidget(const CarRentApp());
      final pickup = await _chooseDate(tester, 'pickupDate');
      final end = await _chooseDate(tester, 'returnDate');
      await _chooseLocation(tester, 'pickupLocation');
      await _chooseLocation(tester, 'returnLocation');
      expect(find.text('1 jour de location'), findsOneWidget);

      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(ReservationSearchScreen)),
      );
      final pickupText = localizations.formatCompactDate(pickup);
      final returnText = localizations.formatCompactDate(end);
      await _search(tester);

      final results = tester.widget<AvailableCarsScreen>(
        find.byType(AvailableCarsScreen),
      );
      expect(results.pickupDate, pickup);
      expect(results.returnDate, _daysAfter(pickup, 1));
      expect(results.pickupLocation, _airport);
      expect(results.returnLocation, _airport);
      expect(find.text('Voitures disponibles'), findsOneWidget);
      expect(find.text('Prise en charge : $pickupText'), findsOneWidget);
      expect(find.text('Retour : $returnText'), findsOneWidget);
      expect(find.text('Données de démonstration'), findsOneWidget);
      expect(find.text('Disponibilité non vérifiée.'), findsOneWidget);
      expect(find.text('Toyota Corolla'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AvailableCarsScreen), findsNothing);
      expect(find.text(pickupText), findsOneWidget);
      expect(find.text(returnText), findsOneWidget);
      expect(find.text('1 jour de location'), findsOneWidget);
      for (final field in ['pickupLocation', 'returnLocation']) {
        final dropdown = tester.state<FormFieldState<String>>(
          find.byKey(Key(field)),
        );
        expect(dropdown.value, _airport);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(360, 640),
    const Size(393, 852),
    const Size(430, 852),
  ]) {
    testWidgets('Filled search form fits or scrolls at $size', (tester) async {
      _setViewport(tester, size);
      await tester.pumpWidget(const CarRentApp());
      final pickup = await _chooseDate(tester, 'pickupDate');
      await _chooseDate(tester, 'returnDate', date: _daysAfter(pickup, 7));
      await _chooseLocation(tester, 'pickupLocation');
      await _chooseLocation(tester, 'returnLocation');
      await tester.ensureVisible(find.text('Rechercher des voitures'));
      await tester.pumpAndSettle();
      expect(find.text('7 jours de location'), findsOneWidget);
      expect(
        find.text('Rechercher des voitures').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Demo results scroll on a small mobile screen', (tester) async {
    _setViewport(tester, const Size(320, 568));
    await tester.pumpWidget(
      MaterialApp(
        home: AvailableCarsScreen(
          pickupDate: DateTime(2026, 11, 10),
          returnDate: DateTime(2026, 11, 12),
          pickupLocation: _airport,
          returnLocation: _airport,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Kia Picanto'),
      180,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('Données de démonstration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
