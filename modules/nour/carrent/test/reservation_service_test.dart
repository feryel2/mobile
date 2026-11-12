import 'dart:async';
import 'dart:convert';

import 'package:carrent/services/reservation_service.dart';
import 'package:carrent/utils/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/reservation_json.dart';

void main() {
  test('GET returns models from a backend-shaped reservation array', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '${ApiConfig.baseUrl}/reservations/client/${ApiConfig.developmentClientId}',
      );
      return http.Response(
        jsonEncode([
          reservationJson(),
          reservationJson(
            changes: {'_id': '222222222222222222222222', 'status': 'cancelled'},
          ),
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    final result = await ReservationService.getClientReservations(
      ApiConfig.developmentClientId,
      client: client,
    );
    expect(result.length, 2);
    expect(result[0].pickupLocation, 'Tunis - Aéroport');
    expect(result[0].totalPriceMillimes, 150000);
    expect(result[1].status, 'cancelled');
  });

  test('successful empty JSON array returns an empty list', () async {
    final client = MockClient((request) async => http.Response('[]', 200));
    addTearDown(client.close);
    expect(
      await ReservationService.getClientReservations(
        ApiConfig.developmentClientId,
        client: client,
      ),
      isEmpty,
    );
  });

  for (final status in [400, 403, 500, 503]) {
    test('HTTP $status is an error, never an empty history', () async {
      final client = MockClient((request) async => http.Response('{}', status));
      addTearDown(client.close);
      await expectLater(
        ReservationService.getClientReservations(
          ApiConfig.developmentClientId,
          client: client,
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('HTTP $status'),
          ),
        ),
      );
    });
  }

  for (final body in ['not-json', '{}', '[123]', '[{}]']) {
    test('invalid or incomplete API data is rejected: $body', () async {
      final client = MockClient((request) async => http.Response(body, 200));
      addTearDown(client.close);
      await expectLater(
        ReservationService.getClientReservations(
          ApiConfig.developmentClientId,
          client: client,
        ),
        throwsFormatException,
      );
    });
  }

  test('invalid client ID is rejected before sending a request', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('[]', 200);
    });
    addTearDown(client.close);
    await expectLater(
      ReservationService.getClientReservations('invalid', client: client),
      throwsFormatException,
    );
    expect(called, isFalse);
  });

  test('connection failure explains the local backend and CORS', () async {
    final client = MockClient(
      (request) async => throw http.ClientException('Failed to fetch'),
    );
    addTearDown(client.close);
    await expectLater(
      ReservationService.getClientReservations(
        ApiConfig.developmentClientId,
        client: client,
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('CORS'),
        ),
      ),
    );
  });

  testWidgets('an unresponsive request times out rather than loading forever', (
    tester,
  ) async {
    final pendingResponse = Completer<http.Response>();
    final client = MockClient((request) => pendingResponse.future);
    addTearDown(client.close);
    final result = ReservationService.getClientReservations(
      ApiConfig.developmentClientId,
      client: client,
    );
    final expectation = expectLater(
      result,
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('délai'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 11));
    await expectation;
  });
}
