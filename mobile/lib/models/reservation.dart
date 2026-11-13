class Reservation {
  final String id;
  final String vehicleId;
  final String vehicleName;
  final String registration;
  final String image;
  final String clientId;
  final String clientName;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;
  final int totalPriceMillimes;
  final String status;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? cancelledByRole;

  bool get cancelledByAdmin =>
      status == 'cancelled' && cancelledByRole == 'admin';

  Reservation({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.registration,
    required this.image,
    required this.clientId,
    this.clientName = '',
    required this.pickupDate,
    required this.returnDate,
    required this.pickupLocation,
    required this.returnLocation,
    required this.totalPriceMillimes,
    required this.status,
    this.cancellationReason,
    this.cancelledAt,
    this.cancelledByRole,
  });

  factory Reservation.fromJson(Map<String, dynamic> json,
      {bool adminList = false}) {
    final vehicle = json['vehicleId'] is Map<String, dynamic>
        ? json['vehicleId'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final vehicleId =
        vehicle['_id']?.toString() ?? json['vehicleId']?.toString() ?? '';
    final client = adminList && json['clientId'] is Map<String, dynamic>
        ? json['clientId'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final clientId = client['_id'] ?? json['clientId'];
    for (final field in [
      '_id',
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
    final objectId = RegExp(r'^[a-fA-F0-9]{24}$');
    // MongoDB returns null for a populated record that no longer exists.
    final missingVehicle =
        adminList && json.containsKey('vehicleId') && json['vehicleId'] == null;
    final missingClient =
        adminList && json.containsKey('clientId') && json['clientId'] == null;
    if (!missingVehicle && !objectId.hasMatch(vehicleId)) {
      throw const FormatException('Identifiant véhicule invalide.');
    }
    if (!objectId.hasMatch(json['_id'] as String)) {
      throw const FormatException('Identifiant de réservation invalide : _id.');
    }
    if (!missingClient &&
        (clientId is! String || !objectId.hasMatch(clientId))) {
      throw const FormatException(
          'Identifiant de réservation invalide : clientId.');
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
      clientId: missingClient ? '' : clientId as String,
      clientName: client['fullname']?.toString().trim() ?? '',
      pickupDate: pickup,
      returnDate: end,
      pickupLocation: json['pickupLocation'],
      returnLocation: json['returnLocation'],
      totalPriceMillimes: json['totalPriceMillimes'],
      status: json['status'],
      cancellationReason: (json['cancellationReason'] as String?)?.trim(),
      cancelledAt: DateTime.tryParse(json['cancelledAt']?.toString() ?? ''),
      cancelledByRole: json['cancelledByRole'] as String?,
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
