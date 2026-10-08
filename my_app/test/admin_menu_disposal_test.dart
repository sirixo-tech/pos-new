import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/admin_models.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_admin_controller.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/services/pos_api.dart';

class _MenuApi extends PosApi {
  final result = Completer<AdminMenuPayload>();
  @override
  Future<AdminMenuPayload> fetchAdminMenu(PosSession session) => result.future;
}

void main() {
  test('menu fetch finishing after disposal does not notify or throw', () async {
    final api = _MenuApi();
    final pos = PosController()..session = PosSession(
      serverUrl: 'https://example.test', token: 'test',
      restaurantId: 456, branchId: 789,
    );
    final admin = PosAdminController(api: api, pos: pos);
    var notifications = 0;
    admin.addListener(() => notifications++);
    final load = admin.loadMenu();
    final beforeDispose = notifications;
    admin.dispose();
    api.result.complete(AdminMenuPayload(categories: [], modifiers: [], timeSlots: []));
    await load;
    expect(notifications, beforeDispose);
    pos.dispose();
  });
}
