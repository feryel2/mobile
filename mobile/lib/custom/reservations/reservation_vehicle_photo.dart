import 'package:flutter/material.dart';

class ReservationVehiclePhoto extends StatelessWidget {
  final String vehicleName;
  final String? image;
  final double height;

  const ReservationVehiclePhoto({
    super.key,
    required this.vehicleName,
    required this.image,
    required this.height,
  });

  Widget _fallbackPhoto() {
    return Image.asset(
      'assets/images/default_car.png',
      fit: BoxFit.contain,
      semanticLabel: 'Photo générique de véhicule',
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.directions_car_outlined,
            color: Color(0xFF5D6678), size: 56),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filename = image?.trim() ?? '';
    return SizedBox(
      height: height,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: filename.isEmpty || filename == 'default_car.png'
              ? _fallbackPhoto()
              : Image.asset(
                  'assets/images/$filename',
                  fit: BoxFit.contain,
                  semanticLabel: 'Photo de $vehicleName',
                  errorBuilder: (context, error, stackTrace) =>
                      _fallbackPhoto(),
                ),
        ),
      ),
    );
  }
}
