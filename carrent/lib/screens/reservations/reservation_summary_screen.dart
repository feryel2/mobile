import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import 'reservation_confirmation_demo_screen.dart';

class ReservationSummaryScreen extends StatelessWidget {
  final String vehicleName;
  final String vehicleCategory;
  final int dailyPrice;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;

  const ReservationSummaryScreen({
    super.key,
    required this.vehicleName,
    required this.vehicleCategory,
    required this.dailyPrice,
    required this.pickupDate,
    required this.returnDate,
    required this.pickupLocation,
    required this.returnLocation,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void _showConfirmationDialog(BuildContext context, int estimatedTotal) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          scrollable: true,
          title: const Text('Confirmer la réservation (démo)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicleName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Prise en charge : ${_formatDate(pickupDate)}'),
              const SizedBox(height: 8),
              Text('Retour : ${_formatDate(returnDate)}'),
              const SizedBox(height: 12),
              Text(
                'Total estimé (démo) : $estimatedTotal DT',
                style: const TextStyle(
                  color: AppTheme.darkBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ceci est une démonstration. '
                'Aucune réservation ne sera enregistrée.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              // Dialog buttons need a compact width instead of a full-width one.
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ReservationConfirmationDemoScreen(),
                  ),
                );
              },
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Count calendar days only. UTC avoids errors caused by clock changes.
    final pickupDay = DateTime.utc(
      pickupDate.year,
      pickupDate.month,
      pickupDate.day,
    );
    final returnDay = DateTime.utc(
      returnDate.year,
      returnDate.month,
      returnDate.day,
    );
    final Duration rentalDuration = returnDay.difference(pickupDay);
    final int rentalDays = rentalDuration.inDays;

    // The search form already checks dates; also protect this screen directly.
    if (rentalDays <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résumé de la réservation')),
        body: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: const Text(
            'La date de retour doit être après la date de prise en charge.',
          ),
        ),
      );
    }

    final int estimatedTotal = rentalDays * dailyPrice;

    return Scaffold(
      appBar: AppBar(title: const Text('Résumé de la réservation')),
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
                    const Text(
                      'Données de démonstration',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFFF6F8FC),
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.directions_car_outlined,
                              color: AppTheme.blue,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              vehicleName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(vehicleCategory),
                            const SizedBox(height: 12),
                            Text(
                              '$dailyPrice DT / jour',
                              style: const TextStyle(
                                color: AppTheme.darkBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Détails de la location',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Prise en charge : ${_formatDate(pickupDate)}'),
                    const SizedBox(height: 12),
                    Text('Retour : ${_formatDate(returnDate)}'),
                    const SizedBox(height: 12),
                    Text('Lieu de prise en charge : $pickupLocation'),
                    const SizedBox(height: 12),
                    Text(
                      'Durée : $rentalDays ${rentalDays == 1 ? 'jour' : 'jours'}',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prix total estimé (démonstration)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$estimatedTotal DT',
                            key: const Key('estimatedTotal'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('$rentalDays × $dailyPrice DT'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Disponibilité non vérifiée. '
                      'Aucune réservation enregistrée.',
                      style: TextStyle(color: Color(0xFF5D6678)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      key: const Key('confirmDemoReservation'),
                      onPressed: () {
                        _showConfirmationDialog(context, estimatedTotal);
                      },
                      child: const Text(
                        'Confirmer la réservation (démo)',
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
