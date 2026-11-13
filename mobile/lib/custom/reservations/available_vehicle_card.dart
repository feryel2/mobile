import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../utils/app_theme.dart';
import 'reservation_vehicle_photo.dart';

class AvailableVehicleCard extends StatelessWidget {
  static const _ink = Color(0xFF102047);
  static const _muted = Color(0xFF5D6678);

  final Vehicle vehicle;
  final bool isDraftVehicle;
  final VoidCallback? onSelect;

  const AvailableVehicleCard({
    super.key,
    required this.vehicle,
    this.isDraftVehicle = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final name = '${vehicle.marque} ${vehicle.modele}';
    final id = vehicle.id;
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: const Color(0x18102047),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD9DFEA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReservationVehiclePhoto(
              vehicleName: name,
              image: vehicle.image,
              height: 116,
            ),
            const SizedBox(height: 6),
            if (isDraftVehicle)
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  'Véhicule du brouillon',
                  style: TextStyle(
                    color: AppTheme.darkBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${vehicle.carburant} · ${vehicle.annee}',
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${vehicle.prix.toStringAsFixed(3)} DT',
                          style: const TextStyle(
                            color: AppTheme.blue,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: ' / jour',
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            if (id != null && id.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Réf. véhicule : $id',
                  style: const TextStyle(color: _muted, fontSize: 11)),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Choisir cette voiture'),
            ),
          ],
        ),
      ),
    );
  }
}
