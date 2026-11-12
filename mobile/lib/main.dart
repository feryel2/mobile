import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isAuth = await UserService.isAuthenticated();
  runApp(CarRentApp(isAuth: isAuth));
}

class CarRentApp extends StatelessWidget {
  final bool isAuth;
  const CarRentApp({super.key, required this.isAuth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarRent - Location de Voitures',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0052CC),
          primary: const Color(0xFF0052CC),
          secondary: const Color(0xFF28A745),
          error: const Color(0xFFDC3545),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0052CC),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: isAuth ? const ProfileScreen() : const AuthScreen(),
    );
  }
}
