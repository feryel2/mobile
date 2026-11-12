import 'package:flutter/material.dart';

import '../../models/reservation.dart';

class ReservationApiCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onCancel;

  const ReservationApiCard({
    super.key,
    required this.reservation,
    this.onCancel,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = reservation.status == 'confirmed';
    final price = (reservation.totalPriceMillimes / 1000).toStringAsFixed(3);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reservation.vehicleName.isEmpty
                  ? 'Véhicule'
                  : reservation.vehicleName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (reservation.registration.isNotEmpty)
              Text(reservation.registration),
            const SizedBox(height: 8),
            Text(
              '${_formatDate(reservation.pickupDate)} – '
              '${_formatDate(reservation.returnDate)}',
            ),
            Text('Départ : ${reservation.pickupLocation}'),
            Text('Retour : ${reservation.returnLocation}'),
            const SizedBox(height: 8),
            Text('$price DT'),
            Text(isConfirmed ? 'Confirmée' : 'Annulée'),
            if (onCancel != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Annuler'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
