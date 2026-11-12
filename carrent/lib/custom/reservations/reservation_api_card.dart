import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../utils/app_theme.dart';

class ReservationApiCard extends StatelessWidget {
  final Reservation reservation;

  const ReservationApiCard({super.key, required this.reservation});

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = reservation.status == 'confirmed' ? 'Confirmée' : 'Annulée';
    // One dinar contains 1000 millimes. Keep all three decimal places.
    final price = (reservation.totalPriceMillimes / 1000).toStringAsFixed(3);
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
              'API locale — développement',
              style: TextStyle(color: AppTheme.darkBlue),
            ),
            const SizedBox(height: 12),
            const Icon(
              Icons.directions_car_outlined,
              color: AppTheme.blue,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text('Réservation : ${reservation.id}'),
            const SizedBox(height: 8),
            Text('Véhicule (ID) : ${reservation.vehicleId}'),
            const SizedBox(height: 12),
            Text('Prise en charge : ${_formatDate(reservation.pickupDate)}'),
            Text('Retour : ${_formatDate(reservation.returnDate)}'),
            const SizedBox(height: 8),
            Text('Lieu de départ : ${reservation.pickupLocation}'),
            Text('Lieu de retour : ${reservation.returnLocation}'),
            const SizedBox(height: 12),
            Text(
              'Prix total : $price DT',
              style: const TextStyle(
                color: AppTheme.darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Statut : $status',
              style: const TextStyle(
                color: AppTheme.darkBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
