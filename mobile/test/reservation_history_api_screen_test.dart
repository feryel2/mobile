import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carrent_client/custom/reservations/reservation_api_card.dart';
import 'package:carrent_client/models/user_model.dart';
import 'package:carrent_client/screens/profile_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_history_api_screen.dart';
import 'package:carrent_client/services/user_service.dart';
import 'package:carrent_client/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/reservation_drafts.dart';

const _cancel = 'Annuler la réservation';
const _confirm = 'Confirmer l’annulation';
const _activeId = '000000000000000000000010';
const _missingImage = 'missing-history-fixture.png';

DateTime _day(int offset) {
  final today = DateTime.now();
  return DateTime.utc(today.year, today.month, today.day + offset);
}

Map<String, Object?> _booking({
  String id = _activeId,
  User? owner,
  String name = 'Yaris',
  String image = 'toyota yaris.png',
  String status = 'confirmed',
  int start = -1,
  int end = 2,
  int millimes = 361501,
}) {
  return {
    '_id': id,
    'clientId': (owner ?? clientA).id,
    'vehicleId': {
      '_id': vehicle.id,
      'marque': 'Toyota',
      'modele': name,
      'immatriculation': 'TEST',
      'image': image,
      'prix': 999.99,
    },
    'pickupDate': _day(start).toIso8601String(),
    'returnDate': _day(end).toIso8601String(),
    'pickupLocation': 'Tunis - Aéroport',
    'returnLocation': 'Tunis - Centre-ville',
    'totalPriceMillimes': millimes,
    'status': status,
  };
}

