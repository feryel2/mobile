import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import 'reservation_history_screen.dart';

class ReservationConfirmationDemoScreen extends StatelessWidget {
  const ReservationConfirmationDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation (démo)')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.blue,
                      size: 72,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Démonstration de confirmation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.darkBlue,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Ceci est une démonstration. '
                        'Aucune réservation n’a été enregistrée.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Votre voiture n’est pas réservée.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF5D6678)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'La liste suivante contient uniquement des exemples fixes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF5D6678)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ReservationHistoryScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Voir les réservations (démo)',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
