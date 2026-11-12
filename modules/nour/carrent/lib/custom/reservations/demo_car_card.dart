import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

class DemoCarCard extends StatelessWidget {
  final String name;
  final String category;
  final int dailyPrice;
  final VoidCallback onSelect;

  const DemoCarCard({
    super.key,
    required this.name,
    required this.category,
    required this.dailyPrice,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD9DFEA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car_outlined,
                    size: 36,
                    color: AppTheme.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(category),
                      const SizedBox(height: 6),
                      Text(
                        '$dailyPrice DT / jour',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Véhicule de démonstration',
                        style: TextStyle(
                          color: AppTheme.darkBlue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onSelect,
              child: const Text('Choisir cette voiture'),
            ),
          ],
        ),
      ),
    );
  }
}
