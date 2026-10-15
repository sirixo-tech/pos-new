import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/screens/customer_display/customer_display_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('CustomerCartDisplayPage renders on small mobile (360x640) without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final pos = PosController()..serverUrl = 'https://example.test';

    await tester.pumpWidget(
      ChangeNotifierProvider<PosController>.value(
        value: pos,
        child: const MaterialApp(
          home: CustomerCartDisplayPage(
            branchId: 1,
            terminalCode: 'T-01',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Review Your Order'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('QTY'), findsOneWidget);
    expect(find.text('ITEM NAME'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text('No items in the cart'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Grand Total'), findsOneWidget);
    expect(find.text('Thank you for dining with us!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CustomerCartDisplayPage renders on standard mobile (390x844) without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final pos = PosController()..serverUrl = 'https://example.test';

    await tester.pumpWidget(
      ChangeNotifierProvider<PosController>.value(
        value: pos,
        child: const MaterialApp(
          home: CustomerCartDisplayPage(
            branchId: 1,
            terminalCode: 'T-01',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Review Your Order'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('Grand Total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CustomerCartDisplayPage renders on desktop/tablet (1024x768) without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final pos = PosController()..serverUrl = 'https://example.test';

    await tester.pumpWidget(
      ChangeNotifierProvider<PosController>.value(
        value: pos,
        child: const MaterialApp(
          home: CustomerCartDisplayPage(
            branchId: 1,
            terminalCode: 'T-01',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Review Your Order'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('Grand Total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
