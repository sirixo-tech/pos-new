import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/pos_startup.dart';

void main() {
  testWidgets('renders before display initialization and stays responsive', (
    tester,
  ) async {
    final displayReady = Completer<void>();
    var calls = 0;
    final app = PosStartup(
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Text('POS ready'),
      ),
      initializeDisplay: () {
        calls++;
        expect(find.text('POS ready'), findsOneWidget);
        return displayReady.future;
      },
    );
    expect(calls, 0);
    await tester.pumpWidget(app);
    expect(calls, 1);
    expect(find.text('POS ready'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    displayReady.complete();
    await tester.pump(Duration.zero);
  });

  testWidgets('display failure leaves the app mounted and reports the error', (
    tester,
  ) async {
    await tester.pumpWidget(
      PosStartup(
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('POS ready'),
        ),
        initializeDisplay: () async => throw StateError('window unavailable'),
      ),
    );
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('POS ready'), findsOneWidget);
  });
}
