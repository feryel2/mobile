import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../models/reservation_draft.dart';
import '../../utils/app_theme.dart';
import '../../utils/reservation_date_range.dart';
import 'reservation_vehicle_photo.dart';

class ReservationApiCard extends StatelessWidget {
  static const _ink = Color(0xFF102047);
  static const _muted = Color(0xFF5D6678);
  static const _border = Color(0xFFD9DFEA);

  final Reservation reservation;
  final VoidCallback? onCancel;
  final bool isCancelling;
  final bool showAdminDetails;

  const ReservationApiCard({
    super.key,
    required this.reservation,
    this.onCancel,
    this.isCancelling = false,
    this.showAdminDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        reservation.vehicleName.isEmpty ? 'Véhicule' : reservation.vehicleName;
    final dates = formatReservationDateRange(MaterialLocalizations.of(context),
        reservation.pickupDate, reservation.returnDate);
    final confirmed = reservation.status == 'confirmed';
    final statusColor =
        confirmed ? const Color(0xFF126044) : const Color(0xFFA62834);

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: const Color(0x18102047),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 94,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: ColoredBox(
                      color: const Color(0xFFF6F8FC),
                      child: ReservationVehiclePhoto(
                        vehicleName: name,
                        image: reservation.image,
                        height: 92,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(dates,
                              style:
                                  const TextStyle(color: _muted, fontSize: 12)),
                          Text(
                            ReservationDraft.formatMillimes(
                                reservation.totalPriceMillimes),
                            style: const TextStyle(
                                color: _ink, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          confirmed
                              ? 'Confirmée'
                              : reservation.cancelledByAdmin
                                  ? 'Annulée par l’administration'
                                  : 'Annulée',
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (reservation.registration.isNotEmpty)
                        Text(reservation.registration,
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                      Text('Prise en charge · ${reservation.pickupLocation}',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                      Text('Retour · ${reservation.returnLocation}',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (showAdminDetails) ...[
              const Divider(),
              if (reservation.clientName.isNotEmpty)
                Text('Client · ${reservation.clientName}',
                    style: const TextStyle(
                        color: _ink, fontWeight: FontWeight.w600)),
              Text('Réf. · ${reservation.id}',
                  style: const TextStyle(color: _muted, fontSize: 12)),
            ],
            if (reservation.cancelledByAdmin &&
                (reservation.cancellationReason?.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Motif : ${reservation.cancellationReason}',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            if (confirmed && (!showAdminDetails || onCancel != null))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: showAdminDetails
                        ? const Color(0xFFA62834)
                        : AppTheme.darkBlue,
                    backgroundColor: showAdminDetails
                        ? const Color(0xFFFCEFF0)
                        : const Color(0xFFEAF1FC),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: isCancelling
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(isCancelling
                      ? 'Annulation en cours…'
                      : 'Annuler la réservation'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
