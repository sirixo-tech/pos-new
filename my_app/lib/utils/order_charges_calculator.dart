import '../utils/tax_calculator.dart';
import 'json_parse.dart';

class ExtraChargeLine {
  const ExtraChargeLine({
    required this.id,
    required this.label,
    required this.amount,
    this.taxable = false,
  });

  final String id;
  final String label;
  final double amount;
  final bool taxable;
}

class ServiceChargeConfig {
  const ServiceChargeConfig({
    this.enabled = false,
    this.rate = 0,
    this.label = 'Service charge',
    this.taxable = false,
  });

  final bool enabled;
  final double rate;
  final String label;
  final bool taxable;

  factory ServiceChargeConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ServiceChargeConfig();
    return ServiceChargeConfig(
      enabled: json['enabled'] as bool? ?? false,
      rate: parseJsonDouble(json['rate']),
      label: json['label'] as String? ?? 'Service charge',
      taxable: parseJsonBool(json['taxable']),
    );
  }
}

class OrderTotalsPreview {
  const OrderTotalsPreview({
    required this.extraChargeLines,
    required this.extraChargesTotal,
    required this.serviceChargeAmount,
    required this.taxComputation,
  });

  final List<ExtraChargeLine> extraChargeLines;
  final double extraChargesTotal;
  final double serviceChargeAmount;
  final TaxComputation taxComputation;

  double get total => taxComputation.total;
  double get totalTax => taxComputation.totalTax;
}

const surchargeStrategyItemized = 'itemized';
const surchargeStrategyGlobal = 'global';
const globalApplicationOrder = 'order';
const globalApplicationPerItem = 'per_item';

String normalizeOrderType(String? type) {
  final t = (type ?? 'dine_in').toLowerCase();
  if (t == 'takeaway') return 'pickup';
  if (t == 'dine_in' || t == 'pickup' || t == 'delivery') return t;
  return 'dine_in';
}

Map<String, dynamic> defaultSurchargeSettings() {
  const row = {
    'strategy': surchargeStrategyGlobal,
    'global_application': globalApplicationOrder,
  };
  return {
    'dine_in': Map<String, dynamic>.from(row),
    'pickup': Map<String, dynamic>.from(row),
    'delivery': Map<String, dynamic>.from(row),
  };
}

Map<String, dynamic> normalizeSurchargeSettings(Map<String, dynamic>? stored) {
  final defaults = defaultSurchargeSettings();
  if (stored == null) return defaults;

  return Map.fromEntries(
    defaults.keys.map((type) {
      final row = stored[type] as Map<String, dynamic>? ?? const {};
      final strategy = row['strategy'] == surchargeStrategyItemized
          ? surchargeStrategyItemized
          : surchargeStrategyGlobal;
      final application = row['global_application'] == globalApplicationPerItem
          ? globalApplicationPerItem
          : globalApplicationOrder;
      return MapEntry(type, {
        'strategy': strategy,
        'global_application': application,
      });
    }),
  );
}

List<Map<String, dynamic>> _activeCharges(List<dynamic>? list) {
  if (list == null) return const [];
  return list.whereType<Map<String, dynamic>>().where((row) {
    if (row['enabled'] == false) return false;
    final label = (row['label'] as String? ?? '').trim();
    final amount = parseJsonDouble(row['amount']);
    return label.isNotEmpty && amount > 0;
  }).toList();
}

List<ExtraChargeLine> computeItemSurchargeLines(
  List<Map<String, dynamic>> cartLines,
  String orderType,
) {
  final type = normalizeOrderType(orderType);
  final lines = <ExtraChargeLine>[];

  for (final line in cartLines) {
    final menuItemId = parseJsonInt(line['menu_item_id']);
    final qty = parseJsonInt(line['quantity']);
    if (menuItemId <= 0 || qty <= 0) continue;

    final surchargesRaw = line['order_type_surcharges'];
    if (surchargesRaw is! Map<String, dynamic>) continue;
    final surcharges = _activeCharges(surchargesRaw[type] as List<dynamic>?);

    for (final row in surcharges) {
      final unit = parseJsonDouble(row['amount']);
      final amount = roundMoney(unit * qty);
      if (amount <= 0) continue;
      lines.add(
        ExtraChargeLine(
          id: row['id']?.toString() ?? 'item-$menuItemId-${row['label']}',
          label: row['label'] as String? ?? 'Charge',
          amount: amount,
        ),
      );
    }
  }

  return lines;
}

