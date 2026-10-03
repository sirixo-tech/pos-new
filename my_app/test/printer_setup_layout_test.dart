import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer/printer_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/l10n/pos_l10n.dart';
import 'package:my_app/screens/printer_setup_screen.dart';
import 'package:my_app/services/printing/pos_receipt_printer.dart';
import 'package:my_app/services/printing/printer_health.dart';
import 'package:my_app/services/printing/printer_status_service.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(800, 480),
  ]) {
    testWidgets('printer controls remain reachable at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = UsbPrinterConfig.smartpos(
        name: 'iMin NM2 Pro (I21M01) printer',
      );
      SharedPreferences.setMockInitialValues({
        posUsbPrinterKey: jsonEncode(config.toJson()),
      });
      final service = PrinterStatusService();
      service.applyHealth(
        PrinterHealth(
          state: PrinterHealthState.attention,
          config: config,
          message: 'Close the printer cover, then try again.',
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const PrinterSetupScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
      final testButton = find.widgetWithText(FilledButton, 'Test print');
      await tester.scrollUntilVisible(
        testButton,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(testButton.hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Clear kitchen ticket on scan-to-print'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Clear kitchen ticket on scan-to-print').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(
        () => PrinterManager.instance.stopScan(stopBle: false),
      );
      service.dispose();
    });
  }
}
