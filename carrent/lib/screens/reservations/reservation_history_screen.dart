import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../custom/reservations/reservation_card.dart';
import '../../utils/app_theme.dart';
import 'demo/reservation_history_demo_data.dart';
import 'reservation_history_api_screen.dart';

class ReservationHistoryScreen extends StatelessWidget {
  const ReservationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes Réservations')),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Données de démonstration',
                      style: TextStyle(
                        color: AppTheme.darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Exemples fixes, sans lien avec votre confirmation. '
                      'Aucune réservation n’a été enregistrée.',
                    ),
                  ],
                ),
              ),
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ReservationHistoryApiScreen(),
                        ),
                      );
                    },
                    child: const Text('Aperçu API — développement uniquement'),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: reservationHistoryDemoData.length,
                  itemBuilder: (context, index) {
                    final reservation = reservationHistoryDemoData[index];
                    return ReservationCard(
                      vehicleName: reservation['vehicleName'],
                      pickupDate: reservation['pickupDate'],
                      returnDate: reservation['returnDate'],
                      totalPrice: reservation['totalPrice'],
                      status: reservation['status'],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
