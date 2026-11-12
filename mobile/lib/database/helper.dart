import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
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
      version: 1,
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
      },
    );
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
          await txn.insert('vehicles', v.copyWith(syncStatus: 'synced').toMap());
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