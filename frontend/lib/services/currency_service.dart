
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Appelle une API externe (ExchangeRate-API, endpoint ouvert sans clé)
/// pour obtenir les taux de change à partir du dinar tunisien (TND).
class CurrencyService {
  static const _url = 'https://open.er-api.com/v6/latest/TND';
  static const _cacheDuration = Duration(hours: 6);

  // Cache en mémoire : les taux ne changent qu'une fois par jour,
  // inutile de rappeler l'API à chaque ouverture d'un écran.
  static Map<String, double>? _rates;
  static DateTime? _fetchedAt;

  /// Retourne les taux 1 TND -> autres devises (ex: {'EUR': 0.30, 'USD': 0.32}).
  Future<Map<String, double>> getRates() async {
    final cached = _rates;
    final at = _fetchedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _cacheDuration) {
      return cached;
    }

    final response = await http
        .get(Uri.parse(_url))
        .timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception('Service de taux indisponible (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['result'] != 'success') {
      throw Exception('Réponse invalide du service de taux');
    }

    final rates = (body['rates'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toDouble()));

    _rates = rates;
    _fetchedAt = DateTime.now();
    return rates;
  }
}

