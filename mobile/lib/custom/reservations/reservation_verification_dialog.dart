import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../models/vehicle.dart';
import '../../utils/app_theme.dart';
import '../../utils/reservation_date_range.dart';
import 'reservation_vehicle_photo.dart';

class ReservationVerificationDialog extends StatelessWidget {
  static const _ink = Color(0xFF102047);
  static const _muted = Color(0xFF5D6678);
  static const _border = Color(0xFFD9DFEA);

  final Vehicle vehicle;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;
  final String duration;
  final String estimatedTotal;

  const ReservationVerificationDialog({
    super.key,
    required this.vehicle,
    required this.pickupDate,
    required this.returnDate,
    required this.pickupLocation,
    required this.returnLocation,
    required this.duration,
    required this.estimatedTotal,
  });

  Widget _detail(String label, String value, {bool total = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: total ? _ink : _muted,
                  fontWeight: total ? FontWeight.w700 : FontWeight.w400,
                )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: total ? AppTheme.darkBlue : _ink,
                fontSize: total ? 19 : 14,
                fontWeight: total ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = '${vehicle.marque} ${vehicle.modele}';
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: const BoxConstraints(maxWidth: 360),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: const Text('Vérifier votre réservation',
          style: TextStyle(
              color: _ink, fontSize: 20, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: ReservationVehiclePhoto(
                    vehicleName: name,
                    image: vehicle.image,
                    height: 48,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: _ink, fontWeight: FontWeight.w700)),
                      Localizations.override(
                        context: context,
                        locale: const Locale('fr'),
                        delegates: GlobalMaterialLocalizations.delegates,
                        child: Builder(builder: (context) {
                          return Text(
                            formatReservationDateRange(
                              MaterialLocalizations.of(context),
                              pickupDate,
                              returnDate,
                            ),
                            style: const TextStyle(color: _muted, fontSize: 13),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: _border),
            _detail('Prise en charge', pickupLocation),
            _detail('Retour', returnLocation),
            _detail('Durée', duration),
            const Divider(height: 20, color: _border),
            _detail('Total estimé', estimatedTotal, total: true),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _border),
                  shape: shape,
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () {
                  // Ignore a second tap while this route is closing.
                  if (ModalRoute.of(context)?.isCurrent == true) {
                    Navigator.pop(context, true);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.blue,
                  foregroundColor: Colors.white,
                  shape: shape,
                  minimumSize: const Size(0, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                child: const Text('Confirmer la réservation',
                    textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
