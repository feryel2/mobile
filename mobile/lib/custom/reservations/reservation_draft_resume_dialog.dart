import 'package:flutter/material.dart';

import '../../models/reservation_draft.dart';
import '../../utils/app_theme.dart';
import '../../utils/reservation_date_range.dart';
import 'reservation_vehicle_photo.dart';

class ReservationDraftResumeDialog extends StatelessWidget {
  final ReservationDraft draft;

  const ReservationDraftResumeDialog({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF102047);
    const muted = Color(0xFF5D6678);
    final dates = formatReservationDateRange(
      MaterialLocalizations.of(context),
      draft.pickupDate,
      draft.returnDate,
    );
    final total = draft.estimatedTotalMillimes;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      constraints: const BoxConstraints(maxWidth: 360),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Reprendre ce brouillon ?',
        style: TextStyle(color: ink, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                child: ReservationVehiclePhoto(
                  vehicleName: draft.vehicleName,
                  image: draft.vehicleImage,
                  height: 56,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.vehicleName,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(dates, style: const TextStyle(color: muted)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE1E7F1)),
          Text(
            'Prise en charge : ${draft.pickupLocation}',
            style: const TextStyle(color: ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Retour : ${draft.returnLocation}',
            style: const TextStyle(color: ink),
          ),
          const SizedBox(height: 10),
          Text(
            total == null
                ? 'Total estimé indisponible'
                : 'Total estimé · ${ReservationDraft.formatMillimes(total)}',
            style: const TextStyle(
              color: AppTheme.darkBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Vous allez reprendre ce brouillon pour modifier votre réservation.',
              style: TextStyle(color: ink, fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.blue),
          child: const Text('Reprendre'),
        ),
      ],
    );
  }
}
