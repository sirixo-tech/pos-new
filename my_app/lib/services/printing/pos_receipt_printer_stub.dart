import 'dart:async';

import '../../models/pos_models.dart';
import '../offline/pending_order.dart';
import 'printer_health.dart';
import 'printer_paper_sensor.dart';
import 'usb_printer_config.dart';

/// Web stub — printing is unavailable.
class PosReceiptPrinter {
  PosReceiptPrinter._();

  static bool get isSupported => false;

  static bool get supportsBluetooth => false;

  static bool get bleLinkIsLive => false;

  static String get unsupportedMessage =>
      'ESC/POS receipt printing is not available in the browser.';

  static Future<List<UsbPrinterDevice>> listUsbPrinters() async {
    return [];
  }

  static Future<List<UsbPrinterDevice>> listBluetoothPrinters() async {
    return [];
  }

  static Future<void> stopBluetoothScan() async {}

  static StreamSubscription<dynamic>? watchUsbHardware(void Function() onChange) {
    return null;
  }

  static Future<void> warmUp() async {}

  static Future<PrinterPaperSensor> readPaperSensor(
    UsbPrinterConfig config,
  ) async =>
      PrinterPaperSensor.unknown;

  static Future<PrinterHealth> probe({bool allowBluetoothScan = false}) async =>
      PrinterHealth(
        state: PrinterHealthState.unsupported,
        message: unsupportedMessage,
        lastCheckedAt: DateTime.now(),
      );

  static Future<PrinterHealth> printTestPage({
    String? restaurantName,
    String? branchName,
    String? terminalName,
  }) async =>
      probe();

  static Future<void> printReceipt({
    required PosSession session,
    required String serverUrl,
    required int orderId,
    String? orderNumber,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  static Future<void> printOrderByNumber({
    required PosSession session,
    required String orderNumber,
    bool handoff = false,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  static Future<int> printKotByOrderNumber({
    required PosSession session,
    required String orderNumber,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  static Future<void> printOfflineReceipt({
    required PosBootstrap bootstrap,
    required PendingOrder order,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  static Future<void> printOfflineKot({
    required PosBootstrap bootstrap,
    required PendingOrder order,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  static Future<void> printPaymentQrSlip({
    required PosSession session,
    required String serverUrl,
    required int orderId,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  static Future<void> printThermalReport({
    required PosSession session,
    required String serverUrl,
    required String type,
    String? dateFrom,
    String? dateTo,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  static Future<void> openCashDrawer() async {
    throw UnsupportedError(unsupportedMessage);
  }
}
