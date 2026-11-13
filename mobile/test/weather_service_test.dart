import 'dart:async';
import 'dart:convert';

import 'package:carrent_client/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _airport = 'Tunis - Aéroport';

Map<String, Object?> _dailyForecast() => {
      'time': ['2026-11-13', '2026-11-14', '2026-11-15'],
      'temperature_2m_max': [18, 21.7, 19.4],
      'weather_code': [0, 3, 61],
    };

http.Response _forecastResponse(Map<String, Object?> daily) =>
    http.Response(jsonEncode({'daily': daily}), 200);

void main() {
  final service = WeatherService(now: () => DateTime.utc(2026, 11, 13, 12));

  test('sends the Open-Meteo GET and reads the exact pickup day', () async {
    final forecast = await http.runWithClient(
      () => service.getPickupForecast(
        pickupDate: DateTime(2026, 11, 14, 18),
        pickupLocation: _airport,
      ),
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.path, '/v1/forecast');
        expect(request.url.queryParameters, {
          'latitude': '36.8511',
          'longitude': '10.2269',
          'daily': 'weather_code,temperature_2m_max',
          'temperature_unit': 'celsius',
          'timezone': 'Africa/Tunis',
          'forecast_days': '16',
        });
        return _forecastResponse(_dailyForecast());
      }),
    );

    expect(forecast, isNotNull);
    expect(forecast!.date, DateTime.utc(2026, 11, 14));
    expect(forecast.maxTemperatureCelsius, 21.7);
    expect(forecast.weatherCode, 3);
  });

  const addedCoordinates = {
    'Tunis - Centre-ville': ['36.79944', '10.17851'],
    'Tunis - Les Berges du Lac': ['36.83509', '10.23884'],
    'Tunis - La Marsa': ['36.87818', '10.32466'],
    'Tunis - Carthage': ['36.85961', '10.32978'],
    'Tunis - Sidi Bou Saïd': ['36.87111', '10.34619'],
    'Grand Tunis - Ariana': ['36.86542', '10.16846'],
  };

  for (final location in addedCoordinates.entries) {
    test('uses the coordinates for ${location.key}', () async {
      final forecast = await http.runWithClient(
        () => service.getPickupForecast(
          pickupDate: DateTime(2026, 11, 14),
          pickupLocation: location.key,
        ),
        () => MockClient((request) async {
          expect(request.url.queryParameters['latitude'], location.value[0]);
          expect(request.url.queryParameters['longitude'], location.value[1]);
          return _forecastResponse(_dailyForecast());
        }),
      );
      expect(forecast?.maxTemperatureCelsius, 21.7);
    });
  }

  test('uses the Tunis calendar day at midnight and accepts the final day',
      () async {
    final service =
        WeatherService(now: () => DateTime.utc(2026, 11, 13, 23, 10));
    final forecast = await http.runWithClient(
      () => service.getPickupForecast(
        pickupDate: DateTime(2026, 11, 29),
        pickupLocation: _airport,
      ),
      () => MockClient((_) async => _forecastResponse({
            'time': ['2026-11-29'],
            'temperature_2m_max': [18],
            'weather_code': [0],
          })),
    );

    expect(forecast?.date, DateTime.utc(2026, 11, 29));
    expect(forecast?.maxTemperatureCelsius, 18.0);
  });

  test('unsupported locations and dates outside 16 days skip HTTP', () async {
    var requests = 0;
    await http.runWithClient(
      () async {
        expect(
          await service.getPickupForecast(
            pickupDate: DateTime(2026, 11, 14),
            pickupLocation: 'Sousse',
          ),
          isNull,
        );
        for (final pickup in [DateTime(2026, 11, 12), DateTime(2026, 11, 29)]) {
          expect(
            await service.getPickupForecast(
              pickupDate: pickup,
              pickupLocation: _airport,
            ),
            isNull,
          );
        }
      },
      () => MockClient((_) async {
        requests++;
        return _forecastResponse(_dailyForecast());
      }),
    );
    expect(requests, 0);
  });

  final unavailableCases = <String, Future<http.Response> Function()>{
    'missing pickup day': () async => _forecastResponse(_dailyForecast()),
    'missing daily data': () async => http.Response('{}', 200),
    'missing maximum temperature': () async =>
        _forecastResponse(_dailyForecast()..remove('temperature_2m_max')),
    'null temperature': () async => _forecastResponse(
          _dailyForecast()..['temperature_2m_max'] = [18, null, 19.4],
        ),
    'truncated weather codes': () async =>
        _forecastResponse(_dailyForecast()..['weather_code'] = [0]),
    'invalid weather code': () async => _forecastResponse(
          _dailyForecast()..['weather_code'] = [0, '3', 61],
        ),
    'HTTP error': () async => http.Response('Service unavailable', 503),
    'malformed JSON': () async => http.Response('{invalid', 200),
    'no internet': () async => throw http.ClientException('Offline'),
    'timeout': () async => throw TimeoutException('Forecast timed out'),
  };

  for (final entry in unavailableCases.entries) {
    test('returns unavailable for ${entry.key}', () async {
      final forecast = await http.runWithClient(
        () => service.getPickupForecast(
          pickupDate:
              DateTime(2026, 11, entry.key == 'missing pickup day' ? 16 : 14),
          pickupLocation: _airport,
        ),
        () => MockClient((_) => entry.value()),
      );
      expect(forecast, isNull);
    });
  }
}
