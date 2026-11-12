import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../custom/reservations/reservation_api_card.dart';

class ReservationHistoryApiScreen extends StatefulWidget {
  final Future<List<Reservation>>? reservationsFuture;

  const ReservationHistoryApiScreen({super.key, this.reservationsFuture});

  @override
  State<ReservationHistoryApiScreen> createState() =>
      _ReservationHistoryApiScreenState();
}

class _ReservationHistoryApiScreenState
    extends State<ReservationHistoryApiScreen> {
  late Future<List<Reservation>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture =
        widget.reservationsFuture ?? ReservationService.getMyReservations();
  }

  void _reload() {
    setState(() {
      _reservationsFuture = ReservationService.getMyReservations();
    });
  }

  Future<void> _cancel(Reservation reservation) async {
    try {
      await ReservationService.cancel(reservation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation annulée.')),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      body: FutureBuilder<List<Reservation>>(
        future: _reservationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Impossible de charger les réservations.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final reservations = snapshot.data ?? [];
          if (reservations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune réservation pour le moment.'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reservations.length,
              itemBuilder: (context, index) {
                final reservation = reservations[index];
                return ReservationApiCard(
                  reservation: reservation,
                  onCancel: reservation.status == 'confirmed'
                      ? () => _cancel(reservation)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
