import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carrent_client/database/reservation_draft_database.dart';
import 'package:carrent_client/models/reservation_draft.dart';
import 'package:carrent_client/models/user_model.dart';
import 'package:carrent_client/screens/reservations/available_cars_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_drafts_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_search_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_summary_screen.dart';
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

const _resume = 'Reprendre';
const _update = 'Mettre à jour le brouillon';
const _search = 'Rechercher des voitures';
const _choose = 'Choisir cette voiture';
const _pickupLocation = 'Tunis - La Marsa';
const _returnLocation = 'Tunis - Centre-ville';
const _otherVehicleId = '000000000000000000000004';
const _sessionChanged = 'Votre session a changé. Rouvrez vos brouillons.';

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

String _date(DateTime day) => day.toIso8601String().substring(0, 10);

ReservationDraft _saved({int start = 2}) {
  return ReservationDraft.fromVehicle(
    id: 42,
    createdAt: DateTime.utc(2025, 1, 1),
    client: clientA,
    vehicle: vehicle,
    pickupDate: _day(start),
    returnDate: _day(start + 3),
    pickupLocation: _pickupLocation,
    returnLocation: _returnLocation,
  );
}

class _DraftDatabase extends ReservationDraftDatabase {
  ReservationDraft? row;
  int reads = 0;
  int writes = 0;
  bool disappearsOnUpdate = false;
  Completer<void>? updatePending;

  _DraftDatabase(this.row);

  @override
  Future<List<ReservationDraft>> getAllDrafts(User client) async {
    final draft = row;
    return draft != null && draft.clientId == client.id ? [draft] : [];
  }

  @override
  Future<ReservationDraft?> getDraftById(User client, int id) async {
    expect(client, same(clientA));
    reads++;
    return row?.id == id && row?.clientId == client.id ? row : null;
  }

  @override
  Future<int> updateDraft(User client, ReservationDraft draft) async {
    expect(client, same(clientA));
    writes++;
    expect(draft.id, row?.id);
    expect(draft.createdAt, row?.createdAt);
    await updatePending?.future;
    if (disappearsOnUpdate) {
      row = null;
      return 0;
    }
    row = draft;
    return 1;
  }

  @override
  Future<int> insertDraft(User client, ReservationDraft draft) async {
    fail('Editing must not insert a new row');
  }

