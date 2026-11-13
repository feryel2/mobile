import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carrent_client/custom/reservations/reservation_weather_card.dart';
import 'package:carrent_client/models/reservation_draft.dart';
import 'package:carrent_client/models/user_model.dart';
import 'package:carrent_client/models/vehicle.dart';
import 'package:carrent_client/screens/reservations/reservation_drafts_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_summary_screen.dart';
import 'package:carrent_client/services/weather_service.dart';
import 'package:carrent_client/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/reservation_drafts.dart';

const _save = 'Enregistrer comme brouillon';
const _review = 'Vérifier ma réservation';
const _book = 'Confirmer la réservation';
const _pickupLocation = 'Tunis - La Marsa';
const _returnLocation = 'Tunis - Centre-ville';

const _weatherUnavailable = 'Prévisions météo non disponibles pour ce départ.';

class _TestWeatherService extends WeatherService {
  final Future<PickupForecast?> Function(DateTime, String)? forecast;

  const _TestWeatherService([this.forecast]);

  @override
  Future<PickupForecast?> getPickupForecast({
    required DateTime pickupDate,
    required String pickupLocation,
  }) async {
    return forecast?.call(pickupDate, pickupLocation);
  }
}

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

Widget _summary({
  User? client,
  Vehicle selectedVehicle = vehicle,
  DateTime? pickup,
  DateTime? end,
  String pickupLocation = _pickupLocation,
  String returnLocation = _returnLocation,
  required Future<int> Function(User, ReservationDraft) insert,
  GlobalKey? capture,
  WeatherService weatherService = const _TestWeatherService(),
}) {
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
      home: ReservationSummaryScreen(
        client: client,
        vehicle: selectedVehicle,
        pickupDate: pickup ?? _day(2),
        returnDate: end ?? _day(5),
        pickupLocation: pickupLocation,
        returnLocation: returnLocation,
        insertDraft: insert,
        weatherService: weatherService,
      ),
    ),
  );
}

Future<void> _tapReview(WidgetTester tester) async {
  final review = find.text(_review);
  await tester.ensureVisible(review);
  await tester.tap(review);
  await tester.pumpAndSettle();
}