({List<ExtraChargeLine> lines, double total, double taxableTotal})
computeOrderLevelChargeLines(
  Map<String, dynamic>? orderTypeCharges,
  String orderType,
  double base,
) {
  final type = normalizeOrderType(orderType);
  final charges = _activeCharges(orderTypeCharges?[type] as List<dynamic>?);
  final lines = <ExtraChargeLine>[];
  var total = 0.0;
  var taxableTotal = 0.0;
  final roundedBase = roundMoney(base < 0 ? 0 : base);

  for (final row in charges) {
    final mode = row['mode'] == 'percent' ? 'percent' : 'fixed';
    final raw = parseJsonDouble(row['amount']);
    final amount = mode == 'percent'
        ? roundedBase > 0
              ? roundMoney(roundedBase * raw.clamp(0, 100) / 100)
              : 0.0
        : roundMoney(raw);
    if (amount <= 0) continue;
    final taxable = row['taxable'] == true;
    lines.add(
      ExtraChargeLine(
        id: row['id']?.toString() ?? 'order-${row['label']}',
        label: row['label'] as String? ?? 'Charge',
        amount: amount,
        taxable: taxable,
      ),
    );
    total += amount;
    if (taxable) taxableTotal += amount;
  }

  return (
    lines: lines,
    total: roundMoney(total),
    taxableTotal: roundMoney(taxableTotal),
  );
}

List<Map<String, dynamic>> _activeItemSurchargesForLine(
  Map<String, dynamic> line,
  String orderType,
) {
  final type = normalizeOrderType(orderType);
  final surchargesRaw = line['order_type_surcharges'];
  if (surchargesRaw is! Map<String, dynamic>) return const [];
  return _activeCharges(surchargesRaw[type] as List<dynamic>?);
}

({List<ExtraChargeLine> lines, double total, double taxableTotal})
computeGlobalPerItemChargeLines(
  Map<String, dynamic>? orderTypeCharges,
  String orderType,
  List<Map<String, dynamic>> cartLines,
) {
  final type = normalizeOrderType(orderType);
  final charges = _activeCharges(orderTypeCharges?[type] as List<dynamic>?);
  final lines = <ExtraChargeLine>[];
  var total = 0.0;
  var taxableTotal = 0.0;

  for (final line in cartLines) {
    final menuItemId = parseJsonInt(line['menu_item_id']);
    final qty = parseJsonInt(line['quantity']);
    if (menuItemId <= 0 || qty <= 0) continue;

    final itemSurcharges = _activeItemSurchargesForLine(line, orderType);
    if (itemSurcharges.isNotEmpty) {
      for (final row in itemSurcharges) {
        final unit = parseJsonDouble(row['amount']);
        final amount = roundMoney(unit * qty);
        if (amount <= 0) continue;
        lines.add(
          ExtraChargeLine(
            id: row['id']?.toString() ?? 'item-$menuItemId-${row['label']}',
            label: row['label'] as String? ?? 'Charge',
            amount: amount,
          ),
        );
        total += amount;
      }
      continue;
    }

    var lineTotal = roundMoney(parseJsonDouble(line['total']));
    if (lineTotal <= 0) {
      final unit = roundMoney(parseJsonDouble(line['unit_price']));
      lineTotal = roundMoney(unit * qty);
    }

    for (final row in charges) {
      final mode = row['mode'] == 'percent' ? 'percent' : 'fixed';
      final raw = parseJsonDouble(row['amount']);
      final amount = mode == 'percent'
          ? lineTotal > 0
                ? roundMoney(lineTotal * raw.clamp(0, 100) / 100)
                : 0.0
          : roundMoney(raw * qty);
      if (amount <= 0) continue;
      final taxable = row['taxable'] == true;
      lines.add(
        ExtraChargeLine(
          id: '${row['id'] ?? 'order-${row['label']}'}-$menuItemId',
          label: row['label'] as String? ?? 'Charge',
          amount: amount,
          taxable: taxable,
        ),
      );
      total += amount;
      if (taxable) taxableTotal += amount;
    }
  }

  return (
    lines: lines,
    total: roundMoney(total),
    taxableTotal: roundMoney(taxableTotal),
  );
}

