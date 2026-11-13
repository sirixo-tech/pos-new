/// Restaurant weighing settings from POS bootstrap (`restaurant.weighing`).
class WeighingSettings {
  const WeighingSettings({
    this.enabled = false,
    this.barcodeFormat = 'ean13',
    this.prefix = '20',
    this.pluDigits = 5,
    this.valueDigits = 5,
    this.payload = 'weight',
    this.priceDecimals = 2,
    this.labelWidthMm = 50,
    this.labelHeightMm = 38,
    this.labelShowRestaurant = true,
    this.labelShowDate = true,
    this.autoPrintOnStable = false,
  });

  final bool enabled;

  /// `ean13` or `custom`. Custom labels have no check digit.
  final String barcodeFormat;
  final String prefix;

  /// Used when [barcodeFormat] is `custom`. EAN-13 derives the PLU width from the prefix.
  final int pluDigits;

  /// Used when [barcodeFormat] is `custom`. EAN-13 always carries 5 value digits.
  final int valueDigits;
  final String payload;
  final int priceDecimals;
  final int labelWidthMm;
  final int labelHeightMm;
  final bool labelShowRestaurant;
  final bool labelShowDate;
  final bool autoPrintOnStable;

  bool get isCustom => barcodeFormat == 'custom';

  int get pluLength {
    if (isCustom) return pluDigits.clamp(1, 6);
    final digits = prefix.replaceAll(RegExp(r'\D'), '');
    return (7 - digits.length).clamp(1, 6);
  }

  int get valueLength => isCustom ? valueDigits.clamp(4, 6) : 5;

  int get barcodeLength {
    final digits = prefix.replaceAll(RegExp(r'\D'), '');
    if (isCustom) return digits.length + pluLength + valueLength;
    return 13;
  }

  factory WeighingSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WeighingSettings();
    final prefix = (json['prefix'] as String?)?.trim();
    final payload = (json['payload'] as String?)?.trim().toLowerCase();
    final format = (json['barcode_format'] as String?)?.trim().toLowerCase();
    final decimals = json['price_decimals'];
    final width = json['label_width_mm'];
    final height = json['label_height_mm'];
    return WeighingSettings(
      enabled: _weighingFlag(json['enabled']),
      barcodeFormat: format == 'custom' ? 'custom' : 'ean13',
      prefix: prefix != null && prefix.isNotEmpty ? prefix : '20',
      pluDigits: _boundedInt(json['plu_digits'], 1, 6, 5),
      valueDigits: _boundedInt(json['value_digits'], 4, 6, 5),
      payload: payload == 'price' ? 'price' : 'weight',
      priceDecimals: decimals is num ? decimals.toInt().clamp(0, 2) : 2,
      labelWidthMm: width is num ? width.toInt() : 50,
      labelHeightMm: height is num ? height.toInt() : 38,
      labelShowRestaurant: json.containsKey('label_show_restaurant')
          ? _weighingFlag(json['label_show_restaurant'])
          : true,
      labelShowDate: json.containsKey('label_show_date')
          ? _weighingFlag(json['label_show_date'])
          : true,
      autoPrintOnStable: _weighingFlag(json['auto_print_on_stable']),
    );
  }

  WeighingSettings copyWith({
    bool? enabled,
    String? barcodeFormat,
    String? prefix,
    int? pluDigits,
    int? valueDigits,
    String? payload,
    int? priceDecimals,
    int? labelWidthMm,
    int? labelHeightMm,
    bool? labelShowRestaurant,
    bool? labelShowDate,
    bool? autoPrintOnStable,
  }) {
    return WeighingSettings(
      enabled: enabled ?? this.enabled,
      barcodeFormat: barcodeFormat ?? this.barcodeFormat,
      prefix: prefix ?? this.prefix,
      pluDigits: pluDigits ?? this.pluDigits,
      valueDigits: valueDigits ?? this.valueDigits,
      payload: payload ?? this.payload,
      priceDecimals: priceDecimals ?? this.priceDecimals,
      labelWidthMm: labelWidthMm ?? this.labelWidthMm,
      labelHeightMm: labelHeightMm ?? this.labelHeightMm,
      labelShowRestaurant: labelShowRestaurant ?? this.labelShowRestaurant,
      labelShowDate: labelShowDate ?? this.labelShowDate,
      autoPrintOnStable: autoPrintOnStable ?? this.autoPrintOnStable,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'barcode_format': isCustom ? 'custom' : 'ean13',
    'prefix': prefix,
    'plu_digits': pluDigits.clamp(1, 6),
    'value_digits': valueDigits.clamp(4, 6),
    'payload': payload == 'price' ? 'price' : 'weight',
    'price_decimals': priceDecimals.clamp(0, 2),
    'label_width_mm': labelWidthMm.clamp(30, 110),
    'label_height_mm': labelHeightMm.clamp(20, 150),
    'label_show_restaurant': labelShowRestaurant,
    'label_show_date': labelShowDate,
    'auto_print_on_stable': autoPrintOnStable,
  };

  /// Prefix + PLU (P) + value (V) + check digit (C) when the format is EAN-13.
  String get barcodeFormatPreview {
    final digits = prefix.replaceAll(RegExp(r'\D'), '');
    return '$digits${'P' * pluLength}${'V' * valueLength}${isCustom ? '' : 'C'}';
  }
}