Future<void> _loadFixtureFonts() async {
  final fonts = Platform.environment['CARRENT_DRAFT_FIXTURE_FONTS'];
  if (fonts != null) {
    final loader = FontLoader('Roboto');
    for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
      loader.addFont(
          File('$fonts/$name').readAsBytes().then(ByteData.sublistView));
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
  final directory = Platform.environment['CARRENT_SUMMARY_FIXTURE_SCREENSHOTS'];
  await tester.runAsync(() async {
    final box =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await box.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File('$directory/$name.png').writeAsBytes(png!.buffer.asUint8List());
  });
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = find.text(_save);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
}

void main() {
  setUp(() {
    // Test-only preference storage and transport. No real session is created.
    SharedPreferences.setMockInitialValues(
        {'jwt_carrent_token': 'fixture-token'});
  });

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets('Premium summary and review fit at ${width.toInt()}dp',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, width == 393 ? 852 : 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final capture = width == 393 &&
              Platform.environment['CARRENT_SUMMARY_FIXTURE_SCREENSHOTS'] !=
                  null
          ? GlobalKey()
          : null;
      if (capture != null) {
        await tester.runAsync(_loadFixtureFonts);
      }
      final year = DateTime.now().year + 1;
      final selected = width == 320
          ? Vehicle.fromJson(vehicle.toJson()
            ..['_id'] = vehicle.id
            ..['image'] = 'missing-fixture-photo.png')
          : vehicle;
      await http.runWithClient(() async {
        await tester.pumpWidget(_summary(
          client: clientA,
          selectedVehicle: selected,
          pickup: DateTime(year, 6, 10),
          end: DateTime(year, 6, 14),
          capture: capture,
          insert: (_, __) async => fail('Review should not save a draft'),
        ));
        final summary = find.byType(ReservationSummaryScreen);
        if (capture != null || width == 320) {
          await tester.runAsync(() async {
            final context = tester.element(summary);
            for (final asset in [
              'toyota yaris.png',
              'default_car.png',
              selected.image
            ]) {
              await precacheImage(AssetImage('assets/images/$asset'), context,
                  onError: (_, __) {});
            }
          });
        }
        await tester.pumpAndSettle();
        expect(find.text('Votre réservation'), findsOneWidget);
        expect(find.text('Vérifiez votre réservation'), findsOneWidget);
        expect(find.text('Toyota Yaris'), findsOneWidget);
        expect(find.text('Essence · 2024'), findsOneWidget);
        expect(find.text('10 juin $year'), findsOneWidget);
        expect(find.text('14 juin $year'), findsOneWidget);
        expect(find.text(_pickupLocation), findsOneWidget);
        expect(find.text(_returnLocation), findsOneWidget);
        expect(find.text('120.500 DT / jour'), findsOneWidget);
        expect(find.text('4 × 120.500 DT'), findsOneWidget);
        expect(find.text('482.000 DT'), findsOneWidget);
        final asset = width == 320 ? 'default_car.png' : vehicle.image;
        expect(
          find.byWidgetPredicate((widget) =>
              widget is Image &&
              widget.image == AssetImage('assets/images/$asset')),
          findsOneWidget,
        );
        expect(find.text(_book), findsNothing);
        expect(tester.takeException(), isNull);
        await _capture(tester, capture, 'summary-test-fixture');

        await _tapReview(tester);
        final dialog = find.byType(AlertDialog);
        Finder inDialog(String text) =>
            find.descendant(of: dialog, matching: find.text(text));
        expect(inDialog('Vérifier votre réservation'), findsOneWidget);
        expect(inDialog('Toyota Yaris'), findsOneWidget);
        expect(inDialog('10–14 juin $year'), findsOneWidget);
        expect(inDialog(_pickupLocation), findsOneWidget);
        expect(inDialog(_returnLocation), findsOneWidget);
        expect(inDialog('4 jours'), findsOneWidget);
        expect(inDialog('482.000 DT'), findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.byWidgetPredicate((widget) =>
                widget is Image &&
                widget.image == AssetImage('assets/images/$asset')),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _capture(tester, capture, 'verification-dialog-test-fixture');

        await tester.tap(find.widgetWithText(OutlinedButton, 'Retour'));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(summary, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
          () => MockClient(
              (_) async => fail('Review and Retour must send zero requests')));
    });
  }

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets('Weather card fits the summary at ${width.toInt()}dp',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, width == 393 ? 852 : 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final pickup = DateTime(2026, 11, 14);
      final calls = <(DateTime, String)>[];
      await tester.pumpWidget(_summary(
        pickup: pickup,
        end: DateTime(2026, 11, 17),
        weatherService: _TestWeatherService((date, location) async {
          calls.add((date, location));
          return PickupForecast(
            date: date,
            maxTemperatureCelsius: 22.4,
            weatherCode: 2,
          );
        }),
        insert: (_, __) async => fail('Viewing weather must not save a draft'),
      ));
      await tester.pumpAndSettle();

      expect(calls, [(pickup, _pickupLocation)]);
      final card = find.byType(ReservationWeatherCard);
      final cardText = find.descendant(of: card, matching: find.byType(Text));
      expect(
        tester.widgetList<Text>(cardText).map((text) => text.data),
        containsAll([
          'Météo prévue au départ',
          '14 novembre 2026',
          '22,4°C',
          'Partiellement nuageux',
          'Température max. prévue',
          'Prévisions indicatives · Source : Open-Meteo',
        ]),
      );
      expect(
          tester.getTopLeft(card).dy,
          greaterThan(
              tester.getTopLeft(find.text('Détails de votre trajet')).dy));
      expect(tester.getTopLeft(card).dy,
          lessThan(tester.getTopLeft(find.text('Tarif journalier')).dy));
      await tester.ensureVisible(find.text(_save));
      await tester.pumpAndSettle();
      expect(find.text(_save).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Forecast reloads only when the pickup changes', (tester) async {
    final calls = <(DateTime, String)>[];
    final service = _TestWeatherService((date, location) async {
      calls.add((date, location));
      if (location != _pickupLocation) return null;
      return PickupForecast(
          date: date, maxTemperatureCelsius: 19, weatherCode: 999);
    });
    Future<void> show(DateTime date, String location) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReservationWeatherCard(
            pickupDate: date,
            pickupLocation: location,
            weatherService: service,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show(DateTime(2026, 11, 14), _pickupLocation);
    expect(find.text('Conditions variables'), findsOneWidget);
    expect(find.text('19°C'), findsOneWidget);
    await show(DateTime(2026, 11, 14, 15), _pickupLocation);
    expect(calls, hasLength(1));
    await show(DateTime(2026, 11, 15), _pickupLocation);
    expect(find.text('15 novembre 2026'), findsOneWidget);
    await show(DateTime(2026, 11, 15), _returnLocation);
    expect(calls, hasLength(3));
    expect(calls.last, (DateTime(2026, 11, 15), _returnLocation));
    expect(find.text(_weatherUnavailable), findsOneWidget);
    expect(find.text('19°C'), findsNothing);
  });

  testWidgets('Only a changed pickup location requests another forecast',
      (tester) async {
    final requests = <Uri>[];
    final today = _day(0);
    final weather = WeatherService(now: () => today);
    Future<void> show(String pickup, String end) async {
      await tester.pumpWidget(_summary(
        pickupLocation: pickup,
        returnLocation: end,
        weatherService: weather,
        insert: (_, __) async => fail('No draft should be saved'),
      ));
      await tester.pumpAndSettle();
    }

    await http.runWithClient(() async {
      await show('Tunis - Aéroport', _returnLocation);
      await show('Tunis - Aéroport', 'Tunis - Les Berges du Lac');
      expect(requests, hasLength(1));
      await show(_pickupLocation, 'Tunis - Les Berges du Lac');
      expect(requests, hasLength(2));
      expect(requests.first.queryParameters['latitude'], '36.8511');
      expect(requests.last.queryParameters['latitude'], '36.87818');
      expect(requests.last.queryParameters['longitude'], '10.32466');
      expect(find.text('21°C'), findsOneWidget);
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return http.Response(
                jsonEncode({
                  'daily': {
                    'time': [_day(2).toIso8601String().substring(0, 10)],
                    'temperature_2m_max': [21],
                    'weather_code': [0],
                  },
                }),
                200,
              );
            }));
  });

  testWidgets('A pending forecast never blocks saving a draft', (tester) async {
    final pending = Completer<PickupForecast?>();
    var weatherRequests = 0;
    var saves = 0;
    await tester.pumpWidget(_summary(
      client: clientA,
      weatherService: _TestWeatherService((_, __) {
        weatherRequests++;
        return pending.future;
      }),
      insert: (_, __) async => ++saves,
    ));
    final indicator = find.descendant(
      of: find.byType(ReservationWeatherCard),
      matching: find.byType(CircularProgressIndicator),
    );
    expect(indicator, findsOneWidget);
    expect(tester.widget<CircularProgressIndicator>(indicator).semanticsLabel,
        'Chargement de la météo');
    await _tapSave(tester);
    await tester.pump();
    expect(saves, 1);
    expect(weatherRequests, 1);
    expect(find.text('Voir mes brouillons'), findsOneWidget);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text(_weatherUnavailable), findsOneWidget);
  });

  testWidgets('Capture available and unavailable weather test fixtures',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(_loadFixtureFonts);
    final pickup = DateTime(2026, 11, 14);
    for (final available in [true, false]) {
      final key = GlobalKey();
      await tester.pumpWidget(_summary(
        client: clientA,
        pickup: pickup,
        end: DateTime(2026, 11, 17),
        capture: key,
        weatherService: _TestWeatherService((date, _) async => available
            ? PickupForecast(
                date: date, maxTemperatureCelsius: 22, weatherCode: 0)
            : null),
        insert: (_, __) async => fail('Screenshot must not save a draft'),
      ));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(ReservationSummaryScreen));
        await precacheImage(
            AssetImage('assets/images/${vehicle.image}'), context);
      });
      await tester.pumpAndSettle();
      expect(
          find.text(available ? '22°C' : _weatherUnavailable), findsOneWidget);
      await _capture(
          tester,
          key,
          available
              ? 'weather-available-test-fixture'
              : 'weather-unavailable-test-fixture');
    }
  }, skip: Platform.environment['CARRENT_SUMMARY_FIXTURE_SCREENSHOTS'] == null);

  testWidgets('Rapid confirmation taps send one POST and show loading',
      (tester) async {
    final pending = Completer<http.Response>();
    final requests = <http.Request>[];
    var weatherRequests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_summary(
        client: clientA,
        weatherService: WeatherService(now: () => _day(0)),
        insert: (_, __) async => fail('Booking must not insert a draft'),
      ));
      await _tapReview(tester);
      final button =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, _book));
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(requests, hasLength(1));
      expect(find.text('Enregistrement de la réservation…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Réservation confirmée'), findsNothing);
      pending.complete(http.Response.bytes(
          utf8.encode(
              jsonEncode({'message': 'Ce véhicule vient d’être réservé.'})),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ce véhicule vient d’être réservé.'),
          findsOneWidget);
      expect(find.text('Réservation confirmée'), findsNothing);
      expect(find.text(_review), findsOneWidget);
    },
        () => MockClient((request) {
              if (request.url.host == 'api.open-meteo.com') {
                weatherRequests++;
                throw http.ClientException('Weather is offline');
              }
              expect(request.method, 'POST');
              expect(request.url.path, '/api/reservations');
              requests.add(request);
              return pending.future;
            }));
    expect(weatherRequests, 1);
  });

  for (final status in [401, 500, null]) {
    testWidgets(
        'Booking failure leaves review available (${status ?? 'network'})',
        (tester) async {
      final message = status == null
          ? 'Connexion impossible à l’API CarRent.'
          : 'Erreur de réservation $status';
      var requests = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(_summary(
          client: clientA,
          insert: (_, __) async => fail('Booking must not insert a draft'),
        ));
        await _tapReview(tester);
        await tester.tap(find.text(_book));
        await tester.pumpAndSettle();
        expect(requests, 1);
        expect(find.textContaining(message), findsOneWidget);
        expect(find.text('Réservation confirmée'), findsNothing);
        expect(find.text(_review), findsOneWidget);
      },
          () => MockClient((_) async {
                requests++;
                if (status == null) {
                  throw http.ClientException('fixture connection lost');
                }
                return http.Response(jsonEncode({'message': message}), status);
              }));
    });
  }

  for (final size in [const Size(360, 640), const Size(393, 852)]) {
    testWidgets('Local save uses the selected trip once at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final pending = Completer<int>();
      final saved = <ReservationDraft>[];
      final requests = <http.Request>[];
      final pickup = _day(2);
      final end = _day(5);
      await http.runWithClient(() async {
        await tester.pumpWidget(_summary(
          client: clientA,
          pickup: pickup,
          end: end,
          insert: (client, draft) {
            expect(client, same(clientA));
            saved.add(draft);
            return pending.future;
          },
        ));
        expect(find.text(_review), findsOneWidget);
        await _tapSave(tester);
        await tester.tap(find.text(_save));
        await tester.pump();
        expect(find.text('Enregistrement du brouillon…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(saved, hasLength(1));
        final draft = saved.single;
        expect(draft.id, isNull);
        expect(draft.clientId, clientA.id);
        expect(draft.vehicleId, vehicle.id);
        expect(draft.vehicleName, '${vehicle.marque} ${vehicle.modele}');
        expect(draft.vehicleImage, vehicle.image);
        expect(draft.dailyPriceMillimes, 120500);
        expect(draft.estimatedTotalMillimes, 361500);
        expect(draft.pickupDate,
            DateTime.utc(pickup.year, pickup.month, pickup.day));
        expect(draft.returnDate, DateTime.utc(end.year, end.month, end.day));
        expect(draft.pickupLocation, _pickupLocation);
        expect(draft.returnLocation, _returnLocation);
        expect(draft.createdAt.isUtc, isTrue);
        expect(draft.updatedAt, draft.createdAt);
        pending.complete(1);
        await tester.pumpAndSettle();
        expect(find.text('Brouillon enregistré sur cet appareil.'),
            findsOneWidget);
        expect(find.text('Voir mes brouillons'), findsOneWidget);
        expect(find.text(_review), findsOneWidget);
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request);
                return http.Response('{}', 500);
              }));
    });
  }

  testWidgets(
      'Database error allows a retry with identical pickup and return locations',
      (tester) async {
    var inserts = 0;
    await tester.pumpWidget(_summary(
      client: clientA,
      returnLocation: _pickupLocation,
      insert: (_, draft) async {
        expect(draft.pickupLocation, _pickupLocation);
        expect(draft.returnLocation, _pickupLocation);
        if (++inserts == 1) throw StateError('fixture disk error');
        return 1;
      },
    ));
    await _tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('Impossible d’enregistrer le brouillon. Réessayez.'),
        findsOneWidget);
    expect(find.text('Voir mes brouillons'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await _tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('Voir mes brouillons'), findsOneWidget);
    expect(inserts, 2);
  });

  testWidgets('A missing client disables only the draft action',
      (tester) async {
    await tester.pumpWidget(_summary(insert: (_, __) async {
      fail('A draft requires a client');
    }));
    final draftButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, _save),
    );
    final bookingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, _review),
    );
    expect(draftButton.onPressed, isNull);
    expect(bookingButton.onPressed, isNotNull);
    expect(find.textContaining('Connectez-vous avec un compte client'),
        findsOneWidget);
  });

  testWidgets('Invalid trips and vehicle data never reach the database',
      (tester) async {
    Future<int> unexpected(User _, ReservationDraft __) async {
      fail('Invalid draft reached the database');
    }

    final invalidTrips = [
      _summary(client: clientA, pickup: _day(-1), insert: unexpected),
      _summary(client: clientA, end: _day(2), insert: unexpected),
      _summary(client: clientA, end: _day(33), insert: unexpected),
      _summary(client: clientA, pickupLocation: ' ', insert: unexpected),
      _summary(client: clientA, returnLocation: ' ', insert: unexpected),
    ];
    for (final summary in invalidTrips) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(summary);
      await _tapSave(tester);
      await tester.pumpAndSettle();
      expect(find.text('Vérifiez les dates et les lieux de votre réservation.'),
          findsOneWidget);
    }

    final invalidVehicles = [
      vehicle.copyWith(id: 'invalid'),
      Vehicle.fromJson(vehicle.toJson()
        ..['_id'] = vehicle.id
        ..['prix'] = -1),
    ];
    for (final invalidVehicle in invalidVehicles) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_summary(
        client: clientA,
        selectedVehicle: invalidVehicle,
        insert: unexpected,
      ));
      await _tapSave(tester);
      await tester.pumpAndSettle();
      expect(
          find.text('Le véhicule ou son tarif est invalide.'), findsOneWidget);
    }
  });

  testWidgets(
      'Primary booking still uses the original service and server reference',
      (tester) async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_summary(
          client: clientA,
          insert: (_, __) async {
            fail('Real booking should not insert a local draft');
          }));
      await tester.ensureVisible(find.text(_review));
      await tester.tap(find.text(_review));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.tap(find.text(_book));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/reservations');
      expect(request.headers['Authorization'], 'Bearer fixture-token');
      expect(jsonDecode(request.body), {
        'vehicleId': vehicle.id,
        'pickupDate': _day(2).toIso8601String().substring(0, 10),
        'returnDate': _day(5).toIso8601String().substring(0, 10),
        'pickupLocation': _pickupLocation,
        'returnLocation': _returnLocation,
      });
      expect(find.text('Réservation confirmée'), findsOneWidget);
      expect(find.textContaining('Référence : 000000000000000000000004'),
          findsOneWidget);
      expect(
          find.textContaining('Total confirmé : 369.125 DT'), findsOneWidget);
      expect(find.textContaining(_returnLocation), findsWidgets);
      expect(find.text('Brouillon enregistré sur cet appareil.'), findsNothing);
    },
        () => MockClient((request) async {
              requests.add(request);
              final payload = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': {
                      ...payload,
                      '_id': '000000000000000000000004',
                      'clientId': clientA.id,
                      'pickupDate': "${payload['pickupDate']}T00:00:00.000Z",
                      'returnDate': "${payload['returnDate']}T00:00:00.000Z",
                      'status': 'confirmed',
                      'totalPriceMillimes': 369125,
                    },
                  }),
                  201);
            }));
  });

  testWidgets(
      'Saved draft opens the same client’s drafts and Back does not insert again',
      (tester) async {
    var inserts = 0;
    await tester.pumpWidget(
        _summary(client: clientA, insert: (_, __) async => ++inserts));
    await _tapSave(tester);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.ensureVisible(find.text('Voir mes brouillons'));
    await tester.tap(find.text('Voir mes brouillons'));
    await tester.pumpAndSettle();
    final drafts = tester
        .widget<ReservationDraftsScreen>(find.byType(ReservationDraftsScreen));
    expect(drafts.client, same(clientA));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Voir mes brouillons'), findsOneWidget);
    expect(inserts, 1);
  });
}