({
  List<ExtraChargeLine> lines,
  double total,
  double taxableTotal,
})
computeExtraCharges({
  required List<Map<String, dynamic>> cartLines,
  required String orderType,
  Map<String, dynamic>? orderTypeCharges,
  required double discountedSubtotal,
  Map<String, dynamic>? surchargeSettings,
}) {
  final type = normalizeOrderType(orderType);
  final settings = normalizeSurchargeSettings(surchargeSettings)[type]
      as Map<String, dynamic>? ??
      defaultSurchargeSettings()[type] as Map<String, dynamic>;

  if (settings['strategy'] == surchargeStrategyItemized) {
    final itemLines = computeItemSurchargeLines(cartLines, orderType);
    final itemTotal = roundMoney(
      itemLines.fold<double>(0, (sum, l) => sum + l.amount),
    );
    return (
      lines: itemLines,
      total: itemTotal,
      taxableTotal: 0.0,
    );
  }

  if (settings['global_application'] == globalApplicationPerItem) {
    return computeGlobalPerItemChargeLines(
      orderTypeCharges,
      orderType,
      cartLines,
    );
  }

  return computeOrderLevelChargeLines(
    orderTypeCharges,
    orderType,
    discountedSubtotal,
  );
}

double computeServiceChargeAmount(
  ServiceChargeConfig config,
  double discountedSubtotal,
) {
  if (!config.enabled || discountedSubtotal <= 0) return 0;
  final rate = config.rate.clamp(0, 100);
  if (rate <= 0) return 0;
  return roundMoney(discountedSubtotal * rate / 100);
}

OrderTotalsPreview computeOrderTotalsPreview({
  required double subtotal,
  double discountAmount = 0,
  required List<Map<String, dynamic>> cartLines,
  required String orderType,
  Map<String, dynamic>? orderTypeCharges,
  Map<String, dynamic>? surchargeSettings,
  ServiceChargeConfig serviceCharge = const ServiceChargeConfig(),
  required TaxSettings taxSettings,
}) {
  final discountedSubtotal = roundMoney(
    (subtotal - discountAmount).clamp(0.0, double.infinity),
  );
  final extraPart = computeExtraCharges(
    cartLines: cartLines,
    orderType: orderType,
    orderTypeCharges: orderTypeCharges,
    discountedSubtotal: discountedSubtotal,
    surchargeSettings: surchargeSettings,
  );
  final extraLines = extraPart.lines;
  final extraTotal = extraPart.total;
  final taxableExtra = extraPart.taxableTotal;
  final nonTaxableExtra = roundMoney(extraTotal - taxableExtra);
  final serviceChargeAmount = computeServiceChargeAmount(
    serviceCharge,
    discountedSubtotal,
  );
  final taxBase = roundMoney(
    discountedSubtotal +
        taxableExtra +
        (serviceCharge.taxable ? serviceChargeAmount : 0),
  );
  final taxComputation = computeTaxFromSubtotal(taxBase, taxSettings);
  var total = taxComputation.total;
  if (nonTaxableExtra > 0) {
    total = roundMoney(total + nonTaxableExtra);
  }
  if (serviceChargeAmount > 0 && !serviceCharge.taxable) {
    total = roundMoney(total + serviceChargeAmount);
  }

  return OrderTotalsPreview(
    extraChargeLines: extraLines,
    extraChargesTotal: extraTotal,
    serviceChargeAmount: serviceChargeAmount,
    taxComputation: TaxComputation(
      breakdown: taxComputation.breakdown,
      totalTax: taxComputation.totalTax,
      total: total,
    ),
  );
}
