import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../services/reservation_service.dart';

class ReservationSummaryScreen extends StatefulWidget {
  final Vehicle vehicle;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;

  const ReservationSummaryScreen({
    super.key,
    required this.vehicle,
    required this.pickupDate,
    required this.returnDate,
    required this.pickupLocation,
    required this.returnLocation,
  });

  @override
  State<ReservationSummaryScreen> createState() =>
      _ReservationSummaryScreenState();
}

class _ReservationSummaryScreenState extends State<ReservationSummaryScreen> {
  bool _isSaving = false;

  int get _rentalDays {
    final pickup = DateTime.utc(
      widget.pickupDate.year,
      widget.pickupDate.month,
      widget.pickupDate.day,
    );
    final end = DateTime.utc(
      widget.returnDate.year,
      widget.returnDate.month,
      widget.returnDate.day,
    );
    return end.difference(pickup).inDays;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _confirmReservation() async {
    setState(() => _isSaving = true);
    try {
      final reservation = await ReservationService.create(
        vehicleId: widget.vehicle.id!,
        pickupDate: widget.pickupDate,
        returnDate: widget.returnDate,
        pickupLocation: widget.pickupLocation,
        returnLocation: widget.returnLocation,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Réservation confirmée'),
          content: Text(
            'Votre réservation de ${widget.vehicle.marque} '
            '${widget.vehicle.modele} est enregistrée.\n'
            'Référence : ${reservation.id}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Terminé'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final total = _rentalDays * vehicle.prix;

    return Scaffold(
      appBar: AppBar(title: const Text('Résumé de la réservation')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.directions_car, size: 40),
              title: Text('${vehicle.marque} ${vehicle.modele}'),
              subtitle: Text('${vehicle.carburant} • ${vehicle.annee}'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Départ : ${_formatDate(widget.pickupDate)}'),
          const SizedBox(height: 8),
          Text('Retour : ${_formatDate(widget.returnDate)}'),
          const SizedBox(height: 8),
          Text('Lieu de départ : ${widget.pickupLocation}'),
          const SizedBox(height: 8),
          Text('Lieu de retour : ${widget.returnLocation}'),
          const SizedBox(height: 16),
          Text('Durée : $_rentalDays jour(s)'),
          const SizedBox(height: 8),
          Text('${vehicle.prix.toStringAsFixed(2)} DT / jour'),
          const SizedBox(height: 8),
          Text(
            'Total estimé : ${total.toStringAsFixed(2)} DT',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _confirmReservation,
            child: Text(
              _isSaving ? 'Enregistrement...' : 'Confirmer la réservation',
            ),
          ),
        ],
      ),
    );
  }
}
