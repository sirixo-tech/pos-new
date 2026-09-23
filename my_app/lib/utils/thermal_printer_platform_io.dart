import 'dart:io' show Platform;

import '../l10n/pos_l10n.dart';

String _t(
  String key,
  String fallback, [
  Map<String, Object> replacements = const {},
]) {
  return PosTranslationStore.instance.text(
    key,
    fallback,
    replacements: replacements,
  );
}

/// Native desktop/mobile copy for ESC/POS printer setup and errors.
String thermalPrinterSetupTitle() =>
    _t('printerReceiptTitle', 'Receipt printer');

String thermalPrinterSetupHelp() {
  if (Platform.isMacOS) {
    return _t(
      'printerHelpMac',
      'Choose USB / system, LAN (IP:9100), or Bluetooth ESC/POS. '
          'macOS CUPS printers appear under USB — use a raw/ESC-POS queue when available.',
    );
  }
  if (Platform.isWindows) {
    return _t(
      'printerHelpWin',
      'Connect USB, enter a LAN printer IP (port 9100), or pair Bluetooth in Windows Settings, '
          'then select it below.',
    );
  }
  if (Platform.isIOS) {
    return _t(
      'printerHelpIos',
      'iOS supports Bluetooth or LAN (same Wi‑Fi) ESC/POS printers. '
          'For LAN, enter the printer IP and port 9100.',
    );
  }
  return _t(
    'printerHelpAndroid',
    'Use USB, LAN (IP:9100 on the same network), or Bluetooth for an ESC/POS printer. '
        'Allow USB / nearby devices when Android prompts.',
  );
}

String thermalPrinterEmptyMessage({bool bluetooth = false}) {
  if (bluetooth) {
    return _t(
      'printerEmptyBt',
      'No Bluetooth printers found. Pair the printer in system Bluetooth settings, allow Nearby devices / Bluetooth when prompted, then Scan again.',
    );
  }
  return _t('printerEmptyUsb', 'No USB / system printers found.');
}

String thermalPrinterMissingMessage() =>
    _t('printerMissing', 'No receipt printer selected.');

String thermalPrinterConnectError(String name, {bool bluetooth = false}) {
  if (bluetooth) {
    return _t(
      'printerConnectBt',
      'Could not connect to Bluetooth printer "{name}". Keep the printer powered on and nearby, then try again.',
      {'name': name},
    );
  }
  if (Platform.isMacOS) {
    return _t(
      'printerConnectMac',
      'Could not print to "{name}". Confirm the printer is online in System Settings and supports raw ESC/POS via CUPS.',
      {'name': name},
    );
  }
  return _t(
    'printerConnectUsb',
    'Could not connect to USB printer "{name}". Unplug and replug the printer, then try again.',
    {'name': name},
  );
}

String thermalPrinterConnectNetworkError(String name, String endpoint) {
  return _t(
    'printerConnectLan',
    'Could not reach LAN printer "{name}" at {endpoint}. Check power, Wi‑Fi/Ethernet, and that raw TCP port 9100 is open.',
    {'name': name, 'endpoint': endpoint},
  );
}

String thermalPrinterPairingButtonLabel() =>
    _t('printerReceiptTitle', 'Receipt printer');

String thermalPrinterUnsupportedMessage() => '';

String thermalPrinterNeedsSystemQueueMessage() => _t(
      'printerNeedsSystemQueue',
      'Detected on USB only — add this printer in System Settings → Printers & Scanners, then refresh.',
    );