bool _weighingFlag(Object? value) =>
    value == true || value == 1 || value == '1';

int _boundedInt(Object? value, int min, int max, int fallback) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse('${value ?? ''}');
  if (parsed == null) return fallback;
  return parsed.clamp(min, max);
}

int _settingsFlag(Object? value) => value == true || value == 1 ? 1 : 0;

const _orderingFlagKeys = <String>{
  'order_notes_enabled',
  'enable_order_pickup',
  'enable_order_delivery',
  'enable_order_dine_in',
  'enable_table_booking',
  'require_customer_login',
  'ai_chat_enabled',
  'require_shift_for_pos',
  'queue_required',
  'auto_accept_paid_orders',
  'kot_only_for_confirmed',
  'auto_start_cooking_on_kot',
  'auto_deliver_on_scan_to_print',
  'accept_online_payments',
  'accept_pay_at_counter',
  'prices_include_tax',
};

const _orderingValueKeys = <String>{
  'order_number_prefix',
  'customer_login_method',
  'guest_contact_required',
  'pos_receipt_print_mode',
  'order_notification_sound',
  'payment_qr_timeout_seconds',
  'payment_confirm_grace_seconds',
  'service_charge',
  'tips',
  'order_type_charges',
  'order_type_surcharge_settings',
};

Map<String, dynamic>? _stringKeyMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// The ordering fields, whether the settings document is flat or nested.
Map<String, dynamic> _orderingSource(Map<String, dynamic> current) {
  final nested = _stringKeyMap(current['ordering']);
  if (nested != null) return nested;
  final settings = _stringKeyMap(current['settings']);
  final fromSettings = settings == null
      ? null
      : _stringKeyMap(settings['ordering']);
  if (fromSettings != null) return fromSettings;
  return current;
}

/// Ordering-tab body for `PATCH /api/v1/admin/settings`.
///
/// Copies only ordering keys the server already returned, then replaces
/// `weighing`. A missing key is left out so this save cannot reset it.
Map<String, dynamic> orderingSettingsUpdate({
  required Map<String, dynamic> current,
  required WeighingSettings weighing,
}) {
  final source = _orderingSource(current);
  final body = <String, dynamic>{'tab': 'ordering'};
  for (final key in _orderingFlagKeys) {
    if (!source.containsKey(key)) continue;
    body[key] = _settingsFlag(source[key]);
  }
  for (final key in _orderingValueKeys) {
    if (!source.containsKey(key)) continue;
    body[key] = source[key];
  }
  final previous = _stringKeyMap(source['weighing']) ?? const <String, dynamic>{};
  body['weighing'] = {
    ...previous,
    'enabled': _settingsFlag(weighing.enabled),
    'barcode_format': weighing.isCustom ? 'custom' : 'ean13',
    'prefix': weighing.prefix,
    'plu_digits': weighing.pluDigits.clamp(1, 6),
    'value_digits': weighing.valueDigits.clamp(4, 6),
    'payload': weighing.payload == 'price' ? 'price' : 'weight',
    'price_decimals': weighing.priceDecimals.clamp(0, 2),
    'label_width_mm': weighing.labelWidthMm.clamp(30, 110),
    'label_height_mm': weighing.labelHeightMm.clamp(20, 150),
    'label_show_restaurant': _settingsFlag(weighing.labelShowRestaurant),
    'label_show_date': _settingsFlag(weighing.labelShowDate),
    'auto_print_on_stable': _settingsFlag(weighing.autoPrintOnStable),
  };
  return body;
}

/// EAN-13 variable-measure codes for in-store weighed labels.
///
/// `[prefix][PLU][value, 5 digits][check]` — see the weighed-items spec.
class WeighedCode {
  const WeighedCode({
    required this.barcode,
    required this.plu,
    required this.value,
    this.weightKg,
    this.priceTotal,
  });

  final String barcode;

  /// PLU with leading zeros removed (`00123` == `123`).
  final String plu;
  final int value;
  final double? weightKg;
  final double? priceTotal;
}

class WeighedBarcode {
  WeighedBarcode._();

  static int pluLength(WeighingSettings settings) => settings.pluLength;

