import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/kitchen_controller.dart';
import 'package:my_app/services/pos_api.dart';

void main() {
  final session = PosSession(serverUrl: 'https://example.test', token: 'test',
    restaurantId: 1, branchId: 1);

  test('concurrent kitchen starts share token request and handle its failure', () async {
    final kitchen = KitchenController();
    final token = Completer<String>();
    var calls = 0;
    Future<String> requestToken() {
      calls++;
      return token.future;
    }
    final first = kitchen.ensureRunning(session: session, ensureKitchenToken: requestToken);
    final second = kitchen.ensureRunning(session: session, ensureKitchenToken: requestToken);
    expect(calls, 1);
    token.completeError(PosApiException('Too Many Attempts.',
      statusCode: 429, retryAfter: const Duration(seconds: 20)));
    await Future.wait([first, second]);
    expect(kitchen.loading, isFalse);
    expect(kitchen.errorMessage, contains('Retrying'));
    await kitchen.ensureRunning(session: session, ensureKitchenToken: requestToken);
    expect(calls, 1);
    kitchen.dispose();
  });
}
