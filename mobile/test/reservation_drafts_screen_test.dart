import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carrent_client/models/reservation_draft.dart';
import 'package:carrent_client/models/user_model.dart';
import 'package:carrent_client/screens/profile_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_drafts_screen.dart';
import 'package:carrent_client/screens/reservations/reservation_search_screen.dart';
import 'package:carrent_client/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'fixtures/reservation_drafts.dart';

ReservationDraft _draft(User client, int id, {String? name, String? image}) {
  final map = draftFor(client).toMap()..['id'] = id;
  if (name != null) map['vehicleName'] = name;
  if (image != null) map['vehicleImage'] = image;
  return ReservationDraft.fromMap(map);
}

void _phone(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _ProfileService extends UserService {
  @override
  Future<Map<String, dynamic>> getProfile() async =>
      {'success': true, 'user': clientA};
}

void main() {
  testWidgets(
      'The team Réserver tab passes its current client and Back returns',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(userService: _ProfileService()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réserver'));
    await tester.pumpAndSettle();
    final search = tester.state(find.byType(ReservationSearchScreen));
    await _tap(tester, find.text('Mes brouillons'));
    expect(
        tester
            .widget<ReservationDraftsScreen>(
              find.byType(ReservationDraftsScreen),
            )
            .client,
        same(clientA));
    expect(find.text('Brouillons sur mobile'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ReservationSearchScreen)), same(search));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('No user means no draft entry and no database read',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReservationSearchScreen()));
    expect(find.text('Mes brouillons'), findsNothing);
    var reads = 0;
    await tester.pumpWidget(MaterialApp(
      home: ReservationDraftsScreen(
        client: null,
        loadDrafts: (_) async {
          reads++;
          return [_draft(clientA, 1)];
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Connexion nécessaire'), findsOneWidget);
    expect(find.text('Toyota Yaris'), findsNothing);
    expect(reads, 0);
  });

  for (final size in [const Size(360, 640), const Size(393, 852)]) {
    testWidgets('Own draft shows image, locations and exact price at $size',
        (tester) async {
      _phone(tester, size);
      final requests = <User>[];
      await tester.pumpWidget(MaterialApp(
        home: ReservationDraftsScreen(
          client: clientA,
          loadDrafts: (client) async {
            requests.add(client);
            return [
              _draft(clientA, 1),
              _draft(clientB, 2, name: 'Private draft')
            ];
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(requests, [clientA]);
      expect(find.text('Toyota Yaris'), findsOneWidget);
      expect(find.text('Private draft'), findsNothing);
      expect(find.text('Brouillon'), findsOneWidget);
      expect(find.text('10–13 déc. 2026'), findsOneWidget);
      expect(find.text('Prise en charge · Tunis - Aéroport'), findsOneWidget);
      expect(find.text('Retour · Tunis - Centre-ville'), findsOneWidget);
      expect(find.text('Total estimé · 361.500 DT'), findsOneWidget);
      final photo = tester.widget<Image>(find.byType(Image));
      expect((photo.image as AssetImage).assetName,
          'assets/images/toyota yaris.png');
      expect(find.text('Reprendre'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Switching account clears the old list while the new one loads',
      (tester) async {
    final pending = Completer<List<ReservationDraft>>();
    final requested = <User>[];
    Future<List<ReservationDraft>> load(User client) {
      requested.add(client);
      return client == clientA
          ? Future.value([_draft(clientA, 1)])
          : pending.future;
    }

    Future<void> show(User? client) => tester.pumpWidget(MaterialApp(
          home: ReservationDraftsScreen(client: client, loadDrafts: load),
        ));
    await show(clientA);
    await tester.pumpAndSettle();
    expect(find.text('Toyota Yaris'), findsOneWidget);
    await show(clientB);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Toyota Yaris'), findsNothing);
    pending.complete([_draft(clientB, 2, name: 'Second account')]);
    await tester.pumpAndSettle();
    expect(find.text('Second account'), findsOneWidget);
    await show(null);
    await tester.pumpAndSettle();
    expect(find.text('Second account'), findsNothing);
    expect(find.text('Connexion nécessaire'), findsOneWidget);
    expect(requested, [clientA, clientB]);
  });

  testWidgets(
      'Loading and friendly read error can be retried to the empty state',
      (tester) async {
    final pending = Completer<List<ReservationDraft>>();
    var reads = 0;
    await tester.pumpWidget(MaterialApp(
      home: ReservationDraftsScreen(
        client: clientA,
        loadDrafts: (_) => ++reads == 1 ? pending.future : Future.value([]),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('internal error'));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger les brouillons'), findsOneWidget);
    expect(find.textContaining('internal error'), findsNothing);
    await _tap(tester, find.text('Réessayer'));
    expect(find.text('Aucun brouillon enregistré'), findsOneWidget);
    expect(
        find.text('Enregistrez une réservation pour la retrouver plus tard.'),
        findsOneWidget);
  });

  testWidgets('Cancel keeps drafts, confirm deletes just one and reloads',
      (tester) async {
    final rows = [
      _draft(clientA, 42, image: 'missing.png'),
      _draft(clientA, 51, name: 'Second draft'),
    ];
    final deleted = <int>[];
    var reads = 0;
    await tester.pumpWidget(MaterialApp(
      home: ReservationDraftsScreen(
        client: clientA,
        loadDrafts: (client) async {
          expect(client, same(clientA));
          reads++;
          return List.of(rows);
        },
        deleteDraft: (client, id) async {
          expect(client, same(clientA));
          deleted.add(id);
          rows.removeWhere((row) => row.id == id);
          return 1;
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.semanticLabel == 'Photo générique de véhicule'),
        findsOneWidget);
    final remove = find.descendant(
      of: find.byKey(const ValueKey<int?>(42)),
      matching: find.text('Supprimer'),
    );
    await _tap(tester, remove);
    expect(find.text('Supprimer ce brouillon ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(reads, 1);
    await _tap(tester, remove);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(deleted, [42]);
    expect(reads, 2);
    expect(find.text('Toyota Yaris'), findsNothing);
    expect(find.text('Second draft'), findsOneWidget);
    expect(find.text('Brouillon supprimé.'), findsOneWidget);
  });

  testWidgets('Delete failure keeps the card and shows a friendly message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReservationDraftsScreen(
        client: clientA,
        loadDrafts: (_) async => [_draft(clientA, 42)],
        deleteDraft: (_, __) async => throw StateError('internal error'),
      ),
    ));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Supprimer'));
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Toyota Yaris'), findsOneWidget);
    expect(find.text('Impossible de supprimer le brouillon. Réessayez.'),
        findsOneWidget);
  });

  testWidgets('An old confirmation cannot delete after the account changes',
      (tester) async {
    var deletes = 0;
    Future<void> show(User client) => tester.pumpWidget(MaterialApp(
          home: ReservationDraftsScreen(
            client: client,
            loadDrafts: (user) async => [_draft(user, 42)],
            deleteDraft: (_, __) async => ++deletes,
          ),
        ));
    await show(clientA);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Supprimer'));
    await show(clientB);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
  });

  final captureDirectory =
      Platform.environment['CARRENT_DRAFT_FIXTURE_SCREENSHOTS'];
  testWidgets('Capture the three explicitly labeled draft fixture states',
      (tester) async {
    _phone(tester, const Size(393, 852));
    final fontDirectory = Platform.environment['CARRENT_DRAFT_FIXTURE_FONTS'];
    if (fontDirectory != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto');
        for (final font in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
          loader.addFont(File(path.join(fontDirectory, font))
              .readAsBytes()
              .then(ByteData.sublistView));
        }
        await loader.load();
      });
    }
    final iconFont = Platform.environment['CARRENT_DRAFT_FIXTURE_ICONS'];
    if (iconFont != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('MaterialIcons');
        loader.addFont(File(iconFont).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      });
    }
    final boundary = GlobalKey();
    final rows = [_draft(clientA, 1)];
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: fontDirectory == null ? null : 'Roboto'),
        builder: (context, child) => Column(
          children: [
            const Material(
              color: Color(0xFF102047),
              child: SizedBox(
                width: double.infinity,
                height: 28,
                child: Center(
                  child: Text('TEST FIXTURE',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        ),
        home: ReservationDraftsScreen(
          client: clientA,
          loadDrafts: (_) async => List.of(rows),
          deleteDraft: (_, __) async {
            rows.clear();
            return 1;
          },
        ),
      ),
    ));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(ReservationDraftsScreen));
      await precacheImage(
          const AssetImage('assets/images/toyota yaris.png'), context);
    });
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final box = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await box.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file =
            File(path.join(captureDirectory!, 'drafts-test-fixture-$name.png'));
        await file.writeAsBytes(png!.buffer.asUint8List());
      });
    }

    await capture('list');
    await _tap(tester, find.text('Supprimer'));
    await capture('delete-confirmation');
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Aucun brouillon enregistré'), findsOneWidget);
    await capture('empty');
  }, skip: captureDirectory == null);
}