  static int checkDigit(String body12) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final digit = body12.codeUnitAt(i) - 0x30;
      sum += digit * ((i + 1).isOdd ? 1 : 3);
    }
    return (10 - (sum % 10)) % 10;
  }

  static bool validEan13(String code) {
    if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
    return checkDigit(code.substring(0, 12)) ==
        code.codeUnitAt(12) - 0x30;
  }

  /// `null` when the PLU or the value cannot fit the barcode.
  static String? encode({
    required WeighingSettings settings,
    required String plu,
    required double weightKg,
    double? lineTotal,
  }) {
    final prefix = settings.prefix.replaceAll(RegExp(r'\D'), '');
    final pluWidth = settings.pluLength;
    final valueWidth = settings.valueLength;
    if (prefix.isEmpty || pluWidth < 1) return null;
    final pluDigits = plu.replaceAll(RegExp(r'\D'), '');
    if (pluDigits.isEmpty || pluDigits.length > pluWidth) return null;
    final paddedPlu = pluDigits.padLeft(pluWidth, '0');
    final int rawValue;
    if (settings.payload == 'price') {
      final total = lineTotal ?? 0;
      rawValue = (total * _pow10(settings.priceDecimals)).round();
    } else {
      rawValue = (roundKg(weightKg) * 1000).round();
    }
    final maxValue = _pow10(valueWidth) - 1;
    if (rawValue < 0 || rawValue > maxValue) return null;
    final body =
        '$prefix$paddedPlu${rawValue.toString().padLeft(valueWidth, '0')}';
    if (settings.isCustom) {
      return body.length == settings.barcodeLength ? body : null;
    }
    if (body.length != 12) return null;
    return '$body${checkDigit(body)}';
  }

  static WeighedCode? decode(String raw, WeighingSettings settings) {
    final code = raw.trim().replaceAll(RegExp(r'\s'), '');
    if (!settings.enabled) return null;
    final prefix = settings.prefix.replaceAll(RegExp(r'\D'), '');
    final matchesShape = settings.isCustom
        ? RegExp('^\\d{${settings.barcodeLength}}\$').hasMatch(code)
        : validEan13(code);
    if (!matchesShape || prefix.isEmpty || !code.startsWith(prefix)) {
      return null;
    }
    final pluWidth = settings.pluLength;
    final valueWidth = settings.valueLength;
    final pluEnd = prefix.length + pluWidth;
    final valueEnd = pluEnd + valueWidth;
    if (valueEnd > code.length) return null;
    final pluRaw = code.substring(prefix.length, pluEnd);
    final valueRaw = code.substring(pluEnd, valueEnd);
    final value = int.tryParse(valueRaw);
    if (value == null) return null;
    final plu = stripPlu(pluRaw);
    if (settings.payload == 'price') {
      return WeighedCode(
        barcode: code,
        plu: plu,
        value: value,
        priceTotal: value / _pow10(settings.priceDecimals),
      );
    }
    return WeighedCode(
      barcode: code,
      plu: plu,
      value: value,
      weightKg: roundKg(value / 1000),
    );
  }

  static String stripPlu(String plu) {
    final digits = plu.replaceAll(RegExp(r'\D'), '');
    final stripped = digits.replaceFirst(RegExp(r'^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
  }

  static bool samePlu(String a, String b) => stripPlu(a) == stripPlu(b);

  static double roundKg(double kg) => (kg * 1000).round() / 1000;

  static double lineTotal(double ratePerKg, double weightKg) {
    return (ratePerKg * roundKg(weightKg) * 100).round() / 100;
  }

  static String formatKg(double kg) => roundKg(kg).toStringAsFixed(3);

  static int _pow10(int decimals) {
    var value = 1;
    for (var i = 0; i < decimals; i++) {
      value *= 10;
    }
    return value;
  }
}

/// One scale frame. [stable] is null when the frame has no ST/US flag.
class ScaleReading {
  const ScaleReading({required this.kilograms, this.stable});

  final double kilograms;
  final bool? stable;
}

class ScaleFrame {
  ScaleFrame._();

  static final _number = RegExp(
    r'([+-]?\d+(?:\.\d+)?)\s*(kg|g)?',
    caseSensitive: false,
  );

  static ScaleReading? parse(String raw, {bool assumeGrams = false}) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    bool? stable;
    if (RegExp(r'(^|[^A-Z])ST([^A-Z]|$)').hasMatch(text.toUpperCase())) {
      stable = true;
    } else if (RegExp(r'(^|[^A-Z])US([^A-Z]|$)').hasMatch(text.toUpperCase())) {
      stable = false;
    }
    final match = _number.firstMatch(text);
    if (match == null) return null;
    final number = double.tryParse(match.group(1)!);
    if (number == null) return null;
    final unit = match.group(2)?.toLowerCase();
    final grams = unit == 'g' || (unit == null && assumeGrams);
    final kg = grams ? number / 1000 : number;
    return ScaleReading(kilograms: WeighedBarcode.roundKg(kg), stable: stable);
  }
}
