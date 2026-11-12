import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_client/models/user_model.dart';
import 'package:carrent_client/screens/profile_screen.dart';
import 'package:carrent_client/services/user_service.dart';

class FakeUserService extends UserService {
  FakeUserService(this.user);

  User user;
  String? sentEmail;
  String? changedEmail;

  @override
  Future<Map<String, dynamic>> getProfile() async =>
      {'success': true, 'user': user};

  @override
  Future<Map<String, dynamic>> sendEmailVerificationCode({
    required String email,
  }) async {
    sentEmail = email;
    return {
      'success': true,
      'message': 'Code envoyé.',
      'resendAfterSeconds': 0,
    };
  }

  @override
  Future<Map<String, dynamic>> changeEmail({
    required String email,
    required String code,
  }) async {
    changedEmail = email;
    user = user.copyWith(email: email);
    return {'success': true, 'user': user};
  }
}

void main() {
  testWidgets('profile email changes only through the verification flow',
      (WidgetTester tester) async {
    final service = FakeUserService(
      User(
        id: 'user-1',
        fullname: 'Alex Martin',
        email: 'alex@example.com',
        phone: '+33123456789',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(userService: service)),
    );
    await tester.pumpAndSettle();

    final editEmailButton = find.byTooltip('Modifier l’adresse email');
    await tester.ensureVisible(editEmailButton);
    await tester.tap(editEmailButton);
    await tester.pumpAndSettle();

    final newEmailField =
        find.widgetWithText(TextFormField, 'Nouvelle adresse email');
    await tester.enterText(newEmailField, 'new@example.com');
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(find.text('Code reçu par email'), findsOneWidget);
    final codeField = find.widgetWithText(TextFormField, 'Code reçu par email');
    await tester.enterText(codeField, '123456');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(service.sentEmail, 'new@example.com');
    expect(service.changedEmail, 'new@example.com');
    expect(find.text('new@example.com'), findsWidgets);
  });
}
