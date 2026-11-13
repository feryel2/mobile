class Reservation {
  final String id;
  final String vehicleId;
  final String vehicleName;
  final String registration;
  final String image;
  final String clientId;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;
  final int totalPriceMillimes;
  final String status;

  Reservation({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.registration,
    required this.image,
    required this.clientId,
    required this.pickupDate,
    required this.returnDate,
    required this.pickupLocation,
    required this.returnLocation,
    required this.totalPriceMillimes,
    required this.status,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicleId'] is Map<String, dynamic>
        ? json['vehicleId'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final vehicleId =
        vehicle['_id']?.toString() ?? json['vehicleId']?.toString() ?? '';
    for (final field in [
      '_id',
      'clientId',
      'pickupLocation',
      'returnLocation',
      'status',
    ]) {
      if (json[field] is! String || (json[field] as String).trim().isEmpty) {
        throw FormatException(
          'Champ de réservation manquant ou invalide : $field.',
        );
      }
    }
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(vehicleId)) {
      throw const FormatException('Identifiant véhicule invalide.');
    }
    for (final field in ['_id', 'clientId']) {
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(json[field] as String)) {
        throw FormatException('Identifiant de réservation invalide : $field.');
      }
    }
    if (json['totalPriceMillimes'] is! int || json['totalPriceMillimes'] < 0) {
      throw const FormatException(
        'Le prix doit être un entier positif ou nul en millimes.',
      );
    }
    if (json['status'] != 'confirmed' && json['status'] != 'cancelled') {
      throw const FormatException('Statut de réservation inconnu.');
    }
    final pickup = _readDate(json['pickupDate']);
    final end = _readDate(json['returnDate']);
    if (!end.isAfter(pickup)) {
      throw const FormatException(
        'La date de retour doit être après le départ.',
      );
    }
    return Reservation(
      id: json['_id'],
      vehicleId: vehicleId,
      vehicleName: [
        vehicle['marque']?.toString(),
        vehicle['modele']?.toString(),
      ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
      registration: vehicle['immatriculation']?.toString() ?? '',
      image: vehicle['image']?.toString() ?? '',
      clientId: json['clientId'],
      pickupDate: pickup,
      returnDate: end,
      pickupLocation: json['pickupLocation'],
      returnLocation: json['returnLocation'],
      totalPriceMillimes: json['totalPriceMillimes'],
      status: json['status'],
    );
  }

  static DateTime _readDate(dynamic value) {
    // Mongoose returns our UTC calendar dates as ISO strings at midnight.
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T00:00:00\.000Z$').hasMatch(value)) {
      throw const FormatException(
        'Date de réservation UTC manquante ou invalide.',
      );
    }
    final date = DateTime.tryParse(value);
    // Dart can normalize impossible dates; compare with the original input.
    if (date == null || date.toIso8601String() != value) {
      throw const FormatException('Date de réservation invalide.');
    }
    return date;
  }
}
