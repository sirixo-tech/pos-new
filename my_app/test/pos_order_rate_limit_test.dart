import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/services/pos_api.dart';

void main() {
  final session = PosSession(
    serverUrl: 'https://example.test',
    token: 'test-token',
    restaurantId: 7,
    branchId: 3,
  );

  test('a fast sale retries a rate limit instead of failing', () async {
    var calls = 0;
    final api = PosApi(
      client: MockClient((request) async {
        calls += 1;
        expect(request.headers['Idempotency-Key'], 'sale-1');
        if (calls == 1) {
          return http.Response(
            jsonEncode({'message': 'Too Many Attempts.'}),
            429,
            headers: {'retry-after': '0'},
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'order': {'id': 9, 'order_number': 'A9'},
            },
          }),
          200,
        );
      }),
    );

    final order = await api.createOrder(
      session,
      items: const [
        {'menu_item_id': 1, 'quantity': 1},
      ],
      type: 'takeaway',
      payment: const {'method': 'cash'},
      idempotencyKey: 'sale-1',
    );

    expect(calls, 2);
    expect(order.id, 9);
    expect(order.orderNumber, 'A9');
    expect(PosApi.isRateLimited, isFalse);
  });
}
