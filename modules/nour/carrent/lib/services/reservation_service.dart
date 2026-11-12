import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/reservation.dart';
import '../utils/api_config.dart';

class ReservationService {
  static Future<List<Reservation>> getClientReservations(
    String clientId, {
    http.Client? client,
  }) async {
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(clientId)) {
      throw const FormatException('Identifiant client de test invalide.');
    }
    final link = '${ApiConfig.baseUrl}/reservations/client/$clientId';
    http.Response response;
    try {
      // Normal use follows the workshop's http.get. Tests can supply a client.
      final request = client == null
          ? http.get(Uri.parse(link))
          : client.get(Uri.parse(link));
      response = await request.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw Exception('Le serveur local ne répond pas dans le délai prévu.');
    } on http.ClientException {
      throw Exception(
        'Connexion impossible à l’API locale. Vérifiez le serveur et CORS dans Chrome.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Chargement impossible (HTTP ${response.statusCode}). '
        'L’API nécessite le développement local.',
      );
    }
    final responseItems = jsonDecode(response.body);
    if (responseItems is! List) {
      throw const FormatException(
        'La réponse API doit être une liste de réservations.',
      );
    }
    final List<Reservation> reservations = [];
    for (final item in responseItems) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Une entrée de réservation API est invalide.',
        );
      }
      reservations.add(Reservation.fromJson(item));
    }
    return reservations;
  }
}
