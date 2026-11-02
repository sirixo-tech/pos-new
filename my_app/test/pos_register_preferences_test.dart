import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_register_preferences.dart';

void main() {
  test('this register can hide a type the web still allows', () {
    expect(
      visiblePosOrderTypes(
        serverAllowed: const ['dine_in', 'takeaway', 'delivery'],
        dineIn: true,
        takeaway: false,
        delivery: true,
      ),
      ['dine_in', 'delivery'],
    );
  });

  test('a type turned off on the web stays hidden', () {
    expect(
      visiblePosOrderTypes(
        serverAllowed: const ['dine_in', 'takeaway'],
        dineIn: true,
        takeaway: true,
        delivery: true,
      ),
      ['dine_in', 'takeaway'],
    );
  });

  test('at least one type stays available', () {
    expect(
      visiblePosOrderTypes(
        serverAllowed: const ['dine_in', 'takeaway'],
        dineIn: false,
        takeaway: false,
        delivery: false,
      ),
      ['dine_in'],
    );
  });

  test('offline format overlays text and font without dropping the template', () {
    final base = PosReceiptSettings(
      fontSize: 'small',
      headerText: 'Server header',
      showRestaurantName: false,
      paper: '80mm',
    );
    final next = const OfflineReceiptFormat(
      headerLine: 'Counter copy',
      footerLine: 'See you soon',
      fontSize: 'large',
      paper: '58mm',
      showRestaurantName: true,
    ).applyTo(base);

    expect(next.headerText, 'Counter copy');
    expect(next.footerText, 'See you soon');
    expect(next.fontSize, 'large');
    expect(next.paper, '58mm');
    expect(next.showRestaurantName, isTrue);
    expect(next.template.blocks, base.template.blocks);
    final lines = const OfflineReceiptFormat().toCodeTemplate().blocks;
    expect(lines.first.type, 'logo');
    expect(lines.any((block) => block.bind == 'settings.header_line'), isTrue);
    expect(lines.last.bind, 'settings.footer_line');
    expect(next.token, base.token);
  });
}
