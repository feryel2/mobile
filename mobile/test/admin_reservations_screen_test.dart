import 'dart:async';
import 'dart:convert';

import 'package:carrent_client/custom/reservations/reservation_api_card.dart';
import 'package:carrent_client/screens/admin_hub_screen.dart';
import 'package:carrent_client/screens/auth_screen.dart';
import 'package:carrent_client/screens/reservations/admin_reservations_screen.dart';
import 'package:carrent_client/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clientId = '000000000000000000000001';
const _otherId = '000000000000000000000002';

http.Response _json(Object? data, [int status = 200]) {
  return http.Response.bytes(utf8.encode(jsonEncode(data)), status,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

Map<String, Object?> _reservation(String id, String status, Object? client,
    {bool hasVehicle = true}) {
  return {
    '_id': id,
    'clientId': client,
    'vehicleId': hasVehicle
        ? {
            '_id': '000000000000000000000003',
            'marque': 'Toyota',
            'modele': 'Yaris'
          }
        : null,
    'pickupDate': '2026-11-18T00:00:00.000Z',
    'returnDate': '2026-11-19T00:00:00.000Z',
    'pickupLocation': 'Tunis',
    'returnLocation': 'La Marsa',
    'totalPriceMillimes': 120500,
    'status': status,
  };
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'jwt_carrent_token': 'admin-token'});
  });

  testWidgets('admin loads all clients and filters the reservation list',
      (tester) async {
    var requests = 0;
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminReservationsScreen())));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.complete(_json({
        'data': [
          _reservation('000000000000000000000010', 'confirmed',
              {'_id': _clientId, 'fullname': 'Premier client'}),
          _reservation('000000000000000000000011', 'cancelled',
              {'_id': _otherId, 'fullname': 'Deuxième client'},
              hasVehicle: false),
        ],
      }));
      await tester.pumpAndSettle();
      expect(find.text('Client · Premier client'), findsOneWidget);
      expect(find.text('Client · Deuxième client'), findsOneWidget);
      expect(find.text('Réf. · 000000000000000000000010'), findsOneWidget);
      expect(find.text('Toyota Yaris'), findsOneWidget);
      expect(find.text('120.500 DT'), findsNWidgets(2));
      expect(find.text('Annuler la réservation'), findsOneWidget);

      await _tap(tester, 'Confirmées');
      expect(find.text('Client · Premier client'), findsOneWidget);
      expect(find.text('Client · Deuxième client'), findsNothing);
      await _tap(tester, 'Annulées');
      expect(find.text('Annuler la réservation'), findsNothing);
      expect(find.text('Client · Premier client'), findsNothing);
      expect(find.text('Client · Deuxième client'), findsOneWidget);
      await _tap(tester, 'Toutes');
      expect(find.byType(ReservationApiCard), findsNWidgets(2));
      expect(requests, 1);
    },
        () => MockClient((request) {
              requests++;
              expect(request.method, 'GET');
              expect(request.url.path, '/api/reservations/admin');
              expect(request.headers['authorization'], 'Bearer admin-token');
              return response.future;
            }));
  });

  for (final status in [200, 401, 403, 500]) {
    testWidgets('admin list handles HTTP $status', (tester) async {
      if (status == 403) await UserService.saveToken('client-token');
      var requests = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: AdminReservationsScreen())));
        await tester.pumpAndSettle();

        if (status == 200) {
          expect(find.text('Aucune réservation trouvée.'), findsOneWidget);
        } else if (status == 500) {
          expect(find.text('Impossible de charger les réservations.'),
              findsOneWidget);
          await _tap(tester, 'Réessayer');
          expect(find.text('Aucune réservation trouvée.'), findsOneWidget);
          expect(requests, 2);
        } else {
          expect(find.text('Accès administrateur requis.'), findsOneWidget);
        }
        expect(find.byType(ReservationApiCard), findsNothing);
      },
          () => MockClient((request) async {
                requests++;
                if (status == 403) {
                  expect(
                      request.headers['authorization'], 'Bearer client-token');
                }
                return _json({'data': []}, requests == 1 ? status : 200);
              }));
    });
  }

  testWidgets('admin login, tabs, system Back and explicit logout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final navigator = GlobalKey<NavigatorState>();
    var listRequests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          MaterialApp(navigatorKey: navigator, home: const AuthScreen()));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'admin@carrent.test');
      await tester.enterText(fields.at(1), 'fixture-password');
      final loginButton = find.widgetWithText(ElevatedButton, 'Se connecter');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.byType(AdminHubScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
      expect(navigator.currentState!.canPop(), isFalse);

      await _tap(tester, 'Réservations');
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Gestion des réservations'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AdminReservationsScreen), findsNothing);
      expect(find.byType(AdminHubScreen), findsOneWidget);
      expect(await UserService.getToken(), 'admin-token');

      await _tap(tester, 'Clients');
      expect(find.byType(BackButton), findsNothing);
      await _tap(tester, 'Parc');
      await _tap(tester, 'Réservations');
      expect(listRequests, 2);
      expect(await UserService.getToken(), 'admin-token');

      await _tap(tester, 'Déconnexion');
      await _tap(tester, 'Annuler');
      expect(await UserService.getToken(), 'admin-token');
      await _tap(tester, 'Déconnexion');
      await _tap(tester, 'Se déconnecter');
      expect(await UserService.getToken(), isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
    },
        () => MockClient((request) async {
              switch (request.url.path) {
                case '/api/users/login':
                  return _json({
                    'success': true,
                    'token': 'admin-token',
                    'user': {
                      '_id': _clientId,
                      'fullname': 'Admin fixture',
                      'email': 'admin@carrent.test',
                      'role': 'admin',
                      'status': 'active',
                    },
                  });
                case '/api/users/admin-login-tickets':
                  return _json(
                      {'success': true, 'ticket': 'fixture-ticket'}, 201);
                case '/api/reservations/admin':
                  listRequests++;
                  return _json({'data': []});
                default:
                  return _json({'success': true, 'data': [], 'users': []});
              }
            }));
  });

  testWidgets('Back from a pushed admin hub returns to its signed-in parent',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminHubScreen()),
              ),
              child: const Text('Profil administrateur'),
            ),
          ),
        ),
      ));
      await _tap(tester, 'Profil administrateur');
      await _tap(tester, 'Réservations');
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Profil administrateur'), findsOneWidget);
      expect(await UserService.getToken(), 'admin-token');
    },
        () => MockClient(
            (_) async => _json({'success': true, 'data': [], 'users': []})));
  });

  testWidgets('admin dialog validates and sends one trimmed cancellation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<http.Response>();
    var reads = 0;
    var posts = 0;
    const id = '000000000000000000000010';
    const reason = 'Problème technique.';
    final confirmed = _reservation(id, 'confirmed', _clientId);
    final cancelled = {
      ...confirmed,
      'status': 'cancelled',
      'cancellationReason': reason,
      'cancelledByRole': 'admin',
      'cancelledAt': '2026-11-13T12:00:00.000Z',
    };
    final field = find.byType(TextFormField);
    final confirm = find.text('Confirmer l’annulation');

    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminReservationsScreen())));
      await tester.pumpAndSettle();
      await _tap(tester, 'Confirmées');
      await _tap(tester, 'Annuler la réservation');
      expect(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.text('Réf. · $id')),
          findsOneWidget);

      for (final invalid in ['', '    ', 'x' * 501]) {
        await tester.enterText(field, invalid);
        await _tap(tester, 'Confirmer l’annulation');
        expect(posts, 0);
        expect(
            find.text(invalid.length > 500
                ? 'Le motif ne doit pas dépasser 500 caractères.'
                : 'Indiquez un motif d’annulation.'),
            findsOneWidget);
      }

      await tester.enterText(field, '  $reason  ');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 50));
      expect(posts, 1);
      expect(find.text('Annulation en cours…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Retour'))
              .onPressed,
          isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Réservation annulée avec succès.'), findsNothing);
      expect(reads, 1);

      pending.complete(_json({'success': true, 'data': cancelled}));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Réservation annulée avec succès.'), findsOneWidget);
      expect(reads, 2);
      expect(find.text('Aucune réservation ne correspond à ce filtre.'),
          findsOneWidget);
      await _tap(tester, 'Annulées');
      expect(find.text('Motif : $reason'), findsOneWidget);
      expect(find.text('Annuler la réservation'), findsNothing);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                expect(request.url.path, '/api/reservations/admin');
                reads++;
                return _json({
                  'data': [reads == 1 ? confirmed : cancelled]
                });
              }
              posts++;
              expect(request.method, 'POST');
              expect(request.url.path, '/api/reservations/$id/admin-cancel');
              expect(request.headers['authorization'], 'Bearer admin-token');
              expect(jsonDecode(request.body), {'reason': reason});
              return pending.future;
            }));
  });

  final failures = <int, String>{
    400: 'Le motif est invalide.',
    401: 'Reconnectez-vous avec un compte administrateur.',
    403: 'Reconnectez-vous avec un compte administrateur.',
    404: 'Réservation introuvable.',
    409: 'Cette réservation est déjà annulée ou ne peut plus être annulée.',
    500: 'Erreur de sauvegarde.',
    0: 'Connexion impossible à l’API CarRent.',
    -1: 'Le serveur CarRent ne répond pas.',
  };
  for (final entry in failures.entries) {
    testWidgets('admin cancellation handles failure ${entry.key}',
        (tester) async {
      var reads = 0;
      const id = '000000000000000000000010';
      await http.runWithClient(() async {
        await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: AdminReservationsScreen())));
        await tester.pumpAndSettle();
        await _tap(tester, 'Annuler la réservation');
        await tester.enterText(find.byType(TextFormField), 'Entretien');
        if (entry.key == -1) {
          await tester.tap(find.text('Confirmer l’annulation'));
          await tester.pump(const Duration(seconds: 11));
          await tester.pumpAndSettle();
        } else {
          await _tap(tester, 'Confirmer l’annulation');
        }
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Réservation annulée avec succès.'), findsNothing);
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirmer l’annulation'),
        );
        expect(button.onPressed != null, [400, 500, 0, -1].contains(entry.key));
        await _tap(tester, 'Retour');
        expect(reads, entry.key == 409 ? 2 : 1);
        expect(find.text('Annuler la réservation'),
            entry.key == 409 ? findsNothing : findsOneWidget);
        expect(find.text(entry.key == 409 ? 'Annulée' : 'Confirmée'),
            findsOneWidget);
      },
          () => MockClient((request) async {
                if (request.method == 'GET') {
                  reads++;
                  return _json({
                    'data': [
                      _reservation(id, reads == 1 ? 'confirmed' : 'cancelled',
                          _clientId),
                    ]
                  });
                }
                if (entry.key == 0) throw http.ClientException('offline');
                if (entry.key == -1) return Completer<http.Response>().future;
                return _json(
                    {'success': false, 'message': entry.value}, entry.key);
              }));
    });
  }
}
