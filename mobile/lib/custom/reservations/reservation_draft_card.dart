import 'package:flutter/material.dart';

import '../../models/reservation_draft.dart';
import '../../utils/app_theme.dart';
import '../../utils/reservation_date_range.dart';
import 'reservation_vehicle_photo.dart';

class ReservationDraftCard extends StatelessWidget {
  final ReservationDraft draft;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;

  const ReservationDraftCard({
    super.key,
    required this.draft,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF102047);
    const muted = Color(0xFF5D6678);
    const red = Color(0xFF9D3333);
    final dates = formatReservationDateRange(
      MaterialLocalizations.of(context),
      draft.pickupDate,
      draft.returnDate,
    );
    final total = draft.estimatedTotalMillimes;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x24102047),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E7F1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: ReservationVehiclePhoto(
                    vehicleName: draft.vehicleName,
                    image: draft.vehicleImage,
                    height: 78,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.vehicleName,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Brouillon',
                          style: TextStyle(
                            color: AppTheme.darkBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(dates, style: const TextStyle(color: ink)),
                      const SizedBox(height: 4),
                      Text(
                        'Prise en charge · ${draft.pickupLocation}',
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                      Text(
                        'Retour · ${draft.returnLocation}',
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFE1E7F1)),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  total == null
                      ? 'Total estimé indisponible'
                      : 'Total estimé · ${ReservationDraft.formatMillimes(total)}',
                  style: const TextStyle(
                    color: AppTheme.darkBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: onResume,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.blue,
                        side: const BorderSide(color: AppTheme.blue),
                      ),
                      child: const Text('Reprendre'),
                    ),
                    OutlinedButton(
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: red,
                        side: const BorderSide(color: red),
                      ),
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
