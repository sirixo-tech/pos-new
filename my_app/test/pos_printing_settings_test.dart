import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/printing/print_job_coordinator.dart';
import 'package:my_app/services/printing/scan_to_print_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PosPrintingSettings defaults to enabled (true) on first launch', () async {
    expect(await PosPrintingSettings.enabled(), isTrue);
  });

  test('PosPrintingSettings can be toggled and persists preference', () async {
    await PosPrintingSettings.setEnabled(false);
    expect(await PosPrintingSettings.enabled(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pos_printing_enabled'), isFalse);

    await PosPrintingSettings.setEnabled(true);
    expect(await PosPrintingSettings.enabled(), isTrue);
    expect(prefs.getBool('pos_printing_enabled'), isTrue);
  });

  test('PrintJobCoordinator.enqueueKot skips immediately when printing is disabled', () async {
    await PosPrintingSettings.setEnabled(false);
    final coordinator = PrintJobCoordinator();

    await coordinator.enqueueKot(
      orderId: 101,
      orderNumber: 'A-101',
      source: 'pos',
      cashierCheckout: true,
    );

    // No jobs enqueued, no failures generated
    expect(coordinator.pendingKotFailures, isEmpty);
    expect(coordinator.hasFailedJobs, isFalse);
  });

  test('PrintJobCoordinator.enqueueReceipt skips immediately when printing is disabled', () async {
    await PosPrintingSettings.setEnabled(false);
    final coordinator = PrintJobCoordinator();

    await coordinator.enqueueReceipt(
      orderId: 101,
      orderNumber: 'A-101',
    );

    expect(coordinator.hasFailedJobs, isFalse);
  });
}
