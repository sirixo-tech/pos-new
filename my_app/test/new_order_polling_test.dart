import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/services/pos_api.dart';

class _OrderApi extends PosApi {
  final baseline = Completer<Map<String, dynamic>>();
  int calls = 0;
  bool failNext = false;

  @override
  Future<Map<String, dynamic>> fetchNewOrders(
    PosSession session, {
    int? sinceId,
    bool baseline = false,
  }) async {
    calls++;
    if (failNext) {
      failNext = false;
      throw StateError('temporary network failure');
    }
    if (baseline) return this.baseline.future;
    return {'orders': <Map<String, dynamic>>[]};
  }
}

void main() {
  PosController controller(_OrderApi api) => PosController(api: api)
    ..session = PosSession(
      serverUrl: 'https://example.test',
      token: 'test',
      restaurantId: 1,
      branchId: 1,
    )
    ..workMode = PosWorkMode.register;

  test('resume and timer polls cannot overlap the new-order baseline', () async {
    final api = _OrderApi();
    final pos = controller(api);
    final first = pos.refreshNewOrderAlerts(silent: true);
    await pos.refreshNewOrderAlerts(silent: true);
    expect(api.calls, 1);
    api.baseline.complete({'last_order_id': 10});
    await first;
    expect(api.calls, 2);
    await pos.refreshNewOrderAlerts(silent: true);
    expect(api.calls, 3);
    pos.dispose();
  });

  test('failed order polling releases its lock for the next poll', () async {
    final api = _OrderApi()..failNext = true;
    final pos = controller(api);
    await pos.refreshNewOrderAlerts(silent: true);
    api.baseline.complete({'last_order_id': 10});
    await pos.refreshNewOrderAlerts(silent: true);
    expect(api.calls, 3);
    pos.dispose();
  });

  test('logout discards an in-flight old-session baseline', () async {
    final api = _OrderApi();
    final pos = controller(api);
    final pending = pos.refreshNewOrderAlerts(silent: true);
    pos.session = null;
    api.baseline.complete({'last_order_id': 10});
    await pending;
    expect(api.calls, 1);
    pos.dispose();
  });
}
