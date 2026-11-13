import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/reservation.dart';
import 'user_service.dart';

class AdminReservationAccessException implements Exception {
  const AdminReservationAccessException();
}

class ReservationRequestException implements Exception {
  final String message;
  final int? statusCode;

  const ReservationRequestException(this.message, {this.statusCode});

  @override
  String toString() => 'Exception: $message';
}

class ReservationService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/reservations';

  static Future<Map<String, String>> _headers({bool adminList = false}) async {
    final token = await UserService.getToken();
    if (token == null || token.isEmpty) {
      if (adminList) throw const AdminReservationAccessException();
      throw StateError('Connectez-vous avant de gérer vos réservations.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    bool adminList = false,
  }) async {
    try {
      final response = await send().timeout(ApiConfig.timeout);
      if (adminList &&
          (response.statusCode == 401 || response.statusCode == 403)) {
        throw const AdminReservationAccessException();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Réponse API invalide.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ReservationRequestException(
          decoded['message']?.toString() ??
              'Erreur API (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on TimeoutException {
      throw const ReservationRequestException(
          'Le serveur CarRent ne répond pas.');
    } on http.ClientException {
      throw const ReservationRequestException(
          'Connexion impossible à l’API CarRent.');
    }
  }

  static Future<List<Reservation>> getMyReservations() =>
      _getReservations('mine');

  static Future<List<Reservation>> getAdminReservations() =>
      _getReservations('admin', adminList: true);

  static Future<List<Reservation>> _getReservations(String path,
      {bool adminList = false}) async {
    final headers = await _headers(adminList: adminList);
    final data = await _request(
      () => http.get(Uri.parse('$_baseUrl/$path'), headers: headers),
      adminList: adminList,
    );
    final items = data['data'];
    if (items is! List) {
      throw const FormatException('La liste de réservations est invalide.');
    }
    return items
        .map((item) => Reservation.fromJson(item as Map<String, dynamic>,
            adminList: adminList))
        .toList();
  }

  static Future<Reservation> create({
    required String vehicleId,
    required DateTime pickupDate,
    required DateTime returnDate,
    required String pickupLocation,
    required String returnLocation,
  }) async {
    final headers = await _headers();
    final data = await _request(
      () => http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode({
          'vehicleId': vehicleId,
          'pickupDate': _dateOnly(pickupDate),
          'returnDate': _dateOnly(returnDate),
          'pickupLocation': pickupLocation,
          'returnLocation': returnLocation,
        }),
      ),
    );
    return Reservation.fromJson(data['data'] as Map<String, dynamic>);
  }

  static Future<Reservation> cancel(String reservationId) async {
    final headers = await _headers();
    final data = await _request(
      () => http.post(
        Uri.parse('$_baseUrl/$reservationId/cancel'),
        headers: headers,
      ),
    );
    return Reservation.fromJson(data['data'] as Map<String, dynamic>);
  }

  static Future<Reservation> adminCancelReservation(
    String reservationId, {
    required String reason,
  }) async {
    final headers = await _headers(adminList: true);
    final response = await _request(
      () => http.post(
        Uri.parse('$_baseUrl/$reservationId/admin-cancel'),
        headers: headers,
        body: jsonEncode({'reason': reason}),
      ),
      adminList: true,
    );
    final data = response['data'];
    if (response['success'] != true || data is! Map<String, dynamic>) {
      throw const FormatException('Réponse d’annulation invalide.');
    }
    final reservation = Reservation.fromJson(data, adminList: true);
    if (reservation.id != reservationId ||
        !reservation.cancelledByAdmin ||
        reservation.cancellationReason != reason) {
      throw const FormatException('L’annulation n’a pas été confirmée.');
    }
    return reservation;
  }

  static String _dateOnly(DateTime value) {
    final date = DateTime.utc(value.year, value.month, value.day);
    return date.toIso8601String().substring(0, 10);
  }
}