http.Response _json(Object? body, [int status = 200]) {
  return http.Response.bytes(utf8.encode(jsonEncode(body)), status,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

http.Response _list(List<Map<String, Object?>> rows) =>
    _json({'success': true, 'data': rows});

class _ProfileService extends UserService {
  @override
  Future<Map<String, dynamic>> getProfile() async =>
      {'success': true, 'user': clientA};
}

Widget _app(Widget home, {GlobalKey? capture}) {
  return RepaintBoundary(
    key: capture,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: capture == null
          ? null
          : (context, child) => Column(
                children: [
                  const Material(
                    color: Color(0xFF102047),
                    child: SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: Center(
                        child: Text('TEST FIXTURE',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ),
                  Expanded(child: child!),
                ],
              ),
      home: home,
    ),
  );
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _expectAsset(String name, {Finder? within}) {
  final image = find.byWidgetPredicate((widget) =>
      widget is Image && widget.image == AssetImage('assets/images/$name'));
  expect(within == null ? image : find.descendant(of: within, matching: image),
      findsWidgets);
}

Future<void> _loadFixtureFonts() async {
  final fonts = Platform.environment['CARRENT_DRAFT_FIXTURE_FONTS'];
  if (fonts != null) {
    final loader = FontLoader('Roboto');
    for (final file in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
      loader.addFont(
          File('$fonts/$file').readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
  final icons = Platform.environment['CARRENT_DRAFT_FIXTURE_ICONS'];
  if (icons != null) {
    final loader = FontLoader('MaterialIcons');
    loader.addFont(File(icons).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey? key, String name) async {
  if (key == null) return;
  final dir = Platform.environment['CARRENT_HISTORY_FIXTURE_SCREENSHOTS'];
  await tester.runAsync(() async {
    final box =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await box.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File('$dir/history-test-fixture-$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_carrent_token': 'fixture-a'});
  });

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets(
        'History filters and cancellation dialog fit at ${width.toInt()}dp',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, width == 393 ? 852 : 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final capture = width == 393 &&
              Platform.environment['CARRENT_HISTORY_FIXTURE_SCREENSHOTS'] !=
                  null
          ? GlobalKey()
          : null;
      if (capture != null) await tester.runAsync(_loadFixtureFonts);
      final requests = <http.Request>[];
      final rows = [
        _booking(),
        _booking(
            id: '000000000000000000000011',
            name: 'Retour aujourd’hui',
            image: _missingImage,
            start: -3,
            end: 0,
            millimes: 180125),
        _booking(
            id: '000000000000000000000012',
            name: 'Annulée test',
            image: 'default_car.png',
            status: 'cancelled',
            start: 3,
            end: 5),
      ];
      await http.runWithClient(() async {
        await tester.pumpWidget(_app(
          ReservationHistoryApiScreen(client: clientA),
          capture: capture,
        ));
        await tester.runAsync(() async {
          final context =
              tester.element(find.byType(ReservationHistoryApiScreen));
          for (final name in [
            vehicle.image,
            'default_car.png',
            _missingImage
          ]) {
            await precacheImage(AssetImage('assets/images/$name'), context,
                onError: (_, __) {});
          }
        });
        await tester.pumpAndSettle();
        expect(requests.single.url.path, '/api/reservations/mine');
        expect(requests.single.headers['Authorization'], 'Bearer fixture-a');
        expect(requests.single.url.queryParameters, isEmpty);
        final active = find.byKey(const ValueKey(_activeId));
        final card = tester.widget<ReservationApiCard>(active);
        expect(card.reservation.id, _activeId);
        expect(card.reservation.vehicleId, vehicle.id);
        expect(card.reservation.pickupDate, _day(-1));
        expect(card.reservation.returnDate, _day(2));
        expect(find.text('Toyota Yaris'), findsOneWidget);
        expect(find.text('361.501 DT'), findsWidgets);
        expect(find.text('Confirmée'), findsWidgets);
        _expectAsset(vehicle.image, within: active);
        await _capture(tester, capture, 'all');

        await _tap(tester, 'À venir');
        expect(find.byType(ReservationApiCard), findsOneWidget);
        expect(find.text('Toyota Yaris'), findsOneWidget);
        await _tap(tester, _cancel);
        expect(find.text('Annuler cette réservation ?'), findsOneWidget);
        expect(find.text('Annulation en cours…'), findsNothing);
        await _capture(tester, capture, 'cancel-dialog');
        await _tap(tester, 'Retour');
        expect(requests, hasLength(1));

        await _tap(tester, 'Passées');
        expect(find.byType(ReservationApiCard), findsOneWidget);
        expect(find.text('Toyota Retour aujourd’hui'), findsOneWidget);
        expect(find.text('180.125 DT'), findsOneWidget);
        _expectAsset('default_car.png');

        await _tap(tester, 'Annulées');
        expect(find.byType(ReservationApiCard), findsOneWidget);
        expect(find.text('Toyota Annulée test'), findsOneWidget);
        expect(find.text('Annulée'), findsOneWidget);
        expect(find.text(_cancel), findsNothing);
        await _capture(tester, capture, 'cancelled');

        await _tap(tester, 'Tout afficher');
        await tester.scrollUntilVisible(
          find.text('Toyota Annulée test'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Toyota Annulée test'), findsOneWidget);
        expect(requests, hasLength(1));
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request);
                expect(request.method, 'GET');
                return _list(rows);
              }));
    });
  }

  testWidgets('Loading, expired session error, retry, and empty history',
      (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final capture =
        Platform.environment['CARRENT_HISTORY_FIXTURE_SCREENSHOTS'] != null
            ? GlobalKey()
            : null;
    if (capture != null) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.runAsync(_loadFixtureFonts);
    }
    await http.runWithClient(() async {
      await tester.pumpWidget(
          _app(ReservationHistoryApiScreen(client: clientA), capture: capture));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(_json({'message': 'Session expirée.'}, 401));
      await tester.pumpAndSettle();
      expect(
          find.text('Impossible de charger les réservations.'), findsOneWidget);
      expect(find.textContaining('Session expirée.'), findsOneWidget);
      await _tap(tester, 'Réessayer');
      expect(find.text('Aucune réservation trouvée'), findsOneWidget);
      expect(find.textContaining('l’onglet Réserver'), findsOneWidget);
      expect(requests, 2);
      await _capture(tester, capture, 'empty');
    },
        () => MockClient(
            (_) async => ++requests == 1 ? await pending.future : _list([])));
  });

  testWidgets('Confirmed cancellation sends one POST and reloads the list',
      (tester) async {
    final pending = Completer<http.Response>();
    final requests = <http.Request>[];
    final cancelled = _booking(status: 'cancelled');
    await http.runWithClient(() async {
      await tester
          .pumpWidget(_app(ReservationHistoryApiScreen(client: clientA)));
      await tester.pumpAndSettle();
      await _tap(tester, 'Annulées');
      expect(find.text('Aucune réservation ne correspond à ce filtre.'),
          findsOneWidget);
      await _tap(tester, 'Tout afficher');
      await _tap(tester, _cancel);
      final confirm = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, _confirm));
      confirm.onPressed!();
      confirm.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Annulation en cours…'), findsOneWidget);
      expect(find.text('Confirmée'), findsOneWidget);
      expect(find.text('Réservation annulée.'), findsNothing);
      expect(requests.map((request) => request.method), ['GET', 'POST']);
      expect(requests.last.url.path, '/api/reservations/$_activeId/cancel');
      expect(requests.last.headers['Authorization'], 'Bearer fixture-a');
      pending.complete(_json({'success': true, 'data': cancelled}));
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(find.text('Annulée'), findsOneWidget);
      expect(find.text('Réservation annulée.'), findsOneWidget);
      expect(find.text(_cancel), findsNothing);
    },
        () => MockClient((request) async {
              requests.add(request);
              if (request.method == 'POST') return pending.future;
              return _list(requests.length == 1 ? [_booking()] : [cancelled]);
            }));
  });

  for (final status in [409, 403, 401, null]) {
    testWidgets(
        'Cancellation error leaves confirmed status (${status ?? 'network'})',
        (tester) async {
      final error = status == null
          ? 'Connexion impossible à l’API CarRent.'
          : 'Annulation refusée ($status).';
      var gets = 0;
      var posts = 0;
      await http.runWithClient(() async {
        await tester
            .pumpWidget(_app(ReservationHistoryApiScreen(client: clientA)));
        await tester.pumpAndSettle();
        await _tap(tester, _cancel);
        await _tap(tester, _confirm);
        expect(find.textContaining(error), findsOneWidget);
        expect(find.text('Confirmée'), findsOneWidget);
        expect(find.text('Réservation annulée.'), findsNothing);
        expect(gets, 1);
        expect(posts, 1);
      },
          () => MockClient((request) async {
                if (request.method == 'GET') {
                  gets++;
                  return _list([_booking()]);
                }
                posts++;
                if (status == null) {
                  throw http.ClientException('fixture network error');
                }
                return _json({'message': error}, status);
              }));
    });
  }

  testWidgets('Account switch clears previous records while the new list loads',
      (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(_app(ReservationHistoryApiScreen(client: clientA)));
      await tester.pumpAndSettle();
      expect(find.text('Toyota Yaris'), findsOneWidget);
      await _tap(tester, 'À venir');
      await UserService.saveToken('fixture-b');
      await tester
          .pumpWidget(_app(ReservationHistoryApiScreen(client: clientB)));
      await tester.pump();
      expect(find.text('Toyota Yaris'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(
          _list([_booking(), _booking(owner: clientB, name: 'Autre')]));
      await tester.pumpAndSettle();
      expect(find.text('Toyota Yaris'), findsNothing);
      expect(find.text('Toyota Autre'), findsOneWidget);
      await tester
          .pumpWidget(_app(const ReservationHistoryApiScreen(client: null)));
      await tester.pumpAndSettle();
      expect(find.text('Toyota Autre'), findsNothing);
      expect(find.text('Connexion nécessaire'), findsOneWidget);
      expect(requests, 2);
    },
        () => MockClient((_) async =>
            ++requests == 1 ? _list([_booking()]) : await pending.future));
  });

  testWidgets('Changing session while the dialog is open blocks cancellation',
      (tester) async {
    var requests = 0;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(_app(ReservationHistoryApiScreen(client: clientA)));
      await tester.pumpAndSettle();
      await _tap(tester, _cancel);
      await UserService.clearSession();
      await _tap(tester, _confirm);
      expect(find.text('Toyota Yaris'), findsNothing);
      expect(find.text('Connexion nécessaire'), findsOneWidget);
      expect(requests, 1);
    },
        () => MockClient((request) async {
              requests++;
              expect(request.method, 'GET');
              return _list([_booking()]);
            }));
  });

  testWidgets('Historique tab uses the signed-in user and reloads on return',
      (tester) async {
    var historyRequests = 0;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(_app(ProfileScreen(userService: _ProfileService())));
      await tester.pumpAndSettle();
      await _tap(tester, 'Historique');
      expect(find.text('Toyota Yaris'), findsOneWidget);
      await _tap(tester, 'Réserver');
      expect(find.byType(ReservationHistoryApiScreen), findsNothing);
      await _tap(tester, 'Historique');
      expect(find.text('Toyota Nouveau'), findsOneWidget);
      expect(historyRequests, 2);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/api/reservations/mine');
              return _list([
                _booking(name: ++historyRequests == 1 ? 'Yaris' : 'Nouveau')
              ]);
            }));
  });
}
