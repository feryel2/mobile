class Rental {
  final String id;
  final String vehicleName;
  final String registration;
  final String imageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalPrice;
  final String currency;
  final String status;

  const Rental({
    required this.id,
    required this.vehicleName,
    required this.registration,
    required this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.currency,
    required this.status,
  });

  factory Rental.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] is Map<String, dynamic>
        ? json['vehicle'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final price = json['totalPrice'];

    return Rental(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      vehicleName: vehicle['name']?.toString() ?? 'Véhicule',
      registration: vehicle['registration']?.toString() ?? '',
      imageUrl: vehicle['imageUrl']?.toString() ?? '',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? ''),
      totalPrice:
          price is num ? price.toDouble() : double.tryParse('$price') ?? 0,
      currency: json['currency']?.toString() ?? 'EUR',
      status: json['status']?.toString() ?? 'confirmed',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'ongoing':
        return 'En cours';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }
}
