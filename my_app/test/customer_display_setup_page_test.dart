import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/customer_display/customer_display_setup_page.dart';

void main() {
  testWidgets('CustomerDisplaySetupPage renders on mobile without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerDisplaySetupPage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('QR Display Pairing'), findsOneWidget);
    expect(find.text('Connect Customer Display'), findsOneWidget);
    expect(find.text('Pairing Code'), findsOneWidget);
    expect(find.text('Connection Status'), findsOneWidget);
    expect(find.text('Connected Displays'), findsNothing);
    expect(find.text('Displays'), findsOneWidget);
    expect(find.text('No Displays Connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CustomerDisplaySetupPage renders on desktop 2-column layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerDisplaySetupPage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('QR Display Pairing'), findsOneWidget);
    expect(find.text('Connect Customer Display'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
