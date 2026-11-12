import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import 'reservation_summary_screen.dart';

class AvailableCarsScreen extends StatefulWidget {
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;

  const AvailableCarsScreen({
    super.key,
    required this.pickupDate,
    required this.returnDate,
    required this.pickupLocation,
    required this.returnLocation,
  });

  @override
  State<AvailableCarsScreen> createState() => _AvailableCarsScreenState();
}

class _AvailableCarsScreenState extends State<AvailableCarsScreen> {
  final VehicleService _vehicleService = VehicleService();
  late Future<List<Vehicle>> _vehicles;

  @override
  void initState() {
    super.initState();
    _vehicles = _vehicleService.getAvailableForDates(
      widget.pickupDate,
      widget.returnDate,
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Véhicules disponibles')),
      body: FutureBuilder<List<Vehicle>>(
        future: _vehicles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossible de vérifier les disponibilités.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final vehicles = snapshot.data ?? [];
          if (vehicles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun véhicule disponible sur cette période.'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text(
                    '${_formatDate(widget.pickupDate)} – '
                    '${_formatDate(widget.returnDate)}',
                  ),
                  subtitle: Text(
                    '${widget.pickupLocation} → ${widget.returnLocation}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final vehicle in vehicles)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.directions_car, size: 36),
                    title: Text('${vehicle.marque} ${vehicle.modele}'),
                    subtitle: Text(
                      '${vehicle.carburant} • ${vehicle.annee}\n'
                      '${vehicle.prix.toStringAsFixed(2)} DT / jour',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReservationSummaryScreen(
                            vehicle: vehicle,
                            pickupDate: widget.pickupDate,
                            returnDate: widget.returnDate,
                            pickupLocation: widget.pickupLocation,
                            returnLocation: widget.returnLocation,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
