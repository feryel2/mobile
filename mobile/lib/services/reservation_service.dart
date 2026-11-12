import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/reservation.dart';
import 'user_service.dart';

class ReservationService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/reservations';

  static Future<Map<String, String>> _headers() async {
    final token = await UserService.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Connectez-vous avant de gérer vos réservations.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send,
  ) async {
    try {
      final response = await send().timeout(ApiConfig.timeout);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Réponse API invalide.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            decoded['message'] ?? 'Erreur API (${response.statusCode}).');
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Le serveur CarRent ne répond pas.');
    } on http.ClientException {
      throw Exception('Connexion impossible à l’API CarRent.');
    }
  }

  static Future<List<Reservation>> getMyReservations() async {
    final headers = await _headers();
    final data = await _request(
      () => http.get(Uri.parse('$_baseUrl/mine'), headers: headers),
    );
    final items = data['data'];
    if (items is! List) {
      throw const FormatException('La liste de réservations est invalide.');
    }
    return items
        .map((item) => Reservation.fromJson(item as Map<String, dynamic>))
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

  static String _dateOnly(DateTime value) {
    final date = DateTime.utc(value.year, value.month, value.day);
    return date.toIso8601String().substring(0, 10);
  }
}
