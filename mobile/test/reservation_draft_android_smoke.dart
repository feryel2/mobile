// Run with flutter run -d DEVICE_ID -t test/reservation_draft_android_smoke.dart.
import 'dart:io';

import 'package:carrent_client/database/reservation_draft_database.dart';
import 'package:carrent_client/models/reservation_draft.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'fixtures/reservation_drafts.dart';

void _check(bool passed, String message) {
  if (!passed) throw StateError(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw UnsupportedError('Run this check on Android.');

  final temp = await Directory.systemTemp.createTemp('carrent-draft-smoke-');
  final file = path.join(temp.path, 'carrent_local.db');
  final drafts = ReservationDraftDatabase.forTesting(databaseFactory, file);

  Future<void> closeDatabase() async {
    if (await File(file).exists()) {
      final database = await databaseFactory.openDatabase(file);
      await database.close();
    }
  }

  try {
    final id = await drafts.insertDraft(clientA, draftFor(clientA));
    final otherId = await drafts.insertDraft(clientB, draftFor(clientB));
    final original = (await drafts.getDraftById(clientA, id))!;
    final edited = ReservationDraft.fromMap(
      original.toMap()..['returnLocation'] = 'Sousse',
    );
    _check(id > 0 && otherId > id, 'Expected SQLite-generated IDs.');
    _check(
        await drafts.getDraftById(clientB, id) == null, 'Read leaked a draft.');
    _check(await drafts.deleteDraft(clientB, id) == 0,
        'Wrong account deleted a draft.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _check(await drafts.updateDraft(clientA, edited) == 1,
        'Update should change one row.');
    await closeDatabase();

    final reopened = (await drafts.getAllDrafts(clientA)).single;
    _check(reopened.id == id && reopened.returnLocation == 'Sousse',
        'Edit did not persist.');
    _check(reopened.createdAt == original.createdAt, 'Creation time changed.');
    _check(reopened.updatedAt.isAfter(original.updatedAt),
        'Update time was not refreshed.');
    _check(reopened.estimatedTotalMillimes == 361500, 'Millime total changed.');
    _check(
        await drafts.deleteDraft(clientA, id) == 1, 'Expected one deletion.');
    await closeDatabase();

    _check((await drafts.getAllDrafts(clientA)).isEmpty,
        'Deletion did not persist.');
    _check((await drafts.getAllDrafts(clientB)).single.id == otherId,
        'Other account lost its draft.');
  } finally {
    try {
      await closeDatabase();
    } finally {
      await temp.delete(recursive: true);
    }
  }
  debugPrint('CARRENT_TEAM_DRAFT_SMOKE_PASS');
}
