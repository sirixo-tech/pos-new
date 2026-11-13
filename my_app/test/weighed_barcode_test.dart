import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/utils/weighed_barcode.dart';

void main() {
  const settings = WeighingSettings(enabled: true, prefix: '20');

  test('encodes the documented 0.750 kg label', () {
    final barcode = WeighedBarcode.encode(
      settings: settings,
      plu: '123',
      weightKg: 0.75,
    );
    expect(barcode, '2000123007502');
    expect(WeighedBarcode.validEan13(barcode!), isTrue);
  });

  test('decodes the label back to PLU and kilograms', () {
    final decoded = WeighedBarcode.decode('2000123007502', settings);
    expect(decoded, isNotNull);
    expect(decoded!.plu, '123');
    expect(decoded.weightKg, 0.750);
    expect(WeighedBarcode.samePlu('00123', decoded.plu), isTrue);
  });

  test('rejects a value that does not fit in five digits', () {
    expect(
      WeighedBarcode.encode(settings: settings, plu: '123', weightKg: 100),
      isNull,
    );
  });

  test('priced payload stores the line total', () {
    const priced = WeighingSettings(
      enabled: true,
      prefix: '20',
      payload: 'price',
      priceDecimals: 2,
    );
    final barcode = WeighedBarcode.encode(
      settings: priced,
      plu: '123',
      weightKg: 0.75,
      lineTotal: 12.50,
    );
    final decoded = WeighedBarcode.decode(barcode!, priced);
    expect(decoded!.priceTotal, 12.50);
    expect(decoded.weightKg, isNull);
  });

  test('a weighed cart line sends weight and forces quantity 1', () {
    final item = MenuItem(
      id: 42,
      name: 'Fish',
      price: 800,
      soldBy: 'weight',
      pluCode: '123',
      variants: const [],
      modifiers: const [],
    );
    final line = CartLine(
      menuItem: item,
      quantity: 3,
      weightKg: 0.75,
      scannedBarcode: '2000123007502',
    );
    expect(line.unitPrice, 600);
    expect(line.lineTotal, 600);
    expect(line.toOrderJson(), {
      'menu_item_id': 42,
      'quantity': 1,
      'weight': 0.75,
      'unit_rate': 800,
      'scanned_barcode': '2000123007502',
    });
  });

  test('saving weighing keeps the other ordering settings', () {
    final body = orderingSettingsUpdate(
      current: {
        'order_notes_enabled': true,
        'order_number_prefix': 'SMK',
        'enable_order_dine_in': true,
        'order_type_charges': {'dine_in': 10},
        'service_charge': {'enabled': true, 'rate': 5, 'label': 'Service'},
      },
      weighing: const WeighingSettings(enabled: true, prefix: '21'),
    );
    expect(body['tab'], 'ordering');
    expect(body['order_number_prefix'], 'SMK');
    expect(body['order_notes_enabled'], 1);
    expect(body['order_type_charges'], {'dine_in': 10});
    expect(body['service_charge'], {'enabled': true, 'rate': 5, 'label': 'Service'});
    expect(body.containsKey('enable_order_delivery'), isFalse);
    expect(body['weighing'], containsPair('barcode_format', 'ean13'));
    expect(body['weighing'], containsPair('prefix', '21'));
    expect(body['weighing'], containsPair('enabled', 1));

    final nested = orderingSettingsUpdate(
      current: {
        'ordering': {
          'order_number_prefix': 'SMK',
          'enable_order_dine_in': true,
          'service_charge': {'enabled': true, 'rate': 5},
        },
        'receipt': {'paper': '80mm'},
      },
      weighing: const WeighingSettings(prefix: '20'),
    );
    expect(nested['order_number_prefix'], 'SMK');
    expect(nested['enable_order_dine_in'], 1);
    expect(nested.containsKey('receipt'), isFalse);
    expect(nested.containsKey('enable_order_pickup'), isFalse);
    expect(nested['service_charge'], {'enabled': true, 'rate': 5});
    expect(const WeighingSettings(prefix: '20').barcodeFormatPreview, '20PPPPPVVVVVC');
  });

  test('parses Essae and plain scale frames', () {
    expect(
      ScaleFrame.parse('ST,GS,+  0.750kg')!.kilograms,
      0.750,
    );
    expect(ScaleFrame.parse('ST,GS,+  0.750kg')!.stable, isTrue);
    final settling = ScaleFrame.parse('US,NT,  1.205 kg')!;
    expect(settling.kilograms, 1.205);
    expect(settling.stable, isFalse);
    expect(ScaleFrame.parse('   750 g')!.kilograms, 0.750);
    expect(ScaleFrame.parse('0.750')!.kilograms, 0.750);
    expect(
      ScaleFrame.parse('0.750', assumeGrams: true)!.kilograms,
      0.001,
    );
  });

  test('custom labels decode the printed 425 g crab barcode', () {
    const custom = WeighingSettings(
      enabled: true,
      barcodeFormat: 'custom',
      prefix: '1',
      pluDigits: 5,
      valueDigits: 5,
    );
    final decoded = WeighedBarcode.decode('10002400425', custom);
    expect(decoded, isNotNull);
    expect(decoded!.plu, '24');
    expect(decoded.weightKg, 0.425);
    expect(
      WeighedBarcode.encode(
        settings: custom,
        plu: '24',
        weightKg: 0.425,
      ),
      '10002400425',
    );
    expect(custom.barcodeFormatPreview, '1PPPPPVVVVV');

    final fromServer = WeighingSettings.fromJson({
      'enabled': 1,
      'barcode_format': 'custom',
      'prefix': '10',
      'plu_digits': 4,
      'value_digits': 5,
      'payload': 'weight',
    });
    final sameLabel = WeighedBarcode.decode('10002400425', fromServer);
    expect(sameLabel!.plu, '24');
    expect(sameLabel.weightKg, 0.425);
  });

  test('saving weighing keeps unknown weighing keys from the server', () {
    final body = orderingSettingsUpdate(
      current: {
        'weighing': {'scale_note': 'counter 2', 'enabled': true},
      },
      weighing: const WeighingSettings(
        enabled: true,
        barcodeFormat: 'custom',
        prefix: '1',
        pluDigits: 5,
      ),
    );
    expect(body['weighing']['scale_note'], 'counter 2');
    expect(body['weighing']['barcode_format'], 'custom');
    expect(body['weighing']['plu_digits'], 5);
  });
}
