import 'package:intl/intl.dart';

import '../../models/pos_models.dart';
import '../../utils/format.dart';
import '../../utils/weighed_barcode.dart';
import '../pos_api.dart';
import 'esc_pos_builder.dart';
import 'pos_receipt_printer.dart';
import 'receipt_typography.dart';

class WeighedLabelFields {
  const WeighedLabelFields({
    required this.barcode,
    required this.name,
    required this.weightKg,
    required this.ratePerKg,
    required this.total,
    this.restaurantName,
    this.dateLabel,
  });

  final String barcode;
  final String name;
  final double weightKg;
  final double ratePerKg;
  final double total;
  final String? restaurantName;
  final String? dateLabel;
}

class WeighedLabelPrinter {
  WeighedLabelPrinter._();

  static List<int> buildBytes({
    required WeighedLabelFields label,
    required String currency,
    required WeighingSettings settings,
  }) {
    final builder = EscPosBuilder(
      typography: ReceiptTypography(
        receiptWidth: settings.labelWidthMm <= 58 ? '58mm' : '80mm',
        fontSize: 'normal',
      ),
    );
    builder.initialize();
    builder.alignCenter();
    if (settings.labelShowRestaurant) {
      final restaurant = label.restaurantName?.trim();
      if (restaurant != null && restaurant.isNotEmpty) {
        builder.bold(true);
        builder.text(restaurant);
        builder.bold(false);
      }
    }
    builder.bold(true);
    builder.text(label.name);
    builder.bold(false);
    builder.alignLeft();
    builder.text('${WeighedBarcode.formatKg(label.weightKg)} kg');
    builder.text(
      '@ ${formatMoney(label.ratePerKg, currency)}/kg',
    );
    builder.bold(true);
    builder.text(formatMoney(label.total, currency));
    builder.bold(false);
    if (settings.labelShowDate) {
      final date = label.dateLabel?.trim();
      if (date != null && date.isNotEmpty) builder.text(date);
    }
    builder.alignCenter();
    builder.ean13(label.barcode);
    builder.feed(2);
    builder.cut();
    return builder.build();
  }

  /// Asks the server for the label, then prints it. Offline, the same barcode
  /// is built locally and checkout still re-checks it.
  static Future<void> print({
    required PosSession session,
    required MenuItem item,
    required double weightKg,
    required WeighingSettings settings,
    required String restaurantName,
    required String currency,
    required bool online,
    String? terminalCode,
  }) async {
    final plu = item.pluCode;
    if (plu == null || plu.isEmpty) {
      throw StateError('This item needs a PLU code before a label can be printed.');
    }
    final weight = WeighedBarcode.roundKg(weightKg);
    final rate = item.price;
    final total = WeighedBarcode.lineTotal(rate, weight);
    WeighedLabelFields fields;
    if (online) {
      final label = await PosApi().createWeightLabel(
        session,
        menuItemId: item.id,
        weight: weight,
        posTerminalCode: terminalCode,
      );
      final barcode = (label['barcode'] ?? label['code'])?.toString().trim();
      if (barcode == null || barcode.isEmpty) {
        throw StateError('The server did not return a label barcode.');
      }
      fields = WeighedLabelFields(
        barcode: barcode,
        name: (label['name'] ?? label['item_name'] ?? item.name).toString(),
        weightKg: _asDouble(label['weight'], weight),
        ratePerKg: _asDouble(label['unit_rate'] ?? label['rate'], rate),
        total: _asDouble(label['total'] ?? label['line_total'], total),
        restaurantName: (label['restaurant_name'] ?? restaurantName).toString(),
        dateLabel: (label['date'] ?? label['printed_at'])?.toString() ??
            DateFormat('dd MMM yyyy').format(DateTime.now()),
      );
    } else {
      final barcode = WeighedBarcode.encode(
        settings: settings,
        plu: plu,
        weightKg: weight,
        lineTotal: total,
      );
      if (barcode == null) {
        throw StateError('This weight cannot be encoded on a label.');
      }
      fields = WeighedLabelFields(
        barcode: barcode,
        name: item.name,
        weightKg: weight,
        ratePerKg: rate,
        total: total,
        restaurantName: restaurantName,
        dateLabel: DateFormat('dd MMM yyyy').format(DateTime.now()),
      );
    }
    await PosReceiptPrinter.printEscPos(
      buildBytes(label: fields, currency: currency, settings: settings),
    );
  }

  static double _asDouble(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
