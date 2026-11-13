import '../utils/reservation_date_range.dart';
import 'user_model.dart';
import 'vehicle.dart';

class ReservationDraft {
  final int? id;
  final String clientId;
  final String vehicleId;
  final String vehicleName;
  // The filename provided by the team's Vehicle model.
  final String? vehicleImage;
  final int dailyPriceMillimes;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String pickupLocation;
  final String returnLocation;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReservationDraft({
    this.id,
    required this.clientId,
    required this.vehicleId,
    required this.vehicleName,
    this.vehicleImage,
    required this.dailyPriceMillimes,
    required DateTime pickupDate,
    required DateTime returnDate,
    required this.pickupLocation,
    required this.returnLocation,
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : pickupDate = _calendarDay(pickupDate),
        returnDate = _calendarDay(returnDate),
        createdAt = createdAt.toUtc(),
        updatedAt = updatedAt.toUtc() {
    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(vehicleId)) {
      throw ArgumentError('A draft requires a server vehicle ID.');
    }
    if (dailyPriceMillimes < 0) {
      throw ArgumentError('A draft price cannot be negative.');
    }
  }

  factory ReservationDraft.fromVehicle({
    int? id,
    DateTime? createdAt,
    required User client,
    required Vehicle vehicle,
    required DateTime pickupDate,
    required DateTime returnDate,
    required String pickupLocation,
    required String returnLocation,
  }) {
    if (!vehicle.prix.isFinite || vehicle.prix < 0) {
      throw ArgumentError('The vehicle daily price is invalid.');
    }
    final now = DateTime.now().toUtc();
    return ReservationDraft(
      id: id,
      clientId: client.id,
      vehicleId: vehicle.id ?? '',
      vehicleName: '${vehicle.marque} ${vehicle.modele}',
      vehicleImage: vehicle.image,
      dailyPriceMillimes: (vehicle.prix * 1000).round(),
      pickupDate: pickupDate,
      returnDate: returnDate,
      pickupLocation: pickupLocation,
      returnLocation: returnLocation,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  static DateTime _calendarDay(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  int get rentalDays => calculateRentalDays(pickupDate, returnDate);

  int? get estimatedTotalMillimes {
    final days = rentalDays;
    if (days <= 0) return null;
    return days * dailyPriceMillimes;
  }

  static String formatMillimes(int millimes) {
    final amount = millimes.abs();
    final dinars = amount ~/ 1000;
    final fraction = (amount % 1000).toString().padLeft(3, '0');
    final sign = millimes < 0 ? '-' : '';
    return '$sign$dinars.$fraction DT';
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'vehicleImage': vehicleImage,
      'dailyPriceMillimes': dailyPriceMillimes,
      'pickupDate': pickupDate.toIso8601String(),
      'returnDate': returnDate.toIso8601String(),
      'pickupLocation': pickupLocation,
      'returnLocation': returnLocation,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReservationDraft.fromMap(Map<String, Object?> map) {
    return ReservationDraft(
      id: map['id'] as int?,
      clientId: map['clientId'] as String,
      vehicleId: map['vehicleId'] as String,
      vehicleName: map['vehicleName'] as String,
      vehicleImage: map['vehicleImage'] as String?,
      dailyPriceMillimes: map['dailyPriceMillimes'] as int,
      pickupDate: DateTime.parse(map['pickupDate'] as String),
      returnDate: DateTime.parse(map['returnDate'] as String),
      pickupLocation: map['pickupLocation'] as String,
      returnLocation: map['returnLocation'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
