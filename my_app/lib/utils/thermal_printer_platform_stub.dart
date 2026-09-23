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

/// Web — thermal ESC/POS printing is unavailable.
String thermalPrinterSetupTitle() =>
    _t('printerReceiptTitle', 'Receipt printer');

String thermalPrinterSetupHelp() => _t(
      'printerUnsupportedWeb',
      'ESC/POS receipt printing is not available in the browser. '
          'Run the native POS app on Android, iOS, macOS, or Windows.',
    );

String thermalPrinterEmptyMessage({bool bluetooth = false}) =>
    _t('printerEmptyWeb', 'Printing is not supported in the browser.');

String thermalPrinterMissingMessage() =>
    _t('printerMissingWeb', 'Receipt printing requires the native POS app.');

String thermalPrinterConnectError(String name, {bool bluetooth = false}) => _t(
      'printerConnectWeb',
      'Could not print to "{name}" in the browser. Run the native POS app with a USB or Bluetooth thermal printer.',
      {'name': name},
    );

String thermalPrinterConnectNetworkError(String name, String endpoint) => _t(
      'printerConnectWeb',
      'Could not print to "{name}" in the browser. Run the native POS app with a USB, LAN, or Bluetooth thermal printer.',
      {'name': name},
    );

String thermalPrinterPairingButtonLabel() =>
    _t('printerReceiptTitle', 'Receipt printer');

String thermalPrinterUnsupportedMessage() => _t(
      'printerUnsupportedWeb',
      'ESC/POS receipt printing is not available in the browser. '
          'Run the native POS app on Android, iOS, macOS, or Windows.',
    );

String thermalPrinterNeedsSystemQueueMessage() => '';
