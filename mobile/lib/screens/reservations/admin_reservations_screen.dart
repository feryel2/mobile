import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../custom/reservations/admin_cancellation_dialog.dart';
import '../../custom/reservations/reservation_api_card.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../utils/app_theme.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() =>
      _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  late Future<List<Reservation>> _reservations;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reservations = ReservationService.getAdminReservations();
  }

  void _reload() {
    setState(() {
      _reservations = ReservationService.getAdminReservations();
    });
  }

  Future<void> _cancel(Reservation reservation) async {
    final cancelled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminCancellationDialog(
        reservationId: reservation.id,
        onConflict: _reload,
      ),
    );
    if (!mounted || cancelled != true) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réservation annulée avec succès.')),
    );
  }

  Widget _filter(String label, String? status) {
    return ChoiceChip(
      label: Text(label),
      selected: _status == status,
      selectedColor: const Color(0xFFEAF1FC),
      onSelected: (_) {
        setState(() {
          _status = status;
        });
      },
    );
  }

  Widget _results(AsyncSnapshot<List<Reservation>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      final denied = snapshot.error is AdminReservationAccessException;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                denied
                    ? 'Accès administrateur requis.'
                    : 'Impossible de charger les réservations.',
                textAlign: TextAlign.center,
              ),
              if (denied)
                const Text(
                  'Reconnectez-vous avec un compte administrateur.',
                  textAlign: TextAlign.center,
                )
              else
                TextButton(onPressed: _reload, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final reservations = snapshot.data ?? [];
    final visible = reservations
        .where((item) => _status == null || item.status == _status)
        .toList();
    if (visible.isEmpty) {
      return Center(
        child: Text(
          reservations.isEmpty
              ? 'Aucune réservation trouvée.'
              : 'Aucune réservation ne correspond à ce filtre.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      key: ValueKey(_status),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final reservation = visible[index];
        return ReservationApiCard(
          key: ValueKey(reservation.id),
          reservation: reservation,
          showAdminDetails: true,
          onCancel: reservation.status == 'confirmed'
              ? () => _cancel(reservation)
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF6F8FC),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Gestion des réservations',
                          style: TextStyle(
                            color: AppTheme.darkBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualiser les réservations',
                        onPressed: _reload,
                        icon:
                            const Icon(Icons.refresh, color: AppTheme.darkBlue),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      _filter('Toutes', null),
                      _filter('Confirmées', 'confirmed'),
                      _filter('Annulées', 'cancelled'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Localizations.override(
                      context: context,
                      locale: const Locale('fr'),
                      delegates: GlobalMaterialLocalizations.delegates,
                      child: FutureBuilder<List<Reservation>>(
                        future: _reservations,
                        builder: (context, snapshot) => _results(snapshot),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
