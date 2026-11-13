import 'dart:io';

import 'package:carrent_client/database/reservation_draft_database.dart';
import 'package:carrent_client/models/reservation_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/reservation_drafts.dart';

void main() {
  sqfliteFfiInit();
  late Directory temp;
  late String file;
  late ReservationDraftDatabase drafts;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('carrent-team-drafts-');
    file = path.join(temp.path, 'carrent_local.db');
    drafts = ReservationDraftDatabase.forTesting(databaseFactoryFfi, file);
  });

  tearDown(() async {
    try {
      if (await File(file).exists()) {
        final database = await databaseFactoryFfi.openDatabase(file);
        await database.close();
      }
    } finally {
      await temp.delete(recursive: true);
    }
  });

  test('generated IDs, timestamps, update and selected deletion persist',
      () async {
    expect(await drafts.getAllDrafts(clientA), isEmpty);
    final newDraft = draftFor(clientA);
    final id = await drafts.insertDraft(clientA, newDraft);
    final secondId = await drafts.insertDraft(clientA, newDraft);
    expect(id, greaterThan(0));
    expect(secondId, greaterThan(id));
    final original = (await drafts.getDraftById(clientA, id))!;
    expect(original.createdAt, original.updatedAt);
    expect(original.vehicleId, vehicle.id);
    expect(original.dailyPriceMillimes, 120500);

    final edited = ReservationDraft.fromMap(original.toMap()
      ..['returnLocation'] = 'Sousse'
      ..['createdAt'] = '2000-01-01T00:00:00.000Z'
      ..['updatedAt'] = '2000-01-01T00:00:00.000Z');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await drafts.updateDraft(clientA, edited), 1);
    final rows = await drafts.getAllDrafts(clientA);
    expect(rows.map((draft) => draft.id), [id, secondId]);
    final updated = rows.first;
    expect(updated.returnLocation, 'Sousse');
    expect(updated.pickupLocation, original.pickupLocation);
    expect(updated.createdAt, original.createdAt);
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);

    final database = await databaseFactoryFfi.openDatabase(file);
    await database.close();
    expect((await drafts.getDraftById(clientA, id))!.toMap(), updated.toMap());
    expect(await drafts.deleteDraft(clientA, id), 1);
    expect(await drafts.getDraftById(clientA, id), isNull);
    expect((await drafts.getAllDrafts(clientA)).single.id, secondId);
  });

  test('each account can access only its own drafts', () async {
    final a = await drafts.insertDraft(clientA, draftFor(clientA));
    final b = await drafts.insertDraft(clientB, draftFor(clientB));
    expect((await drafts.getAllDrafts(clientA)).single.id, a);
    expect((await drafts.getAllDrafts(clientB)).single.id, b);
    expect(await drafts.getDraftById(clientA, b), isNull);
    expect(await drafts.deleteDraft(clientA, b), 0);

    final otherDraft = (await drafts.getDraftById(clientB, b))!;
    await expectLater(
        drafts.insertDraft(clientA, otherDraft), throwsArgumentError);
    await expectLater(
        drafts.updateDraft(clientA, otherDraft), throwsArgumentError);
    final spoofed = ReservationDraft.fromMap(draftFor(clientA).toMap()
      ..['id'] = b
      ..['returnLocation'] = 'Changed by another account');
    expect(await drafts.updateDraft(clientA, spoofed), 0);
    expect(
        (await drafts.getDraftById(clientB, b))!.toMap(), otherDraft.toMap());
  });

  test('unknown IDs stay missing and updates require an existing ID', () async {
    expect(await drafts.getDraftById(clientA, 99), isNull);
    expect(await drafts.deleteDraft(clientA, 99), 0);
    final missing =
        ReservationDraft.fromMap(draftFor(clientA).toMap()..['id'] = 99);
    expect(await drafts.updateDraft(clientA, missing), 0);
    await expectLater(
        drafts.updateDraft(clientA, draftFor(clientA)), throwsArgumentError);
    expect(await drafts.getAllDrafts(clientA), isEmpty);
  });
}
