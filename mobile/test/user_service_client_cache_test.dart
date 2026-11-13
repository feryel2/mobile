import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carrent_client/database/helper.dart';
import 'package:carrent_client/services/user_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads all client pages, caches them and falls back when offline',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues(
        {'jwt_carrent_token': 'admin-token'});

    final databasePath = join(await getDatabasesPath(), 'carrent.db');
    await deleteDatabase(databasePath);

    var shouldFail = false;
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer admin-token');
      expect(request.url.queryParameters['limit'], '100');
      if (shouldFail) throw const SocketException('offline');

      final page = request.url.queryParameters['page'];
      final users = page == '1'
          ? [
              {
                '_id': 'client-1',
                'fullname': 'Alex Martin',
                'email': 'alex@example.com',
                'phone': '+33123456789',
                'role': 'client',
                'status': 'active',
                'createdAt': '2024-02-01T00:00:00.000Z',
              }
            ]
          : [
              {
                '_id': 'client-2',
                'fullname': 'Sam Lee',
                'email': 'sam@example.com',
                'phone': '+33123456780',
                'role': 'client',
                'status': 'suspended',
                'createdAt': '2024-01-01T00:00:00.000Z',
              }
            ];
      return http.Response(
        jsonEncode({
          'success': true,
          'data': users,
          'pagination': {'totalPages': 2},
        }),
        200,
      );
    });

    final service = UserService(httpClient: client);
    try {
      final onlineResult = await service.getAllUsers();
      expect(onlineResult['success'], isTrue);
      expect((onlineResult['users'] as List).length, 2);

      shouldFail = true;
      final offlineResult = await service.getAllUsers();
      expect(offlineResult['success'], isTrue);
      expect(offlineResult['offline'], isTrue);
      expect((offlineResult['users'] as List).length, 2);

      final cachedRows = await (await DatabaseHelper.instance.database)
          .query('admin_clients_cache');
      expect(cachedRows.length, 2);
      expect(cachedRows.every((row) => !row.containsKey('password')), isTrue);
    } finally {
      client.close();
      debugDefaultTargetPlatformOverride = null;
      await (await DatabaseHelper.instance.database).close();
    }
  });
}
