import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/l10n/pos_l10n.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/screens/pos_orders_sheet.dart';

class _Orders extends PosController {
  int calls = 0;
  final pending = Completer<List<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> fetchHeldOrders() {
    calls++;
    return calls == 1 ? Future.value([]) : pending.future;
  }
}

void main() {
  testWidgets('polls silently without overlap and keeps list after failure', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final pos = _Orders()
      ..session = PosSession(
        serverUrl: 'https://example.test',
        token: 'test',
        restaurantId: 1,
        branchId: 1,
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<PosController>.value(
        value: pos,
        child: const MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          home: Scaffold(body: PosOrdersSheet(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(pos.calls, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(pos.calls, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(pos.calls, 2);
    pos.pending.completeError(StateError('Background network failure'));
    await tester.pump();
    expect(find.textContaining('Background network failure'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
    expect(pos.calls, 2);
    pos.dispose();
  });
}
