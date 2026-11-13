import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_client/main.dart';
import 'package:carrent_client/screens/auth_screen.dart';

void main() {
  testWidgets('CarRentApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CarRentApp(isAuth: false));
    expect(find.byType(CarRentApp), findsOneWidget);
  });

  testWidgets('signup keeps email verification in the same form',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CarRentApp(isAuth: false));
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(find.byType(Form), findsOneWidget);
    expect(find.text('Nom complet'), findsOneWidget);
    expect(find.text('Adresse Email'), findsOneWidget);
    expect(find.text('Code de vérification email'), findsOneWidget);
    expect(find.text('Numéro de téléphone'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Accéder à l’espace administrateur'), findsOneWidget);
  });

  testWidgets('forgot password opens the email code reset flow',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    final forgotPassword = find.text('Mot de passe oublié ?');
    await tester.ensureVisible(forgotPassword);
    await tester.tap(forgotPassword);
    await tester.pumpAndSettle();

    expect(find.text('Réinitialiser le mot de passe'), findsOneWidget);
    expect(find.text('Envoyer le code'), findsOneWidget);
  });
}
