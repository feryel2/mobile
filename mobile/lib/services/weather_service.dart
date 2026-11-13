import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/reservation_locations.dart';

class PickupForecast {
  final DateTime date;
  final double maxTemperatureCelsius;
  final int weatherCode;

  const PickupForecast({
    required this.date,
    required this.maxTemperatureCelsius,
    required this.weatherCode,
  });
}

class WeatherService {
  static const _forecastDays = 16;

  // The optional clock keeps forecast-window tests independent of today's date.
  final DateTime Function()? now;

  const WeatherService({this.now});

  /// Returns null when a forecast for this exact pickup day is unavailable.
  Future<PickupForecast?> getPickupForecast({
    required DateTime pickupDate,
    required String pickupLocation,
  }) async {
    final coordinates = reservationLocations[pickupLocation.trim()];
    if (coordinates == null) return null;

    // Tunis currently uses UTC+1 year-round. Compare calendar days, even
    // when the device is in a different timezone.
    final tunisNow =
        (now?.call() ?? DateTime.now()).toUtc().add(const Duration(hours: 1));
    final today = DateTime.utc(tunisNow.year, tunisNow.month, tunisNow.day);
    final pickupDay =
        DateTime.utc(pickupDate.year, pickupDate.month, pickupDate.day);
    final daysAhead = pickupDay.difference(today).inDays;
    if (daysAhead < 0 || daysAhead >= _forecastDays) return null;

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': coordinates[0].toString(),
      'longitude': coordinates[1].toString(),
      'daily': 'weather_code,temperature_2m_max',
      'temperature_unit': 'celsius',
      'timezone': 'Africa/Tunis',
      'forecast_days': _forecastDays.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final daily = json['daily'];
      if (daily is! Map<String, dynamic>) return null;

      final dates = daily['time'];
      final temperatures = daily['temperature_2m_max'];
      final weatherCodes = daily['weather_code'];
      if (dates is! List || temperatures is! List || weatherCodes is! List) {
        return null;
      }

      final dateText = pickupDay.toIso8601String().substring(0, 10);
      final index = dates.indexOf(dateText);
      if (index < 0 ||
          index >= temperatures.length ||
          index >= weatherCodes.length) {
        return null;
      }
      final temperature = temperatures[index];
      final weatherCode = weatherCodes[index];
      if (temperature is! num || !temperature.isFinite || weatherCode is! int) {
        return null;
      }

      return PickupForecast(
        date: pickupDay,
        maxTemperatureCelsius: temperature.toDouble(),
        weatherCode: weatherCode,
      );
    } on http.ClientException {
      return null;
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
