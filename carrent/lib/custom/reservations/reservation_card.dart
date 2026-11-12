import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

class ReservationCard extends StatelessWidget {
  final String vehicleName;
  final DateTime pickupDate;
  final DateTime returnDate;
  final int totalPrice;
  final String status;

  const ReservationCard({
    super.key,
    required this.vehicleName,
    required this.pickupDate,
    required this.returnDate,
    required this.totalPrice,
    required this.status,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD9DFEA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Réservation de démonstration',
              style: TextStyle(color: AppTheme.darkBlue, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  color: AppTheme.blue,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    vehicleName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Prise en charge : ${_formatDate(pickupDate)}'),
            const SizedBox(height: 8),
            Text('Retour : ${_formatDate(returnDate)}'),
            const SizedBox(height: 12),
            Text(
              'Prix total : $totalPrice DT',
              style: const TextStyle(
                color: AppTheme.darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Statut : $status',
                style: const TextStyle(
                  color: AppTheme.darkBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
