import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/printer_manager.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:http/http.dart' as http;

import '../../models/pos_models.dart';
import '../../utils/thermal_printer_platform.dart';
import '../offline/pending_order.dart';
import '../pos_api.dart';
import 'esc_pos_builder.dart';
import 'macos_usb_discovery.dart';
import 'network_printer.dart';
import 'offline_receipt_builder.dart';
import 'pos_channel_print_policy.dart';
import 'printer_paper_sensor.dart';
import 'pos_print_payload_filter.dart';
import 'print_object_executor.dart';
import 'print_skipped.dart';
import 'printer_health.dart';
import 'receipt_typography.dart';
import 'thermal_text_encoder.dart';
import 'usb_printer_config.dart';

/// Native Android / macOS / Windows / iOS — ESC/POS via USB, CUPS, Bluetooth, or LAN.
class PosReceiptPrinter {
  PosReceiptPrinter._();

  static final FlutterThermalPrinter _thermal = FlutterThermalPrinter.instance;
  static const _thermalChannel = MethodChannel('flutter_thermal_printer');
  static const _smartPosChannel = MethodChannel('pos_main/smartpos_printer');
  static const _bluetoothChannel = MethodChannel('pos_main/bluetooth');

  static bool get isSupported => true;

  static String get unsupportedMessage => thermalPrinterUnsupportedMessage();

  /// Open USB/BLE transport ahead of the first ticket so checkout is not delayed.
  static Future<void> warmUp() async {
    try {
      final config = await UsbPrinterStorage.load();
      if (config == null) return;
      await probe();
      if (config.connection == PosPrinterConnection.network) {
        return;
      }
      if (config.connection == PosPrinterConnection.smartpos) {
        if (Platform.isAndroid) {
          await _smartPosChannel.invokeMethod<bool>('warmUpPrinter');
        }
        return;
      }
      final printer = await _resolveSavedPrinter();
      if (printer == null) return;
      await _ensureThermalConnected(printer);
    } catch (e) {
      debugPrint('[PRINT] warmUp skipped: $e');
    }
  }

