/// Restaurant weighing settings from POS bootstrap (`restaurant.weighing`).
class WeighingSettings {
  const WeighingSettings({
    this.enabled = false,
    this.prefix = '20',
    this.payload = 'weight',
    this.priceDecimals = 2,
    this.labelWidthMm = 50,
    this.labelHeightMm = 38,
    this.labelShowRestaurant = true,
    this.labelShowDate = true,
    this.autoPrintOnStable = false,
  });

  final bool enabled;
  final String prefix;
  final String payload;
  final int priceDecimals;
  final int labelWidthMm;
  final int labelHeightMm;
  final bool labelShowRestaurant;
  final bool labelShowDate;
  final bool autoPrintOnStable;

  factory WeighingSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WeighingSettings();
    final prefix = (json['prefix'] as String?)?.trim();
    final payload = (json['payload'] as String?)?.trim().toLowerCase();
    final decimals = json['price_decimals'];
    final width = json['label_width_mm'];
    final height = json['label_height_mm'];
    return WeighingSettings(
      enabled: json['enabled'] == true,
      prefix: prefix != null && prefix.isNotEmpty ? prefix : '20',
      payload: payload == 'price' ? 'price' : 'weight',
      priceDecimals: decimals is num ? decimals.toInt() : 2,
      labelWidthMm: width is num ? width.toInt() : 50,
      labelHeightMm: height is num ? height.toInt() : 38,
      labelShowRestaurant: json['label_show_restaurant'] != false,
      labelShowDate: json['label_show_date'] != false,
      autoPrintOnStable: json['auto_print_on_stable'] == true,
    );
  }

  WeighingSettings copyWith({
    bool? enabled,
    String? prefix,
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
      prefix: prefix ?? this.prefix,
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
    'prefix': prefix,
    'payload': payload == 'price' ? 'price' : 'weight',
    'price_decimals': priceDecimals.clamp(0, 2),
    'label_width_mm': labelWidthMm.clamp(30, 110),
    'label_height_mm': labelHeightMm.clamp(20, 150),
    'label_show_restaurant': labelShowRestaurant,
    'label_show_date': labelShowDate,
    'auto_print_on_stable': autoPrintOnStable,
  };

  /// `20PPPPPWWWWWC` style preview. PLU width is `7 - prefix length`.
  String get barcodeFormat {
    final digits = prefix.replaceAll(RegExp(r'\D'), '');
    final plu = (7 - digits.length).clamp(1, 6);
    return '$digits${'P' * plu}VVVVVC';
  }
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
  body['weighing'] = {
    'enabled': _settingsFlag(weighing.enabled),
    'prefix': weighing.prefix,
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

  static int pluLength(String prefix) => 13 - 1 - 5 - prefix.length;

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
    final prefix = settings.prefix;
    final length = pluLength(prefix);
    if (prefix.isEmpty || length < 1) return null;
    final pluDigits = plu.replaceAll(RegExp(r'\D'), '');
    if (pluDigits.isEmpty || pluDigits.length > length) return null;
    final paddedPlu = pluDigits.padLeft(length, '0');
    final int rawValue;
    if (settings.payload == 'price') {
      final total = lineTotal ?? 0;
      rawValue = (total * _pow10(settings.priceDecimals)).round();
    } else {
      rawValue = (roundKg(weightKg) * 1000).round();
    }
    if (rawValue < 0 || rawValue > 99999) return null;
    final body = '$prefix$paddedPlu${rawValue.toString().padLeft(5, '0')}';
    if (body.length != 12) return null;
    return '$body${checkDigit(body)}';
  }

  static WeighedCode? decode(String raw, WeighingSettings settings) {
    final code = raw.trim();
    if (!settings.enabled || !validEan13(code)) return null;
    final prefix = settings.prefix;
    if (!code.startsWith(prefix)) return null;
    final length = pluLength(prefix);
    if (length < 1) return null;
    final pluRaw = code.substring(prefix.length, prefix.length + length);
    final valueRaw = code.substring(prefix.length + length, prefix.length + length + 5);
    if (valueRaw.length != 5) return null;
    final value = int.parse(valueRaw);
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
