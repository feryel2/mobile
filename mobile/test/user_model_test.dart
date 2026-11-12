import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_client/models/user_model.dart';

void main() {
  test('SQLite profile mapping preserves fields without storing credentials',
      () {
    final user = User(
      id: 'user-1',
      fullname: 'Alex Martin',
      email: 'alex@example.com',
      phone: '+33123456789',
      avatar: 'avatar.png',
      driverLicense: DriverLicense(
        number: 'DL-123',
        issuedDate: DateTime.utc(2021, 4, 12),
        photoUrl: 'license.png',
      ),
      role: 'client',
      status: 'active',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 2, 1),
    );

    final row = user.toDatabaseMap();
    final restored = User.fromDatabaseMap(row);

    expect(row.containsKey('password'), isFalse);
    expect(restored.toJson(), user.toJson());
    expect(restored.createdAt, user.createdAt);
    expect(restored.updatedAt, user.updatedAt);
  });
}
