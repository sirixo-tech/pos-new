import 'json_parse.dart';

enum TaxBreakdownDisplay {
  hidden,
  totalOnly,
  always,
  expandable;

  static TaxBreakdownDisplay fromApi(String? value) {
    switch (value) {
      case 'hidden':
        return TaxBreakdownDisplay.hidden;
      case 'total_only':
        return TaxBreakdownDisplay.totalOnly;
      case 'expandable':
        return TaxBreakdownDisplay.expandable;
      case 'always':
      default:
        return TaxBreakdownDisplay.always;
    }
  }
}

class TaxConfig {
  const TaxConfig({
    required this.name,
    required this.rate,
    required this.included,
  });

  final String name;
  final double rate;
  final bool included;

  factory TaxConfig.fromJson(Map<String, dynamic> json) {
    return TaxConfig(
      name: json['name'] as String? ?? 'Tax',
      rate: parseJsonDouble(json['rate']),
      included: parseJsonBool(json['included'], fallback: true),
    );
  }
}

class TaxBreakdownLine {
  const TaxBreakdownLine({
    required this.name,
    required this.rate,
    required this.amount,
    required this.included,
  });

  final String name;
  final double rate;
  final double amount;
  final bool included;
}

class TaxSettings {
  const TaxSettings({
    required this.pricesIncludeTax,
    required this.taxRate,
    required this.taxes,
  });

  final bool pricesIncludeTax;
  final double taxRate;
  final List<TaxConfig> taxes;

  factory TaxSettings.fromJson(Map<String, dynamic> json) {
    return TaxSettings(
      pricesIncludeTax: parseJsonBool(json['prices_include_tax'], fallback: true),
      taxRate: parseJsonDouble(json['tax_rate']),
      taxes: (json['taxes'] as List<dynamic>? ?? [])
          .map((e) => TaxConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TaxComputation {
  const TaxComputation({
    required this.breakdown,
    required this.totalTax,
    required this.total,
  });

  final List<TaxBreakdownLine> breakdown;
  final double totalTax;
  final double total;
}

double roundMoney(double value) => (value * 100).roundToDouble() / 100;

double includedTaxRateSum(List<TaxBreakdownLine> breakdown) {
  return breakdown.fold<double>(
    0,
    (sum, row) => row.included && row.rate > 0 ? sum + row.rate : sum,
  );
}

double exclusiveAmount(double inclusive, double includedRateSum) {
  if (includedRateSum <= 0) {
    return roundMoney(inclusive);
  }

  return roundMoney(inclusive / (1 + includedRateSum / 100));
}

double includedTaxRateSumFromMaps(Iterable<dynamic> rows) {
  var sum = 0.0;
  for (final row in rows) {
    if (row is! Map) continue;
    if (row['included'] != true) continue;
    final rate = (row['rate'] as num?)?.toDouble() ?? 0;
    if (rate > 0) {
      sum += rate;
    }
  }

  return sum;
}

TaxComputation computeTaxFromSubtotal(double subtotal, TaxSettings settings) {
  final taxes = settings.taxes;
  final breakdown = <TaxBreakdownLine>[];
  var totalTax = 0.0;
  var excludedSum = 0.0;

  if (taxes.isNotEmpty) {
    final includedRates =
        taxes.where((t) => t.included && t.rate > 0).toList();
    final excludedRates =
        taxes.where((t) => !t.included && t.rate > 0).toList();
    final includedSum =
        includedRates.fold<double>(0, (sum, t) => sum + t.rate);

    if (includedSum > 0) {
      final base = roundMoney(subtotal / (1 + includedSum / 100));
      for (final rate in includedRates) {
        final amount = roundMoney(base * rate.rate / 100);
        breakdown.add(TaxBreakdownLine(
          name: rate.name,
          rate: rate.rate,
          amount: amount,
          included: true,
        ));
        totalTax += amount;
      }
    }

    for (final rate in excludedRates) {
      final amount = roundMoney(subtotal * rate.rate / 100);
      breakdown.add(TaxBreakdownLine(
        name: rate.name,
        rate: rate.rate,
        amount: amount,
        included: false,
      ));
      totalTax += amount;
      excludedSum += amount;
    }

    return TaxComputation(
      breakdown: breakdown,
      totalTax: roundMoney(totalTax),
      total: roundMoney(subtotal + excludedSum),
    );
  }

  if (!settings.pricesIncludeTax && settings.taxRate > 0) {
    final amount = roundMoney(subtotal * settings.taxRate / 100);
    breakdown.add(TaxBreakdownLine(
      name: 'Tax',
      rate: settings.taxRate,
      amount: amount,
      included: false,
    ));
    totalTax = amount;
  }

  return TaxComputation(
    breakdown: breakdown,
    totalTax: roundMoney(totalTax),
    total: roundMoney(subtotal + totalTax),
  );
}
