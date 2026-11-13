import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carrent_client/database/helper.dart';
import 'package:carrent_client/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('version 1 database upgrades and persists credential-free user caches',
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

      final secondClient = User(
        id: 'user-2',
        fullname: 'Sam Lee',
        email: 'sam@example.com',
        phone: '+33123456789',
        createdAt: DateTime.utc(2024, 3, 1),
      );
      final admin = User(
        id: 'admin-1',
        fullname: 'Admin',
        email: 'admin@example.com',
        phone: '+33123456780',
        role: 'admin',
      );
      await DatabaseHelper.instance
          .cacheAdminClients([user, secondClient, admin]);
      final cachedClients =
          await DatabaseHelper.instance.getCachedAdminClients();

      expect(cachedClients?.map((client) => client.id), ['user-2', 'user-1']);
      final cachedRows = await database.query('admin_clients_cache');
      expect(cachedRows.every((row) => !row.containsKey('password')), isTrue);

      await DatabaseHelper.instance.cacheAdminClients([secondClient]);
      expect(
        (await DatabaseHelper.instance.getCachedAdminClients())
            ?.map((client) => client.id),
        ['user-2'],
      );
      await DatabaseHelper.instance.upsertCachedAdminClient(
        secondClient.copyWith(fullname: 'Sam Updated'),
      );
      expect(
        (await DatabaseHelper.instance.getCachedAdminClients())
            ?.single
            .fullname,
        'Sam Updated',
      );
      await DatabaseHelper.instance.removeCachedAdminClient(secondClient.id);
      expect(
        await DatabaseHelper.instance.getCachedAdminClients(),
        isEmpty,
      );
      await DatabaseHelper.instance.cacheAdminClients([]);
      expect(await DatabaseHelper.instance.getCachedAdminClients(), isEmpty);
      await DatabaseHelper.instance.clearCachedAdminClients();
      expect(await DatabaseHelper.instance.getCachedAdminClients(), isNull);

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
