import 'dart:async';
import 'dart:convert';

import 'package:carrent/custom/reservations/reservation_api_card.dart';
import 'package:carrent/models/reservation.dart';
import 'package:carrent/screens/reservations/reservation_history_api_screen.dart';
import 'package:carrent/screens/reservations/reservation_history_screen.dart';
import 'package:carrent/utils/api_config.dart';
import 'package:carrent/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/reservation_json.dart';

Widget app(Future<List<Reservation>> future) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ReservationHistoryApiScreen(reservationsFuture: future),
  );
}

void mobileSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'iPhone 16 preview loads API cards with accurate millimes and labels',
    (tester) async {
      mobileSize(tester, const Size(393, 852));
      final pending = Completer<List<Reservation>>();
      await tester.pumpWidget(app(pending.future));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('DÉVELOPPEMENT UNIQUEMENT'), findsOneWidget);
      expect(
        find.text('Client de test : ${ApiConfig.developmentClientId}'),
        findsOneWidget,
      );
      pending.complete([
        Reservation.fromJson(
          reservationJson(changes: {'totalPriceMillimes': 150500}),
        ),
        Reservation.fromJson(
          reservationJson(
            changes: {'_id': '222222222222222222222222', 'status': 'cancelled'},
          ),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Véhicule (ID) : 000000000000000000000101'),
        findsWidgets,
      );
      expect(find.text('Prise en charge : 10/11/2026'), findsWidgets);
      expect(find.text('Retour : 13/11/2026'), findsWidgets);
      expect(find.text('Lieu de départ : Tunis - Aéroport'), findsWidgets);
      expect(find.text('Lieu de retour : Tunis - Centre'), findsWidgets);
      expect(find.text('Prix total : 150.500 DT'), findsOneWidget);
      expect(find.text('Statut : Confirmée'), findsOneWidget);
      expect(find.text('Toyota Corolla'), findsNothing);
      expect(find.text('Données de démonstration'), findsNothing);
      await tester.scrollUntilVisible(find.text('Statut : Annulée'), 180);
      expect(find.text('Statut : Annulée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty API array shows the exact empty-state message', (
    tester,
  ) async {
    await tester.pumpWidget(app(Future.value([])));
    await tester.pumpAndSettle();
    expect(find.text('Aucune réservation trouvée'), findsOneWidget);
    expect(find.byType(ReservationApiCard), findsNothing);
    expect(find.text('Toyota Corolla'), findsNothing);
  });

  testWidgets('API errors show an error instead of the empty-state message', (
    tester,
  ) async {
    final pending = Completer<List<Reservation>>();
    await tester.pumpWidget(app(pending.future));
    pending.completeError(Exception('HTTP 403 : développement local requis.'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Impossible de charger les réservations.'),
      findsOneWidget,
    );
    expect(find.textContaining('HTTP 403'), findsOneWidget);
    expect(find.text('Aucune réservation trouvée'), findsNothing);
    expect(find.byType(ReservationApiCard), findsNothing);
  });

  testWidgets('small phone layout scrolls without overflow', (tester) async {
    mobileSize(tester, const Size(320, 568));
    await tester.pumpWidget(
      app(Future.value([Reservation.fromJson(reservationJson())])),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Statut : Confirmée'), 160);
    expect(find.text('Statut : Confirmée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'development navigation opens a separate API preview and Back preserves demo data',
    (tester) async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: const ReservationHistoryScreen(),
            ),
          );
          await tester.tap(find.text('Aperçu API — développement uniquement'));
          await tester.pumpAndSettle();
          expect(find.byType(ReservationHistoryApiScreen), findsOneWidget);
          expect(find.text('Aucune réservation trouvée'), findsOneWidget);
          expect(find.text('Toyota Corolla'), findsNothing);
          expect(requests, 1);
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.text('Mes Réservations'), findsOneWidget);
          expect(find.text('Données de démonstration'), findsOneWidget);
          expect(find.text('Toyota Corolla'), findsOneWidget);
          expect(requests, 1);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.method, 'GET');
          return http.Response(jsonEncode([]), 200);
        }),
      );
    },
  );
}
