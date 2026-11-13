import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carrent_client/database/helper.dart';
import 'package:carrent_client/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('version 1 database upgrades and persists a credential-free profile',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final path = join(await getDatabasesPath(), 'carrent.db');
    await deleteDatabase(path);
    final oldDatabase = await openDatabase(
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
        await db.insert('vehicles', {
          'marque': 'Toyota',
          'modele': 'Yaris',
          'immatriculation': 'TEST-001',
          'annee': 2022,
          'prix': 120,
          'kilometrage': 10000,
          'carburant': 'Essence',
          'disponible': 1,
        });
      },
    );
    await oldDatabase.close();

    final database = await DatabaseHelper.instance.database;
    try {
      final vehicle = await database.query('vehicles');
      expect(vehicle, hasLength(1));
      expect(vehicle.single['immatriculation'], 'TEST-001');

      final user = User(
        id: 'user-1',
        fullname: 'Alex Martin',
        email: 'alex@example.com',
        phone: '+33123456789',
      );
      await DatabaseHelper.instance.cacheUserProfile(user);
      final cachedUser =
          await DatabaseHelper.instance.getCachedUserProfile(user.id);
      final row = await database.query(
        'user_profiles',
        where: 'id = ?',
        whereArgs: [user.id],
      );

      expect(cachedUser?.toJson(), user.toJson());
      expect(row.single.containsKey('password'), isFalse);

      await DatabaseHelper.instance.deleteCachedUserProfile(user.id);
      expect(
        await DatabaseHelper.instance.getCachedUserProfile(user.id),
        isNull,
      );
    } finally {
      await database.close();
    }
  });
}
