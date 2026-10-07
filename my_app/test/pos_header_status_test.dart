import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/l10n/pos_l10n.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/providers/pos_locale_controller.dart';
import 'package:my_app/screens/pos_shell.dart';
import 'package:my_app/services/offline/connectivity_service.dart';
import 'package:my_app/services/scanner_connection_service.dart';
import 'package:my_app/services/printing/pos_receipt_printer.dart';
import 'package:my_app/services/printing/printer_health.dart';
import 'package:my_app/services/printing/printer_status_service.dart';
import 'package:my_app/widgets/pos_system_status_dialog.dart';

class _Connectivity extends ConnectivityService {
  @override
  bool get isOnline => true;
  @override
  Future<bool> checkConnectivity() async => true;
}

class _Scanner extends ScannerConnectionService {
  @override
  bool get connected => true;
  @override
  Future<void> refresh() async {}
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(720, 1280),
  ]) {
    testWidgets('header and status buttons stay accessible at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = UsbPrinterConfig.smartpos(name: 'iMin NM2 Pro');
      final ready = PrinterHealth(
        state: PrinterHealthState.ready,
        config: config,
      );
      final pending = Completer<PrinterHealth>();
      final printer = PrinterStatusService(
        loadConfig: () async => config,
        probe: (_) => pending.future,
      )..applyHealth(ready);
      final pos = PosController();
      final locale = PosLocaleController();
      final connectivity = _Connectivity();
      final scanner = _Scanner();
      var alertsOpened = false;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: pos),
            ChangeNotifierProvider.value(value: locale),
            ChangeNotifierProvider.value(value: printer),
            ChangeNotifierProvider<ConnectivityService>.value(
              value: connectivity,
            ),
            ChangeNotifierProvider<ScannerConnectionService>.value(
              value: scanner,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                appBar: PosRegisterAppBar(
                  accent: Colors.orange,
                  notificationCount: 2,
                  canUseKitchen: true,
                  kotOpenCount: 6,
                  onToggleKotDock: () {},
                  onOpenDayEndReports: () {},
                  onOpenOrders: () {},
                  onOpenDelivery: () {},
                  onOpenPartnerOrders: (_) {},
                  onOpenTable: () {},
                  onOpenNotifications: () => alertsOpened = true,
                  statusControl: IconButton(
                    tooltip: 'System status',
                    icon: const Icon(Icons.warning_amber),
                    onPressed: () => showPosSystemStatusDialog(
                      context,
                      displayProbe: () async => (
                        connected: false,
                        port: null,
                        message: 'Not connected',
                        device: null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final l10n = tester.element(find.byType(PosRegisterAppBar)).l10n;
      expect(find.byTooltip('Settings').hitTestable(), findsOneWidget);
      expect(find.byTooltip(l10n.shellMore), findsNothing);
      expect(find.byTooltip(l10n.shellOrders), findsNothing);
      expect(alertsOpened, isFalse);
      await tester.tap(find.byTooltip('System status'));
      await tester.pumpAndSettle();
      expect(printer.probing, isTrue);
      expect(find.textContaining('Ready'), findsOneWidget);
      expect(find.text('Checking…'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Close').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      pending.complete(ready);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(OutlinedButton, 'Refresh').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      printer.dispose();
      pos.dispose();
      locale.dispose();
      connectivity.dispose();
      scanner.dispose();
    });
  }
}
