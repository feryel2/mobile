import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rental_model.dart';
import '../services/user_service.dart';

class RentalHistoryPanel extends StatefulWidget {
  const RentalHistoryPanel({super.key});

  @override
  State<RentalHistoryPanel> createState() => _RentalHistoryPanelState();
}

class _RentalHistoryPanelState extends State<RentalHistoryPanel> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  String? _error;
  List<Rental> _rentals = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _userService.getRentalHistory();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _rentals = result['rentals'] as List<Rental>;
      } else {
        _error = result['message']?.toString() ??
            'Impossible de charger l’historique.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Mes locations',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Retrouvez ici le suivi de vos locations passées et en cours.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildMessage(
                icon: Icons.cloud_off_outlined,
                message: _error!,
                action: TextButton.icon(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              )
            else if (_rentals.isEmpty)
              _buildMessage(
                icon: Icons.directions_car_outlined,
                message:
                    'Aucune location pour le moment. Votre historique apparaîtra ici après vos premières réservations.',
              )
            else
              ..._rentals.map(_buildRentalCard),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: const Color(0xFF0052CC)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildRentalCard(Rental rental) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dates = rental.startDate != null && rental.endDate != null
        ? '${dateFormat.format(rental.startDate!)} - ${dateFormat.format(rental.endDate!)}'
        : 'Dates indisponibles';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: rental.imageUrl.isNotEmpty
                  ? Image.network(
                      rental.imageUrl,
                      width: 82,
                      height: 82,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _vehiclePlaceholder(),
                    )
                  : _vehiclePlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rental.vehicleName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  if (rental.registration.isNotEmpty)
                    Text(
                      rental.registration,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  const SizedBox(height: 6),
                  Text(dates, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statusChip(rental.statusLabel),
                      Text(
                        '${rental.totalPrice.toStringAsFixed(2)} ${rental.currency}',
                        style: const TextStyle(
                          color: Color(0xFF0052CC),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehiclePlaceholder() {
    return Container(
      width: 82,
      height: 82,
      color: const Color(0xFFEAF1FC),
      child:
          const Icon(Icons.directions_car, color: Color(0xFF0052CC), size: 34),
    );
  }

  Widget _statusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0052CC).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0052CC),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
