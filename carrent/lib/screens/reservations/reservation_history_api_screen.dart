import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../custom/reservations/reservation_api_card.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../utils/api_config.dart';
import '../../utils/app_theme.dart';

class ReservationHistoryApiScreen extends StatefulWidget {
  // Tests can provide a predictable result without contacting a real server.
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
    // Start once when the screen opens, rather than on every build.
    if (kDebugMode) {
      _reservationsFuture =
          widget.reservationsFuture ??
          ReservationService.getClientReservations(
            ApiConfig.developmentClientId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique API — développement')),
      backgroundColor: Colors.white,
      body: !kDebugMode
          ? const Center(child: Text('Aperçu réservé au développement.'))
          : SafeArea(
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
                          'DÉVELOPPEMENT UNIQUEMENT',
                          style: TextStyle(
                            color: AppTheme.darkBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Client de test : ${ApiConfig.developmentClientId}',
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aucun utilisateur connecté. Résultats de l’API locale, '
                          'séparés des exemples fixes. Lecture seule.',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Reservation>>(
                      future: _reservationsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Impossible de charger les réservations.\n${snapshot.error}',
                            ),
                          );
                        }
                        final reservations = snapshot.data ?? [];
                        if (reservations.isEmpty) {
                          return const Center(
                            child: Text('Aucune réservation trouvée'),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: reservations.length,
                          itemBuilder: (context, index) {
                            return ReservationApiCard(
                              reservation: reservations[index],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
