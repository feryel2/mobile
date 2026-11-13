import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/reservation_draft.dart';
import '../models/user_model.dart';

class ReservationDraftDatabase {
  static const _fileName = 'carrent_local.db';
  static const _table = 'reservation_drafts';

  final DatabaseFactory? _testFactory;
  final String? _testPath;

  const ReservationDraftDatabase()
      : _testFactory = null,
        _testPath = null;

  // Tests supply a temporary file and use the same schema and CRUD methods.
  @visibleForTesting
  const ReservationDraftDatabase.forTesting(
    DatabaseFactory factory,
    String databasePath,
  )   : _testFactory = factory,
        _testPath = databasePath;

  Future<Database> _open() async {
    final factory = _testFactory;
    if (factory == null &&
        (kIsWeb ||
            (defaultTargetPlatform != TargetPlatform.android &&
                defaultTargetPlatform != TargetPlatform.iOS))) {
      throw UnsupportedError('The draft database requires Android or iOS.');
    }

    final database = factory ?? databaseFactory;
    final file =
        _testPath ?? path.join(await database.getDatabasesPath(), _fileName);
    return database.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_table (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              clientId TEXT NOT NULL,
              vehicleId TEXT NOT NULL,
              vehicleName TEXT NOT NULL,
              vehicleImage TEXT,
              dailyPriceMillimes INTEGER NOT NULL CHECK (dailyPriceMillimes >= 0),
              pickupDate TEXT NOT NULL,
              returnDate TEXT NOT NULL,
              pickupLocation TEXT NOT NULL,
              returnLocation TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
        },
      ),
    );
  }

  // Callers must pass the current User from the existing authenticated session.
  // A client ID in the draft data cannot establish ownership by itself.
  String _clientId(User client) {
    if (client.role != 'client' ||
        !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(client.id)) {
      throw ArgumentError('A server-issued client identity is required.');
    }
    return client.id;
  }

  String _ownerOf(User client, ReservationDraft draft) {
    final clientId = _clientId(client);
    if (draft.clientId != clientId) {
      throw ArgumentError('The draft belongs to a different client.');
    }
    return clientId;
  }

  Future<int> insertDraft(User client, ReservationDraft draft) async {
    final clientId = _ownerOf(client, draft);
    final database = await _open();
    final timestamp = _timestamp();
    final values = draft.toMap()
      ..remove('id')
      ..['clientId'] = clientId
      ..['createdAt'] = timestamp
      ..['updatedAt'] = timestamp;
    return database.insert(_table, values);
  }

  Future<List<ReservationDraft>> getAllDrafts(User client) async {
    final clientId = _clientId(client);
    final database = await _open();
    final rows = await database.query(
      _table,
      where: 'clientId = ?',
      whereArgs: [clientId],
      orderBy: 'updatedAt DESC, id DESC',
    );
    return rows.map(ReservationDraft.fromMap).toList();
  }

  Future<ReservationDraft?> getDraftById(User client, int id) async {
    final clientId = _clientId(client);
    final database = await _open();
    final rows = await database.query(
      _table,
      where: 'id = ? AND clientId = ?',
      whereArgs: [id, clientId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReservationDraft.fromMap(rows.first);
  }

  Future<int> updateDraft(User client, ReservationDraft draft) async {
    final clientId = _ownerOf(client, draft);
    final id = draft.id;
    if (id == null) {
      throw ArgumentError('An update requires a saved draft ID.');
    }

    final database = await _open();
    final values = draft.toMap()
      ..remove('id')
      ..remove('clientId')
      ..remove('createdAt')
      ..['updatedAt'] = _timestamp();
    return database.update(
      _table,
      values,
      where: 'id = ? AND clientId = ?',
      whereArgs: [id, clientId],
    );
  }

  Future<int> deleteDraft(User client, int id) async {
    final clientId = _clientId(client);
    final database = await _open();
    return database.delete(
      _table,
      where: 'id = ? AND clientId = ?',
      whereArgs: [id, clientId],
    );
  }

  // Fixed millisecond precision keeps these UTC strings sortable in SQLite.
  String _timestamp() {
    return DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
  }
}
