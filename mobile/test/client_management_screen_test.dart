import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_client/models/user_model.dart';
import 'package:carrent_client/screens/client_management_screen.dart';
import 'package:carrent_client/services/user_service.dart';

class FakeUserService extends UserService {
  FakeUserService(this.users, {this.offline = false});

  final List<User> users;
  final bool offline;
  Map<String, String>? updatedClient;
  var createCalls = 0;

  @override
  Future<Map<String, dynamic>> getAllUsers() async => {
        'success': true,
        'users': users,
        if (offline) 'offline': true,
      };

  @override
  Future<Map<String, dynamic>> updateClient({
    required String userId,
    required String fullname,
    required String phone,
    required String driverLicenseNumber,
  }) async {
    updatedClient = {
      'id': userId,
      'fullname': fullname,
      'phone': phone,
      'driverLicenseNumber': driverLicenseNumber,
    };
    return {'success': true, 'message': 'Client mis à jour.'};
  }

  @override
  Future<Map<String, dynamic>> createClient({
    required String fullname,
    required String email,
    required String password,
    required String phone,
    String? driverLicenseNumber,
  }) async {
    createCalls++;
    return {'success': true};
  }
}

void main() {
  final client = User(
    id: 'client-1',
    fullname: 'Alex Martin',
    email: 'alex@example.com',
    phone: '+33123456789',
    driverLicense: DriverLicense(number: 'DL-123'),
  );

  testWidgets('client form rejects invalid values before calling the service',
      (WidgetTester tester) async {
    final service = FakeUserService([client]);
    await tester.pumpWidget(
      MaterialApp(home: ClientManagementScreen(userService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouveau client'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('client-fullname')),
      'A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-email')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-password')),
      '12345',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-phone')),
      '123456abc',
    );
    await tester.tap(find.byKey(const ValueKey('client-form-submit')));
    await tester.pumpAndSettle();

    expect(
        find.text('Saisissez un nom d’au moins 2 caractères.'), findsOneWidget);
    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(find.text('Le mot de passe doit contenir au moins 6 caractères.'),
        findsOneWidget);
    expect(find.text('Saisissez un numéro contenant 7 à 15 chiffres.'),
        findsOneWidget);
    expect(service.createCalls, 0);
  });

  testWidgets('admin can edit client fields without changing the email',
      (WidgetTester tester) async {
    final service = FakeUserService([client]);
    await tester.pumpWidget(
      MaterialApp(home: ClientManagementScreen(userService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Martin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier le client'));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('client-email')),
        matching: find.byType(TextField),
      ),
    );
    expect(emailField.readOnly, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('client-fullname')),
      'Alex Martin Updated',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-phone')),
      '+33198765432',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-license')),
      'DL-456',
    );
    await tester.tap(find.byKey(const ValueKey('client-form-submit')));
    await tester.pumpAndSettle();

    expect(service.updatedClient, {
      'id': 'client-1',
      'fullname': 'Alex Martin Updated',
      'phone': '+33198765432',
      'driverLicenseNumber': 'DL-456',
    });
  });

  testWidgets('offline cached client list disables write actions',
      (WidgetTester tester) async {
    final service = FakeUserService([client], offline: true);
    await tester.pumpWidget(
      MaterialApp(home: ClientManagementScreen(userService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Mode hors ligne'), findsOneWidget);
    final addButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(addButton.onPressed, isNull);

    await tester.tap(find.text('Alex Martin'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Modifier le client'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Suspendre'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Supprimer'))
          .onPressed,
      isNull,
    );
  });
}
