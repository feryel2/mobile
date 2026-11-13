import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/vehicle.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'carrent.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vehicles (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            mongo_id TEXT,
            sync_status TEXT NOT NULL DEFAULT 'synced',
            marque TEXT NOT NULL,
            modele TEXT NOT NULL,
            immatriculation TEXT NOT NULL,
            annee INTEGER NOT NULL,
            prix REAL NOT NULL,
            kilometrage INTEGER NOT NULL,
            carburant TEXT NOT NULL,
            disponible INTEGER NOT NULL,
            image TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_mongo_id ON vehicles(mongo_id)');
        await _createUserProfilesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createUserProfilesTable(db);
        }
      },
    );
  }

  Future<void> _createUserProfilesTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_profiles (
        id TEXT PRIMARY KEY NOT NULL,
        fullname TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        avatar TEXT NOT NULL DEFAULT '',
        driver_license_number TEXT NOT NULL DEFAULT '',
        driver_license_issued_date TEXT,
        driver_license_photo_url TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> cacheUserProfile(User user) async {
    final db = await database;
    await db.insert(
      'user_profiles',
      user.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<User?> getCachedUserProfile(String userId) async {
    final db = await database;
    final rows = await db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromDatabaseMap(rows.first);
  }

  Future<void> deleteCachedUserProfile(String userId) async {
    final db = await database;
    await db.delete('user_profiles', where: 'id = ?', whereArgs: [userId]);
  }

  /// Véhicules affichés (on masque ceux supprimés hors ligne).
  Future<List<Vehicle>> getAll() async {
    final db = await database;
    final rows = await db.query(
      'vehicles',
      where: "sync_status != 'pending_delete'",
      orderBy: 'local_id DESC',
    );
    return rows.map(Vehicle.fromMap).toList();
  }

  /// Modifications en attente d'envoi au serveur.
  Future<List<Vehicle>> getPending() async {
    final db = await database;
    final rows = await db.query(
      'vehicles',
      where: "sync_status != 'synced'",
      orderBy: 'local_id ASC',
    );
    return rows.map(Vehicle.fromMap).toList();
  }

  Future<int> insert(Vehicle v) async {
    final db = await database;
    return db.insert('vehicles', v.toMap());
  }

  Future<void> update(Vehicle v) async {
    final db = await database;
    await db.update('vehicles', v.toMap(),
        where: 'local_id = ?', whereArgs: [v.localId]);
  }

  Future<void> delete(int localId) async {
    final db = await database;
    await db.delete('vehicles', where: 'local_id = ?', whereArgs: [localId]);
  }

  /// Met à jour le cache avec les données du serveur
  /// sans écraser les modifications locales en attente.
  Future<void> cacheRemote(List<Vehicle> remote) async {
    final db = await database;
    await db.transaction((txn) async {
      final remoteIds = remote.map((v) => v.id).whereType<String>().toSet();

      // Supprime les lignes synchronisées qui n'existent plus sur le serveur
      final synced = await txn.query('vehicles',
          where: "sync_status = 'synced' AND mongo_id IS NOT NULL");
      for (final row in synced) {
        if (!remoteIds.contains(row['mongo_id'])) {
          await txn.delete('vehicles',
              where: 'local_id = ?', whereArgs: [row['local_id']]);
        }
      }

      for (final v in remote) {
        final existing = await txn.query('vehicles',
            where: 'mongo_id = ?', whereArgs: [v.id], limit: 1);

        if (existing.isEmpty) {
          await txn.insert(
              'vehicles', v.copyWith(syncStatus: 'synced').toMap());
        } else if (existing.first['sync_status'] == 'synced') {
          final localId = existing.first['local_id'] as int;
          await txn.update(
            'vehicles',
            v.copyWith(localId: localId, syncStatus: 'synced').toMap(),
            where: 'local_id = ?',
            whereArgs: [localId],
          );
        }
        // sinon : modification locale en attente, on ne l'écrase pas
      }
    });
  }
}
