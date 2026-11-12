import 'package:flutter/material.dart';

import '../../custom/reservations/demo_car_card.dart';
import '../../utils/app_theme.dart';
import 'demo/available_cars_demo_data.dart';
import 'reservation_summary_screen.dart';

class AvailableCarsScreen extends StatelessWidget {
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voitures disponibles')),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Votre recherche',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Prise en charge : ${_formatDate(pickupDate)}'),
                    const SizedBox(height: 8),
                    Text('Retour : ${_formatDate(returnDate)}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pickupLocation)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Données de démonstration',
                            style: TextStyle(
                              color: AppTheme.darkBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text('Disponibilité non vérifiée.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: availableCarsDemoData.length,
                  itemBuilder: (context, index) {
                    final car = availableCarsDemoData[index];
                    return DemoCarCard(
                      name: car['name'],
                      category: car['category'],
                      dailyPrice: car['dailyPrice'],
                      onSelect: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReservationSummaryScreen(
                              vehicleName: car['name'],
                              vehicleCategory: car['category'],
                              dailyPrice: car['dailyPrice'],
                              pickupDate: pickupDate,
                              returnDate: returnDate,
                              pickupLocation: pickupLocation,
                              returnLocation: returnLocation,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
