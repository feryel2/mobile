import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/reservations/reservation_search_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const CarRentApp());
}

class CarRentApp extends StatelessWidget {
  const CarRentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarRent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const ReservationSearchScreen(),
    );
  }
}
