import '../../models/pos_models.dart';

/// POS-channel gates for customer bills vs counter/token slips.
///
/// Matches Selfx checkout: auto KOT is independent. Receipt/token jobs print
/// only when the matching backend switch is on.
class PosChannelPrintPolicy {
  const PosChannelPrintPolicy({
    required this.customerReceipt,
    required this.counterReceipt,
  });

  static const disabled = PosChannelPrintPolicy(
    customerReceipt: false,
    counterReceipt: false,
  );

  final bool customerReceipt;
  final bool counterReceipt;

  bool get printsAnyReceiptJob => customerReceipt || counterReceipt;

  static PosChannelPrintPolicy Function()? lookup;

  static PosChannelPrintPolicy resolve() =>
      lookup?.call() ?? disabled;

  static PosChannelPrintPolicy fromBootstrap(PosBootstrap? bootstrap) {
    if (bootstrap == null) return disabled;
    return fromSettings(
      settings: bootstrap.receiptSettings,
      raw: bootstrap.receiptSettingsRaw,
      printMode: bootstrap.posReceiptPrintMode,
    );
  }

  static PosChannelPrintPolicy fromSettings({
    PosReceiptSettings? settings,
    Map<String, dynamic>? raw,
    String? printMode,
  }) {
    final parsed = settings ?? PosReceiptSettings.fromJson(raw);
    final data = raw ?? const <String, dynamic>{};
    final mode = (printMode ?? data['pos_receipt_print_mode'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (mode == 'none' ||
        mode == 'off' ||
        mode == 'disabled' ||
        mode == 'kot' ||
        mode == 'kot_only' ||
        mode == 'kitchen_only') {
      return const PosChannelPrintPolicy(
        customerReceipt: false,
        counterReceipt: false,
      );
    }

    return PosChannelPrintPolicy(
      customerReceipt: _customerEnabled(parsed, data),
      counterReceipt: _counterEnabled(parsed, data),
    );
  }

  static bool _customerEnabled(
    PosReceiptSettings settings,
    Map<String, dynamic> raw,
  ) {
    if (!settings.enabledForChannel('pos')) return false;
    if (raw.isEmpty) return true;

    if (_isFalse(raw['customer_receipt_enabled']) ||
        _isFalse(raw['enable_customer_receipt']) ||
        _isFalse(raw['customer_receipt']) ||
        _isFalse(raw['show_customer_receipt']) ||
        _isFalse(raw['print_customer_receipt']) ||
        _isFalse(raw['auto_print_customer_receipt']) ||
        _isFalse(raw['pos_customer_receipt'])) {
      return false;
    }

    final custReceipt = raw['customer_receipt'];
    if (custReceipt is Map && _isFalse(custReceipt['pos'])) return false;

    final custChannels =
        raw['customer_receipt_channels'] ?? raw['customerReceiptChannels'];
    if (custChannels is List && !_listHasPos(custChannels)) return false;

    final whereToPrint = raw['where_to_print'] ?? raw['whereToPrint'];
    if (whereToPrint is Map) {
      final posSetting = whereToPrint['pos'];
      if (posSetting is Map && _isFalse(posSetting['customer_receipt'])) {
        return false;
      }
      final custReceiptChannel = whereToPrint['customer_receipt'];
      if (custReceiptChannel is List && !_listHasPos(custReceiptChannel)) {
        return false;
      }
    }
    return true;
  }

  static bool _counterEnabled(
    PosReceiptSettings settings,
    Map<String, dynamic> raw,
  ) {
    if (settings.token.enabledForChannel('pos')) return true;
    if (raw.isEmpty) return false;

    if (_isTrue(raw['counter_receipt_enabled']) ||
        _isTrue(raw['enable_counter_receipt']) ||
        _isTrue(raw['counter_receipt']) ||
        _isTrue(raw['print_counter_receipt']) ||
        _isTrue(raw['auto_print_counter_receipt']) ||
        _isTrue(raw['pos_counter_receipt'])) {
      return true;
    }

    final counterReceipt = raw['counter_receipt'];
    if (counterReceipt is Map && _isTrue(counterReceipt['pos'])) return true;

    final counterChannels =
        raw['counter_receipt_channels'] ?? raw['counterReceiptChannels'];
    if (counterChannels is List && _listHasPos(counterChannels)) return true;

    final whereToPrint = raw['where_to_print'] ?? raw['whereToPrint'];
    if (whereToPrint is Map) {
      final posSetting = whereToPrint['pos'];
      if (posSetting is Map && _isTrue(posSetting['counter_receipt'])) {
        return true;
      }
      final counterReceiptChannel = whereToPrint['counter_receipt'];
      if (counterReceiptChannel is List && _listHasPos(counterReceiptChannel)) {
        return true;
      }
    }
    return false;
  }

  static bool _listHasPos(List<dynamic> values) {
    return values
        .map((e) => '$e'.toLowerCase().trim())
        .contains('pos');
  }

  static bool _isFalse(dynamic value) => value == false;

  static bool _isTrue(dynamic value) => value == true;
}