  static bool get supportsBluetooth {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return true;
    }
    // Windows BLE support exists in the plugin but is less reliable for ESC/POS.
    return Platform.isWindows;
  }

  static Future<List<UsbPrinterDevice>> listUsbPrinters() async {
    if (Platform.isMacOS) {
      final native = await MacosUsbDiscovery.listDevices();
      if (native.isNotEmpty) {
        return native;
      }
      return _listViaThermalPluginChannel();
    }

    final printers = await _fetchPrinters(ConnectionType.USB);
    return printers.map(_toDevice).toList();
  }

  static Future<List<UsbPrinterDevice>> _listViaThermalPluginChannel() async {
    try {
      final result =
          await _thermalChannel.invokeMethod<List<dynamic>>('getUsbDevicesList');
      if (result == null) {
        return [];
      }

      return result.map((entry) {
        final map = Map<String, dynamic>.from(entry as Map);
        final name = map['name']?.toString() ?? 'Printer';
        final productId = map['productId']?.toString() ?? '';
        final vendorId = map['vendorId']?.toString() ?? '';
        return UsbPrinterDevice(
          name: name,
          address: productId.isNotEmpty && productId != 'N/A'
              ? productId
              : vendorId,
          connection: PosPrinterConnection.usb,
          printable: true,
          source: 'cups',
        );
      }).toList();
    } catch (e, st) {
      debugPrint('Thermal plugin printer list failed: $e\n$st');
      return [];
    }
  }

  static Future<List<UsbPrinterDevice>> listBluetoothPrinters() async {
    if (!supportsBluetooth) return [];
    await ensureBluetoothPermissions();
    final printers = await _fetchPrinters(
      ConnectionType.BLE,
      timeout: const Duration(seconds: 12),
    );
    return printers.map(_toDevice).toList();
  }

  /// Prompt Android for Nearby devices / Bluetooth so BLE scan can start.
  static Future<void> ensureBluetoothPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final granted =
          await _bluetoothChannel.invokeMethod<bool>('ensurePermissions');
      if (granted == true) return;
    } on MissingPluginException {
      return;
    } catch (e) {
      debugPrint('[PRINT] bluetooth permission request failed: $e');
      return;
    }
    throw StateError(
      'Bluetooth permission denied. Allow Nearby devices / Bluetooth, then Scan again.',
    );
  }

  static Future<void> stopBluetoothScan() async {
    try {
      await _thermal.stopScan();
    } catch (_) {
      // Best-effort — scan may already be stopped.
    }
  }

  static UsbPrinterDevice _toDevice(Printer printer) {
    final isBle = printer.connectionType == ConnectionType.BLE;
    return UsbPrinterDevice(
      name: printer.name ?? 'Receipt printer',
      address: _printerAddress(printer),
      connection:
          isBle ? PosPrinterConnection.bluetooth : PosPrinterConnection.usb,
      printable: true,
      source: isBle ? 'bluetooth' : 'usb',
    );
  }

  /// Soft health check. Paper state comes only from the printer's paper-end
  /// sensor (or the driver's paper-empty bit). Estimated roll length is not used.
  static Future<PrinterHealth> probe({bool allowBluetoothScan = false}) {
    return _probeDevice(allowBluetoothScan: allowBluetoothScan);
  }

  static Printer? _lastResolvedPrinter;
  static bool bleLinkIsLive = false;

  static Future<PrinterHealth> _probeDevice({
    bool allowBluetoothScan = false,
  }) async {
    final checkedAt = DateTime.now();
    if (!isSupported) {
      return PrinterHealth(
        state: PrinterHealthState.unsupported,
        message: unsupportedMessage,
        lastCheckedAt: checkedAt,
      );
    }

    final config = await UsbPrinterStorage.load();
    if (config == null || config.name.trim().isEmpty) {
      return PrinterHealth(
        state: PrinterHealthState.none,
        message: thermalPrinterMissingMessage(),
        lastCheckedAt: checkedAt,
      );
    }

    if (config.connection == PosPrinterConnection.smartpos) {
      return _probeSmartPos(config, checkedAt);
    }

    if (config.connection == PosPrinterConnection.bluetooth) {
      return _probeBluetooth(
        config,
        checkedAt,
        allowScan: allowBluetoothScan,
      );
    }

    if (config.connection == PosPrinterConnection.network) {
      final host = (config.host ?? '').trim();
      if (host.isEmpty) {
        return PrinterHealth(
          state: PrinterHealthState.none,
          config: config,
          message: thermalPrinterMissingMessage(),
          lastCheckedAt: checkedAt,
        );
      }
      try {
        await NetworkPrinter.probe(
          host,
          config.port,
          timeout: const Duration(milliseconds: 1500),
        );
        return PrinterHealth(
          state: PrinterHealthState.ready,
          config: config,
          message: 'Ready · ${config.networkEndpoint}',
          lastCheckedAt: checkedAt,
        );
      } catch (e) {
        return PrinterHealth(
          state: PrinterHealthState.missing,
          config: config,
          message: thermalPrinterConnectNetworkError(
            config.name,
            config.networkEndpoint,
          ),
          issues: const ['offline', 'missing'],
          lastCheckedAt: checkedAt,
        );
      }
    }

    final device = await _findMappedDevice(config);
    if (device == null) {
      return PrinterHealth(
        state: PrinterHealthState.missing,
        config: config,
        message: thermalPrinterConnectError(config.name),
        issues: const ['missing'],
        lastCheckedAt: checkedAt,
      );
    }

    if (!device.printable) {
      return PrinterHealth(
        state: PrinterHealthState.notPrintable,
        config: config,
        device: device,
        message: thermalPrinterNeedsSystemQueueMessage(),
        issues: const ['attention'],
        lastCheckedAt: checkedAt,
      );
    }

    var issues = List<String>.from(device.issues);
    var cupsState = device.cupsState;
    var statusMessage = device.statusMessage;

    if (Platform.isMacOS &&
        (device.source == 'cups' || config.source == 'cups')) {
      final queue =
          device.address.trim().isNotEmpty ? device.address : device.name;
      final status = await MacosUsbDiscovery.getPrinterStatus(queue);
      if (status != null) {
        final found = status['found'] == true;
        if (!found) {
          return PrinterHealth(
            state: PrinterHealthState.missing,
            config: config,
            device: device,
            message: status['message']?.toString() ??
                thermalPrinterConnectError(config.name),
            issues: const ['missing'],
            lastCheckedAt: checkedAt,
          );
        }
        cupsState = status['state']?.toString() ?? cupsState;
        issues = (status['issues'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
        statusMessage = status['message']?.toString() ?? statusMessage;
      }
    }

    if (issues.isNotEmpty) {
      return PrinterHealth(
        state: PrinterHealthState.attention,
        config: config,
        device: device,
        cupsState: cupsState,
        issues: issues,
        message: statusMessage ?? PrinterHealth.messageForIssues(issues),
        lastCheckedAt: checkedAt,
      );
    }

    return PrinterHealth(
      state: PrinterHealthState.ready,
      config: config,
      device: device,
      cupsState: cupsState,
      message: statusMessage ?? 'Ready',
      lastCheckedAt: checkedAt,
    );
  }

  static Future<PrinterHealth> _probeSmartPos(
    UsbPrinterConfig config,
    DateTime checkedAt,
  ) async {
    if (!Platform.isAndroid) {
      return PrinterHealth(
        state: PrinterHealthState.missing,
        config: config,
        message:
            'Built-in printer is available on Android SmartPOS / iMin terminals',
        issues: const ['missing'],
        lastCheckedAt: checkedAt,
      );
    }
    try {
      final status =
          (await _smartPosChannel.invokeMethod<String>('getPrinterStatus') ??
                  '')
              .trim()
              .toLowerCase();
      return switch (status) {
        'ready' || 'printing' => PrinterHealth(
            state: PrinterHealthState.ready,
            config: config,
            message: status == 'printing' ? 'Printing' : 'Ready',
            lastCheckedAt: checkedAt,
          ),
        'paperout' => PrinterHealth(
            state: PrinterHealthState.ready,
            config: config,
            message: 'Ready',
            lastCheckedAt: checkedAt,
          ),
        'overheated' => PrinterHealth(
            state: PrinterHealthState.attention,
            config: config,
            message: 'Built-in printer is overheated. Allow it to cool.',
            issues: const ['offline'],
            lastCheckedAt: checkedAt,
          ),
        _ => PrinterHealth(
            state: PrinterHealthState.missing,
            config: config,
            message:
                'Built-in printer is not ready. Open Printer setup → Built-in, then Test print.',
            issues: const ['offline', 'missing'],
            lastCheckedAt: checkedAt,
          ),
      };
    } catch (e) {
      return PrinterHealth(
        state: PrinterHealthState.missing,
        config: config,
        message: e.toString(),
        issues: const ['offline', 'missing'],
        lastCheckedAt: checkedAt,
      );
    }
  }

  static PrinterHealth _disconnectedHealth(
    UsbPrinterConfig config,
    DateTime checkedAt, {
    required bool bluetooth,
  }) {
    return PrinterHealth(
      state: PrinterHealthState.missing,
      config: config,
      message: thermalPrinterConnectError(config.name, bluetooth: bluetooth),
      issues: const ['offline', 'missing'],
      lastCheckedAt: checkedAt,
    );
  }

  static Future<PrinterHealth> _probeBluetooth(
    UsbPrinterConfig config,
    DateTime checkedAt, {
    required bool allowScan,
  }) async {
    final cached = _lastResolvedPrinter;
    if (cached != null && _matchesSavedPrinter(cached, config)) {
      try {
        if (await PrinterManager.instance.isConnected(cached)) {
          bleLinkIsLive = true;
          return PrinterHealth(
            state: PrinterHealthState.ready,
            config: config,
            message: 'Ready',
            lastCheckedAt: checkedAt,
          );
        }
      } catch (_) {}
    }

    if (!allowScan) {
      if (bleLinkIsLive) {
        bleLinkIsLive = false;
        return _disconnectedHealth(config, checkedAt, bluetooth: true);
      }
      // Idle BLE with no live GATT session: keep last scan result in
      // PrinterStatusService. Report missing only as a hint for first probe.
      return _disconnectedHealth(config, checkedAt, bluetooth: true);
    }

    final printer = await _resolveSavedPrinter();
    if (printer == null) {
      bleLinkIsLive = false;
      return _disconnectedHealth(config, checkedAt, bluetooth: true);
    }
    _lastResolvedPrinter = printer;
    try {
      if (await PrinterManager.instance.isConnected(printer)) {
        bleLinkIsLive = true;
      }
    } catch (_) {}
    return PrinterHealth(
      state: PrinterHealthState.ready,
      config: config,
      message: 'Ready',
      lastCheckedAt: checkedAt,
    );
  }

  /// Short ESC/POS slip — no order API required.
  static Future<PrinterHealth> printTestPage({
    String? restaurantName,
    String? branchName,
    String? terminalName,
  }) async {
    final health = await probe();
    final config = health.config ?? await UsbPrinterStorage.load();
    if (config == null) {
      return health;
    }

    // LAN: still attempt a test send even if the soft TCP probe failed.
    final networkReady = config.connection == PosPrinterConnection.network &&
        (config.host ?? '').trim().isNotEmpty;
    if (!health.canTestPrint && !networkReady) {
      return health;
    }

    try {
      final bytes = _buildTestPrintBytes(
        restaurantName: restaurantName,
        branchName: branchName,
        terminalName: terminalName,
        printerName: health.displayName,
      );
      await _dispatchPrintBytes(config: config, bytes: bytes);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      final after = await probe();

      if (!after.hasIssue) {
        return after.copyWith(
          message: 'Test print sent',
          jobSubmitted: true,
          lastCheckedAt: DateTime.now(),
        );
      }

      final detail = after.message?.trim();
      return after.copyWith(
        jobSubmitted: true,
        message: (detail == null || detail.isEmpty || detail == 'Ready')
            ? 'Test print was queued, but the printer is not ready.'
            : 'Test print was queued, but $detail',
        lastCheckedAt: DateTime.now(),
      );
    } catch (e) {
      final raw = e.toString().replaceFirst('Bad state: ', '');
      final issues = PrinterHealth.issuesFromErrorMessage(raw);

      try {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final after = await probe();
        if (after.hasIssue) {
          return after.copyWith(
            state: after.state == PrinterHealthState.ready
                ? PrinterHealthState.error
                : after.state,
            issues: after.issues.isNotEmpty ? after.issues : issues,
            message: after.message ??
                PrinterHealth.messageForIssues(issues, fallback: raw),
            jobSubmitted: false,
            lastCheckedAt: DateTime.now(),
          );
        }
      } catch (_) {}

      return PrinterHealth(
        state: PrinterHealthState.error,
        config: config,
        device: health.device,
        cupsState: health.cupsState,
        issues: issues,
        message: PrinterHealth.messageForIssues(issues, fallback: raw),
        lastCheckedAt: DateTime.now(),
        jobSubmitted: false,
      );
    }
  }

  static List<int> _buildTestPrintBytes({
    String? restaurantName,
    String? branchName,
    String? terminalName,
    required String printerName,
  }) {
    final builder = EscPosBuilder(
      typography: ReceiptTypography(receiptWidth: '80mm', fontSize: 'normal'),
      enableCurrencyGlyphs: false,
    );
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    builder.initialize();
    builder.alignCenter();
    builder.applyBlockStyle('title');
    builder.text('TEST PRINT');
    builder.clearBlockStyle('title');
    builder.blankLine();
    builder.alignLeft();
    if (restaurantName != null && restaurantName.trim().isNotEmpty) {
      builder.text(restaurantName.trim());
    }
    if (branchName != null && branchName.trim().isNotEmpty) {
      builder.text(branchName.trim());
    }
    if (terminalName != null && terminalName.trim().isNotEmpty) {
      builder.text('Terminal: ${terminalName.trim()}');
    }
    builder.text('Printer: $printerName');
    builder.text(stamp);
    builder.blankLine();
    builder.alignCenter();
    builder.text('If you can read this,');
    builder.text('the POS printer is working.');
    builder.feed(3);
    builder.cut();
    return builder.build();
  }

  static Future<void> printReceipt({
    required PosSession session,
    required String serverUrl,
    required int orderId,
    String? orderNumber,
  }) async {
    final config = await UsbPrinterStorage.load();
    if (config == null) {
      throw StateError(thermalPrinterMissingMessage());
    }

    final bytes = await _buildReceiptBytesFromServer(
      session: session,
      serverUrl: serverUrl,
      orderId: orderId,
    );

    if (bytes.isEmpty) {
      throw const PrintSkipped('Receipt has no printable content.');
    }

    await _dispatchPrintBytes(config: config, bytes: bytes);
  }

  /// Reprint by scanned order number (USB wedge / QR).
  static Future<void> printOrderByNumber({
    required PosSession session,
    required String orderNumber,
    bool handoff = false,
  }) async {
    final config = await UsbPrinterStorage.load();
    if (config == null) {
      throw StateError(thermalPrinterMissingMessage());
    }

    final data = await PosApi().fetchReceiptByOrderNumber(
      session,
      orderNumber: orderNumber,
      handoff: handoff,
    );
    final filtered = PosPrintPayloadFilter.forReceipt(
      _printPayloadFrom(data),
      PosChannelPrintPolicy.resolve(),
    );
    if (filtered == null) {
      throw const PrintSkipped(
        'Customer and counter receipts are disabled for POS.',
      );
    }

    final executor = PrintObjectExecutor.fromPayload(filtered);
    final bytes = await executor.buildBytes(
      PrintObjectExecutor.commandsFromPayload(filtered),
    );
    if (bytes.isEmpty) {
      throw const PrintSkipped('Receipt has no printable content.');
    }

    await _dispatchPrintBytes(config: config, bytes: bytes);
  }

  /// Print kitchen KOT slips on the POS local thermal (one slip per kitchen).
  static Future<int> printKotByOrderNumber({
    required PosSession session,
    required String orderNumber,
  }) async {
    final config = await UsbPrinterStorage.load();
    if (config == null) {
      throw StateError(thermalPrinterMissingMessage());
    }

    Map<String, dynamic> data;
    try {
      data = await PosApi().fetchKotByOrderNumber(
        session,
        orderNumber: orderNumber,
      );
    } on PosApiException catch (error) {
      if (error.isPrintingDisabled) {
        throw PrintSkipped(error.message);
      }
      rethrow;
    }
    final slips = data['slips'];
    if (slips is! List || slips.isEmpty) {
      throw StateError('No KOT slips to print.');
    }

    var printed = 0;
    final policy = PosChannelPrintPolicy.resolve();
    for (final entry in slips) {
      if (entry is! Map) continue;
      final slip = Map<String, dynamic>.from(entry);
      final payload = PosPrintPayloadFilter.forKot(
        _printPayloadFrom(slip),
        policy,
      );
      if (payload == null) continue;

      final executor = PrintObjectExecutor.fromPayload(payload);
      final bytes = await executor.buildBytes(
        PrintObjectExecutor.commandsFromPayload(payload),
      );
      if (bytes.isEmpty) continue;

      await _dispatchPrintBytes(config: config, bytes: bytes);
      printed++;
    }

    if (printed == 0) {
      throw StateError('KOT has no printable content.');
    }

    return printed;
  }

  static Future<void> printOfflineReceipt({
    required PosBootstrap bootstrap,
    required PendingOrder order,
  }) async {
    final config = await UsbPrinterStorage.load();
    if (config == null) {
      throw StateError(thermalPrinterMissingMessage());
    }

    final bytes = await _buildOfflineReceiptBytes(
      bootstrap: bootstrap,
      order: order,
    );

    if (bytes.isEmpty) {
      throw StateError('Offline receipt has no printable content.');
    }

    await _dispatchPrintBytes(config: config, bytes: bytes);
  }

  static Future<void> printPaymentQrSlip({
    required PosSession session,
    required String serverUrl,
    required int orderId,
  }) async {
    final config = await UsbPrinterStorage.load();
    if (config == null) {
      throw StateError(thermalPrinterMissingMessage());
    }

    final bytes = await _buildPaymentQrBytesFromServer(
      session: session,
      serverUrl: serverUrl,
      orderId: orderId,
    );

    if (bytes.isEmpty) {
      throw StateError('Payment QR slip has no printable content.');
    }

    await _dispatchPrintBytes(config: config, bytes: bytes);
  }

  static Future<void> printThermalReport({
    required PosSession session,
    required String serverUrl,
    required String type,
    String? dateFrom,
    String? dateTo,
  }) async {
    final config = await UsbPrinterStorage.load();
    if (config == null) {
      throw StateError(thermalPrinterMissingMessage());
    }

    final bytes = await _buildThermalReportBytesFromServer(
      session: session,
      serverUrl: serverUrl,
      type: type,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    if (bytes.isEmpty) {
      throw StateError('Report has no printable content.');
    }

    await _dispatchPrintBytes(config: config, bytes: bytes);
  }

  static Future<void> openCashDrawer() async {
    final config = await UsbPrinterStorage.load();
    if (config == null) {
      throw StateError(thermalPrinterMissingMessage());
    }
    final builder = EscPosBuilder(
      typography: ReceiptTypography(receiptWidth: '80mm', fontSize: 'normal'),
      enableCurrencyGlyphs: false,
    );
    builder.initialize();
    builder.openDrawer();
    await _dispatchPrintBytes(config: config, bytes: builder.build());
  }

  static Map<String, dynamic> _printPayloadFrom(Map<String, dynamic> data) {
    final printObject = data['print_object'] ?? data['printObject'];
    if (printObject is Map) {
      return Map<String, dynamic>.from(printObject);
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<void> _dispatchPrintBytes({
    required UsbPrinterConfig config,
    required List<int> bytes,
  }) async {
    final payload = config.connection == PosPrinterConnection.smartpos
        ? ThermalTextEncoder.withoutUserDefinedChars(bytes)
        : bytes;
    await _sendPrintBytes(config: config, bytes: payload);
  }

  static Future<void> _sendSmartPosBytes(List<int> bytes) async {
    if (!Platform.isAndroid) {
      throw StateError(
        'Built-in printer is only available on Android SmartPOS / iMin terminals.',
      );
    }
    try {
      await _smartPosChannel.invokeMethod<int>(
        'printEscPos',
        Uint8List.fromList(bytes),
      );
      return;
    } on MissingPluginException {
      // Fall through to a local USB printer when the SDK is not bundled.
    } on PlatformException catch (error) {
      if (error.code != 'SMARTPOS_UNAVAILABLE') {
        throw StateError(
          error.message?.trim().isNotEmpty == true
              ? error.message!
              : 'Built-in printer failed (${error.code}).',
        );
      }
    }

    final usb = await listUsbPrinters();
    UsbPrinterDevice? device;
    for (final item in usb) {
      if (item.printable) {
        device = item;
        break;
      }
    }
    if (device == null) {
      throw StateError(
        'Built-in printer is unavailable. Connect USB or choose Bluetooth / LAN.',
      );
    }
    await _sendPrintBytes(
      config: UsbPrinterConfig(
        name: device.name,
        address: device.address,
        connection: PosPrinterConnection.usb,
        source: device.source,
      ),
      bytes: bytes,
    );
  }

  static Future<void> _sendPrintBytes({
    required UsbPrinterConfig config,
    required List<int> bytes,
  }) async {
    if (config.connection == PosPrinterConnection.smartpos) {
      await _sendSmartPosBytes(bytes);
      return;
    }

    if (config.connection == PosPrinterConnection.network) {
      final host = (config.host ?? '').trim();
      if (host.isEmpty) {
        throw StateError(thermalPrinterMissingMessage());
      }
      await NetworkPrinter.sendBytes(host, config.port, bytes);
      return;
    }

    if (Platform.isMacOS && config.connection == PosPrinterConnection.usb) {
      await _printBytesMacOS(config: config, bytes: bytes);
      return;
    }

    final saved = await _resolveSavedPrinter();
    if (saved == null) {
      throw StateError(
        thermalPrinterConnectError(
          config.name,
          bluetooth: config.connection == PosPrinterConnection.bluetooth,
        ),
      );
    }

    await _ensureThermalConnected(saved);
    await _thermal.printData(saved, bytes, longData: true);
  }

  static Future<void> _printBytesMacOS({
    required UsbPrinterConfig config,
    required List<int> bytes,
  }) async {
    final device = await _findMappedDevice(config);
    if (device == null) {
      throw StateError(thermalPrinterConnectError(config.name));
    }

    final source =
        device.source == 'cups' || config.source == 'cups' ? 'cups' : device.source;
    if (device.printable && source == 'cups') {
      final queueName =
          device.address.trim().isNotEmpty ? device.address : device.name;
      await MacosUsbDiscovery.printRawBytes(queueName: queueName, bytes: bytes);
      return;
    }

    if (!device.printable) {
      throw StateError(thermalPrinterNeedsSystemQueueMessage());
    }

    final printer = await _resolveSavedPrinter();
    if (printer == null) {
      throw StateError(thermalPrinterConnectError(config.name));
    }

    await _ensureThermalConnected(printer);
    await _thermal.printData(printer, bytes, longData: true);
  }

  static Future<UsbPrinterDevice?> _findMappedDevice(
    UsbPrinterConfig config,
  ) async {
    final devices = await listUsbPrinters();
    if (devices.isEmpty) {
      return null;
    }

    final targetName = config.name.trim().toLowerCase();
    final targetAddress = config.address.trim();

    for (final device in devices) {
      if (device.name.trim().toLowerCase() != targetName) {
        continue;
      }
      if (targetAddress.isEmpty || device.address == targetAddress) {
        return device;
      }
    }

    for (final device in devices) {
      if (device.name.trim().toLowerCase() == targetName) {
        return device;
      }
    }

    return null;
  }

  /// Ensure the plugin has an open transport to [printer].
  ///
  /// Android USB: plugin `connect` often returns `false` — poll until permission
  /// is granted. Bluetooth: wait for a real BLE connection with a longer timeout.
  static Future<void> _ensureThermalConnected(Printer printer) async {
    final isBle = printer.connectionType == ConnectionType.BLE;

    if (Platform.isWindows && !isBle) {
      return;
    }

    final manager = PrinterManager.instance;
    if (await manager.isConnected(printer)) {
      _lastResolvedPrinter = printer;
      bleLinkIsLive = true;
      return;
    }

    // Stop any active BLE scan so connect is not starved on Android/iOS.
    if (isBle) {
      await stopBluetoothScan();
    }

    final connected = await _thermal.connect(
      printer,
      connectionStabilizationDelay:
          isBle ? const Duration(seconds: 12) : null,
    );

    if (connected || await manager.isConnected(printer)) {
      _lastResolvedPrinter = printer;
      bleLinkIsLive = true;
      return;
    }

    final pollSeconds = isBle
        ? 15
        : (Platform.isAndroid ? 20 : 0);
    if (pollSeconds > 0) {
      final deadline = DateTime.now().add(Duration(seconds: pollSeconds));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (await manager.isConnected(printer)) {
          _lastResolvedPrinter = printer;
          bleLinkIsLive = true;
          return;
        }
      }
    }

    throw StateError(
      thermalPrinterConnectError(
        printer.name ?? 'Receipt printer',
        bluetooth: isBle,
      ),
    );
  }

  static Future<List<int>> _buildPaymentQrBytesFromServer({
    required PosSession session,
    required String serverUrl,
    required int orderId,
  }) async {
    final uri = Uri.parse('$serverUrl/api/v1/pos/orders/$orderId/payment/qr/print');
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${session.token}',
        'X-Restaurant-Id': '${session.restaurantId}',
        'X-Branch-Id': '${session.branchId}',
      },
    );

    if (response.statusCode != 200) {
      throw StateError('Failed to fetch payment QR slip (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final printObject = data;

    final executor = PrintObjectExecutor.fromPayload(printObject);
    return executor.buildBytes(PrintObjectExecutor.commandsFromPayload(printObject));
  }

  static Future<List<int>> _buildThermalReportBytesFromServer({
    required PosSession session,
    required String serverUrl,
    required String type,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{'type': type};
    if (dateFrom != null && dateFrom.isNotEmpty) {
      params['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      params['date_to'] = dateTo;
    }

    final uri = Uri.parse('$serverUrl/api/v1/pos/reports/thermal-print')
        .replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${session.token}',
        'X-Restaurant-Id': '${session.restaurantId}',
        'X-Branch-Id': '${session.branchId}',
      },
    );

    Map<String, dynamic>? body;
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    }

    if (response.statusCode != 200) {
      final message = body?['message'] as String? ??
          'Failed to fetch report (${response.statusCode})';
      throw StateError(message);
    }

    final data = body?['data'] as Map<String, dynamic>? ?? body ?? const {};
    final commands = PrintObjectExecutor.commandsFromPayload(data);
    if (commands.isEmpty) {
      throw StateError('Report has no printable content.');
    }

    final executor = PrintObjectExecutor.fromPayload(data);
    return executor.buildBytes(commands);
  }

  static Future<List<int>> _buildReceiptBytesFromServer({
    required PosSession session,
    required String serverUrl,
    required int orderId,
  }) async {
    try {
      final data = await PosApi().fetchReceipt(session, orderId: orderId);
      final filtered = PosPrintPayloadFilter.forReceipt(
        _printPayloadFrom(data),
        PosChannelPrintPolicy.resolve(),
      );
      if (filtered == null) {
        throw const PrintSkipped(
          'Customer and counter receipts are disabled for POS.',
        );
      }
      final executor = PrintObjectExecutor.fromPayload(filtered);
      return executor.buildBytes(
        PrintObjectExecutor.commandsFromPayload(filtered),
      );
    } on PosApiException catch (error) {
      if (error.isPrintingDisabled) {
        throw PrintSkipped(error.message);
      }
      rethrow;
    }
  }

  static Future<List<int>> _buildOfflineReceiptBytes({
    required PosBootstrap bootstrap,
    required PendingOrder order,
  }) async {
    return OfflineReceiptBuilder.buildBytes(
      bootstrap: bootstrap,
      order: order,
    );
  }

  static Future<List<Printer>> _fetchPrinters(
    ConnectionType type, {
    Duration timeout = const Duration(seconds: 4),
    bool androidUsesFineLocation = false,
    bool Function(List<Printer> devices)? earlyComplete,
  }) async {
    final completer = Completer<List<Printer>>();
    StreamSubscription<List<Printer>>? subscription;
    var latest = <Printer>[];

    subscription = _thermal.devicesStream.listen((devices) {
      latest = devices.where((device) => device.connectionType == type).toList();
      if (completer.isCompleted) return;

      if (type == ConnectionType.USB && latest.isNotEmpty) {
        completer.complete(List<Printer>.from(latest));
        return;
      }

      if (earlyComplete != null && earlyComplete(latest)) {
        completer.complete(List<Printer>.from(latest));
      }
    });

    try {
      if (type == ConnectionType.BLE) {
        await ensureBluetoothPermissions();
        try {
          await _thermal.turnOnBluetooth();
        } catch (_) {
          // User may decline; scan can still find already-on adapters.
        }
      }

      await _thermal.getPrinters(
        connectionTypes: [type],
        refreshDuration: type == ConnectionType.BLE
            ? const Duration(seconds: 8)
            : const Duration(seconds: 1),
        androidUsesFineLocation: androidUsesFineLocation,
      );

      if (type == ConnectionType.BLE && earlyComplete == null) {
        const slice = Duration(milliseconds: 250);
        var elapsed = Duration.zero;
        while (elapsed < timeout && !completer.isCompleted) {
          await Future<void>.delayed(slice);
          elapsed += slice;
          if (latest.isNotEmpty && elapsed >= const Duration(seconds: 3)) {
            break;
          }
        }
        return List<Printer>.from(latest);
      }

      return await completer.future.timeout(
        timeout,
        onTimeout: () => latest,
      );
    } finally {
      await subscription.cancel();
      if (type == ConnectionType.BLE) {
        await stopBluetoothScan();
      }
    }
  }

  /// One paper-end read at connect time. [PrinterPaperSensor.unknown] means
  /// this printer did not report a roll sensor — that is not a paper-out error.
  static Future<PrinterPaperSensor> readPaperSensor(
    UsbPrinterConfig config,
  ) async {
    try {
      switch (config.connection) {
        case PosPrinterConnection.smartpos:
          if (!Platform.isAndroid) return PrinterPaperSensor.unknown;
          final status = (await _smartPosChannel
                      .invokeMethod<String>('getPrinterStatus') ??
                  '')
              .trim()
              .toLowerCase();
          return switch (status) {
            'ready' || 'printing' => PrinterPaperSensor.present,
            'paperout' => PrinterPaperSensor.empty,
            _ => PrinterPaperSensor.unknown,
          };
        case PosPrinterConnection.network:
          final host = (config.host ?? '').trim();
          if (host.isEmpty) return PrinterPaperSensor.unknown;
          return NetworkPrinter.readPaperSensor(host, config.port);
        case PosPrinterConnection.usb:
          if (!Platform.isAndroid) return PrinterPaperSensor.unknown;
          return _androidUsbPaperSensor(config.address);
        case PosPrinterConnection.bluetooth:
          return PrinterPaperSensor.unknown;
      }
    } on Object {
      return PrinterPaperSensor.unknown;
    }
  }

  /// USB printer-class paper-empty bit. Unknown replies do not mean empty.
  static Future<PrinterPaperSensor> _androidUsbPaperSensor(String address) async {
    final parts = address.split(':');
    if (parts.length != 2 || parts[0].trim().isEmpty || parts[1].trim().isEmpty) {
      return PrinterPaperSensor.unknown;
    }
    try {
      final status = await _smartPosChannel.invokeMethod<int>(
        'getUsbPaperStatus',
        {'vendorId': parts[0].trim(), 'productId': parts[1].trim()},
      ).timeout(const Duration(seconds: 2));
      if (status == null) return PrinterPaperSensor.unknown;
      return decodeUsbPortPaperSensor(status);
    } on Object {
      return PrinterPaperSensor.unknown;
    }
  }

  static String _printerAddress(Printer printer) {
    final address = printer.address?.trim();
    if (address != null &&
        address.isNotEmpty &&
        address != 'N/A' &&
        printer.connectionType == ConnectionType.BLE) {
      return address;
    }

    final vendorId = printer.vendorId?.trim() ?? '';
    final productId = printer.productId?.trim() ?? '';
    if (vendorId.isNotEmpty &&
        vendorId != 'N/A' &&
        productId.isNotEmpty &&
        productId != 'N/A') {
      return '$vendorId:$productId';
    }

    if (address != null && address.isNotEmpty && address != 'N/A') {
      return address;
    }

    if (productId.isNotEmpty && productId != 'N/A') {
      return productId;
    }

    return vendorId;
  }

  static Future<Printer?> _resolveSavedPrinter() async {
    final config = await UsbPrinterStorage.load();
    if (config == null) {
      return null;
    }

    if (config.connection == PosPrinterConnection.smartpos ||
        config.connection == PosPrinterConnection.network) {
      return null;
    }

    final type = config.connection == PosPrinterConnection.bluetooth
        ? ConnectionType.BLE
        : ConnectionType.USB;

    final printers = await _fetchPrinters(
      type,
      timeout: type == ConnectionType.BLE
          ? const Duration(seconds: 8)
          : const Duration(seconds: 4),
      androidUsesFineLocation: false,
      earlyComplete: (devices) =>
          devices.any((p) => _matchesSavedPrinter(p, config)),
    );
    if (printers.isEmpty) return null;

    for (final printer in printers) {
      if (_matchesSavedPrinter(printer, config)) {
        _lastResolvedPrinter = printer;
        return printer;
      }
    }

    for (final printer in printers) {
      if (printer.name == config.name) {
        _lastResolvedPrinter = printer;
        return printer;
      }
    }

    // Never fall back to another printer.
    return null;
  }

  /// Match saved config to a live device (supports legacy address = vendorId only).
  static bool _matchesSavedPrinter(Printer printer, UsbPrinterConfig config) {
    final expectedType = config.connection == PosPrinterConnection.bluetooth
        ? ConnectionType.BLE
        : ConnectionType.USB;
    if (printer.connectionType != null &&
        printer.connectionType != expectedType) {
      return false;
    }

    final saved = config.address.trim();
    final current = _printerAddress(printer);

    // Bluetooth: address (MAC / device id) is the reliable key.
    if (config.connection == PosPrinterConnection.bluetooth) {
      if (saved.isNotEmpty && current.toLowerCase() == saved.toLowerCase()) {
        return true;
      }
      return printer.name == config.name &&
          (saved.isEmpty || current.toLowerCase() == saved.toLowerCase());
    }

    if (printer.name != config.name) {
      return false;
    }

    if (saved.isEmpty) {
      return true;
    }

    if (current == saved) {
      return true;
    }

    final vendorId = printer.vendorId?.trim() ?? '';
    final productId = printer.productId?.trim() ?? '';
    if (saved == vendorId || saved == productId) {
      return true;
    }

    if (saved.contains(':')) {
      final parts = saved.split(':');
      if (parts.length == 2 &&
          parts[0] == vendorId &&
          parts[1] == productId) {
        return true;
      }
    }

    return false;
  }
}