  @override
  Future<int> deleteDraft(User client, int id) async {
    fail('Resuming must not delete a row');
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _resumeDraft(WidgetTester tester) async {
  await _tap(tester, find.text(_resume));
  await _tap(tester, find.widgetWithText(FilledButton, _resume));
}

Map<String, Object?> _vehicleJson({String? id, double price = 120.5}) {
  return {
    ...vehicle.toJson(),
    '_id': id ?? vehicle.id,
    if (id == _otherVehicleId) 'modele': 'Corolla',
    'prix': price,
  };
}

Future<T> _withAvailability<T>(
  List<Map<String, Object?>> vehicles,
  List<http.Request> requests,
  Future<T> Function() body,
) {
  return http.runWithClient(
      body,
      () => MockClient((request) async {
            if (request.url.host == 'api.open-meteo.com') {
              return http.Response('{}', 503);
            }
            requests.add(request);
            expect(request.method, 'GET');
            expect(request.url.path, '/api/vehicles/available');
            return http.Response(jsonEncode({'data': vehicles}), 200);
          }));
}

Widget _app(_DraftDatabase database, {GlobalKey? capture, bool fonts = false}) {
  return RepaintBoundary(
    key: capture,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light.copyWith(
        textTheme: fonts ? ThemeData(fontFamily: 'Roboto').textTheme : null,
      ),
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
      home: ReservationDraftsScreen(client: clientA, draftDatabase: database),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_carrent_token': 'test-session-a',
    });
  });

  for (final size in [const Size(360, 640), const Size(393, 852)]) {
    testWidgets('Edit and refresh the same draft at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final original = _saved();
      final database = _DraftDatabase(original);
      final requests = <http.Request>[];
      final directory = size.width == 393
          ? Platform.environment['CARRENT_DRAFT_EDIT_SCREENSHOTS']
          : null;
      final boundary = directory == null ? null : GlobalKey();
      final fontDirectory = Platform.environment['CARRENT_DRAFT_FIXTURE_FONTS'];
      final iconFont = Platform.environment['CARRENT_DRAFT_FIXTURE_ICONS'];
      if (boundary != null) {
        await tester.runAsync(() async {
          if (fontDirectory != null) {
            final loader = FontLoader('Roboto');
            for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
              loader.addFont(File('$fontDirectory/$name')
                  .readAsBytes()
                  .then(ByteData.sublistView));
            }
            await loader.load();
          }
          if (iconFont != null) {
            final loader = FontLoader('MaterialIcons');
            loader.addFont(
                File(iconFont).readAsBytes().then(ByteData.sublistView));
            await loader.load();
          }
        });
      }

      Future<void> screenshot(String name) async {
        if (boundary == null) return;
        await tester.runAsync(() async {
          final box = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await box.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File('$directory/draft-edit-fixture-$name.png')
              .writeAsBytes(png!.buffer.asUint8List());
        });
      }

      await _withAvailability([_vehicleJson()], requests, () async {
        await tester.pumpWidget(
            _app(database, capture: boundary, fonts: fontDirectory != null));
        if (boundary != null) {
          await tester.runAsync(() async {
            await precacheImage(
                const AssetImage('assets/images/toyota yaris.png'),
                tester.element(find.byType(ReservationDraftsScreen)));
          });
        }
        await tester.pumpAndSettle();
        expect(find.text(_resume), findsOneWidget);
        expect(find.text('Supprimer'), findsOneWidget);
        await screenshot('list');
        await _tap(tester, find.text(_resume));
        final dialog = find.byType(AlertDialog);
        expect(find.text('Reprendre ce brouillon ?'), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.byType(Image)),
            findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text('Toyota Yaris')),
            findsOneWidget);
        expect(find.text('Prise en charge : $_pickupLocation'), findsOneWidget);
        expect(find.text('Retour : $_returnLocation'), findsOneWidget);
        expect(
            find.descendant(
                of: dialog, matching: find.textContaining('361.500 DT')),
            findsOneWidget);
        await screenshot('resume-dialog');
        await _tap(tester, find.text('Annuler'));
        expect(find.byType(ReservationSearchScreen), findsNothing);
        expect(database.row, same(original));
        expect(database.writes, 0);

        await _resumeDraft(tester);
        final search = tester.widget<ReservationSearchScreen>(
            find.byType(ReservationSearchScreen));
        expect(search.client, same(clientA));
        expect(search.draft, same(original));
        final pickup = tester.widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('pickupLocation')));
        final end = tester.widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('returnLocation')));
        expect(pickup.initialValue, _pickupLocation);
        expect(end.initialValue, _returnLocation);
        expect(find.text('3 jours de location'), findsOneWidget);
        if (boundary != null) {
          await tester.ensureVisible(find.text(_search));
          await tester.pumpAndSettle();
        }
        await screenshot('prefilled-search');

        await _tap(tester, find.byKey(const Key('returnDate')));
        expect(
            tester
                .widget<DatePickerDialog>(find.byType(DatePickerDialog))
                .initialDate,
            _day(5));
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        final day = _day(6);
        final dateField = find.byType(TextField);
        final localizations =
            MaterialLocalizations.of(tester.element(dateField));
        await tester.enterText(dateField, localizations.formatCompactDate(day));
        await _tap(tester, find.text('OK'));
        expect(find.text('4 jours de location'), findsOneWidget);

        await _tap(tester, find.text(_search));
        expect(requests.single.url.queryParameters, {
          'pickupDate': _date(_day(2)),
          'returnDate': _date(_day(6)),
        });
        final results = tester
            .widget<AvailableCarsScreen>(find.byType(AvailableCarsScreen));
        expect(results.draft, same(original));
        expect(results.client, same(clientA));
        expect(find.text('Véhicule du brouillon'), findsOneWidget);
        await _tap(tester, find.text(_choose));
        final summary = tester.widget<ReservationSummaryScreen>(
            find.byType(ReservationSummaryScreen));
        expect(summary.draft?.id, original.id);
        expect(summary.vehicle.id, original.vehicleId);
        expect(summary.client, same(clientA));
        expect(summary.pickupLocation, _pickupLocation);
        expect(summary.returnLocation, _returnLocation);
        expect(find.text('482.000 DT'), findsOneWidget);
        expect(find.text('Vérifier ma réservation'), findsOneWidget);
        expect(find.text('Enregistrer comme brouillon'), findsNothing);
        await _tap(tester, find.text(_update));
        expect(database.writes, 1);
        expect(database.row?.id, original.id);
        expect(database.row?.createdAt, original.createdAt);
        expect(database.row?.dailyPriceMillimes, 120500);
        expect(database.row?.rentalDays, 4);
        expect(database.row?.pickupLocation, _pickupLocation);
        expect(database.row?.returnLocation, _returnLocation);
        expect(database.row?.estimatedTotalMillimes, 482000);
        expect(find.byType(ReservationDraftsScreen), findsOneWidget);
        expect(find.byType(ReservationSearchScreen), findsNothing);
        expect(find.text('Total estimé · 482.000 DT'), findsOneWidget);
        expect(find.text('Brouillon mis à jour sur cet appareil.'),
            findsOneWidget);
        await screenshot('updated-draft');
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('Unavailable original can be replaced only by explicit choice',
      (tester) async {
    final original = _saved();
    final database = _DraftDatabase(original);
    final requests = <http.Request>[];
    await _withAvailability(
        [_vehicleJson(id: _otherVehicleId, price: 125.123)], requests,
        () async {
      await tester.pumpWidget(_app(database));
      await tester.pumpAndSettle();
      await _resumeDraft(tester);
      await _tap(tester, find.byKey(const Key('returnLocation')));
      await _tap(tester, find.text('Tunis - Aéroport').hitTestable());
      await _tap(tester, find.text(_search));
      expect(find.textContaining('est indisponible pour ces dates'),
          findsOneWidget);
      expect(find.byType(ReservationSummaryScreen), findsNothing);
      expect(find.text('Véhicule du brouillon'), findsNothing);
      await _tap(tester, find.text('Modifier'));
      expect(find.text('3 jours de location'), findsOneWidget);
      await _tap(tester, find.text(_search));
      await _tap(tester, find.text(_choose));
      expect(find.text('375.369 DT'), findsOneWidget);
      await _tap(tester, find.text(_update));
      expect(database.row?.id, original.id);
      expect(database.row?.vehicleId, _otherVehicleId);
      expect(database.row?.vehicleName, 'Toyota Corolla');
      expect(database.row?.dailyPriceMillimes, 125123);
      expect(database.row?.pickupLocation, _pickupLocation);
      expect(database.row?.returnLocation, 'Tunis - Aéroport');
      expect(requests, hasLength(2));
    });
  });

  testWidgets('Updated backend price is shown and Back leaves the row intact',
      (tester) async {
    final original = _saved();
    final database = _DraftDatabase(original);
    await _withAvailability([_vehicleJson(price: 125.123)], [], () async {
      await tester.pumpWidget(_app(database));
      await tester.pumpAndSettle();
      await _resumeDraft(tester);
      await _tap(tester, find.text(_search));
      expect(find.textContaining('Tarif actuel : 125.123 DT / jour'),
          findsOneWidget);
      await _tap(tester, find.text(_choose));
      expect(find.text('375.369 DT'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await _tap(tester, find.byType(BackButton));
      }
      expect(find.byType(ReservationDraftsScreen), findsOneWidget);
      expect(database.row, same(original));
      expect(database.writes, 0);
    });
  });

  for (final alreadyMissing in [true, false]) {
    testWidgets('Missing row is handled (before update: $alreadyMissing)',
        (tester) async {
      final database = _DraftDatabase(_saved());
      await _withAvailability([_vehicleJson()], [], () async {
        await tester.pumpWidget(_app(database));
        await tester.pumpAndSettle();
        await _resumeDraft(tester);
        await _tap(tester, find.text(_search));
        await _tap(tester, find.text(_choose));
        if (alreadyMissing) {
          database.row = null;
        } else {
          database.disappearsOnUpdate = true;
        }
        await _tap(tester, find.text(_update));
        expect(find.text('Ce brouillon n’est plus sur cet appareil.'),
            findsOneWidget);
        expect(find.byType(ReservationSummaryScreen), findsOneWidget);
        expect(database.writes, alreadyMissing ? 0 : 1);
      });
    });
  }

  testWidgets('Switching sessions blocks an update and a booking attempt',
      (tester) async {
    final original = _saved();
    final database = _DraftDatabase(original);
    final requests = <http.Request>[];
    await _withAvailability([_vehicleJson()], requests, () async {
      await tester.pumpWidget(_app(database));
      await tester.pumpAndSettle();
      await _resumeDraft(tester);
      await _tap(tester, find.text(_search));
      await _tap(tester, find.text(_choose));
      await UserService.saveToken('test-session-b');
      await _tap(tester, find.text(_update));
      expect(find.text(_sessionChanged), findsOneWidget);
      await _tap(tester, find.text('Vérifier ma réservation'));
      await _tap(tester, find.text('Confirmer la réservation'));
      expect(find.text(_sessionChanged), findsOneWidget);
      expect(database.row, same(original));
      expect(database.reads, 0);
      expect(database.writes, 0);
      expect(requests, hasLength(1));
    });
  });

  testWidgets('Saving an edit prevents a second tap and Back while pending',
      (tester) async {
    final database = _DraftDatabase(_saved());
    final pending = Completer<void>();
    database.updatePending = pending;
    await _withAvailability([_vehicleJson()], [], () async {
      await tester.pumpWidget(_app(database));
      await tester.pumpAndSettle();
      await _resumeDraft(tester);
      await _tap(tester, find.text(_search));
      await _tap(tester, find.text(_choose));
      await tester.ensureVisible(find.text(_update));
      await tester.pump();
      await tester.tap(find.text(_update));
      await tester.tap(find.text(_update));
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(database.writes, 1);
      expect(find.byType(ReservationSummaryScreen), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ReservationDraftsScreen), findsOneWidget);
      expect(database.writes, 1);
    });
  });

  testWidgets('Past dates can be reopened but cannot run a search',
      (tester) async {
    final database = _DraftDatabase(_saved(start: -6));
    final requests = <http.Request>[];
    await _withAvailability([], requests, () async {
      await tester.pumpWidget(_app(database));
      await tester.pumpAndSettle();
      await _resumeDraft(tester);
      await _tap(tester, find.text(_search));
      expect(find.text('Choisissez aujourd’hui ou une date future.'),
          findsOneWidget);
      expect(requests, isEmpty);
      await _tap(tester, find.byKey(const Key('pickupDate')));
      expect(
          tester
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .initialDate,
          _day(0));
      await _tap(tester, find.text('OK'));
      await _tap(tester, find.byKey(const Key('returnDate')));
      await _tap(tester, find.text('OK'));
      await _tap(tester, find.text(_search));
      expect(find.textContaining('est indisponible pour ces dates'),
          findsOneWidget);
      expect(find.text('Aucun véhicule disponible sur cette période.'),
          findsOneWidget);
      expect(database.writes, 0);
    });
  });
}
