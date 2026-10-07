import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/order_barcode_scan.dart';

void main() {
  test('camera accepts order codes and tracking links', () {
    for (final code in [
      'ORD-202610070011',
      'https://app.selfx.in/order/ORD-202610070011',
      'https://app.selfx.in/track?order_number=ORD-202610070011',
    ]) {
      expect(OrderBarcodeScan.isOrderReference(code), isTrue);
      expect(OrderBarcodeScan.parseOrderNumber(code), 'ORD-202610070011');
    }
  });

  test('payment QRs and product barcodes cannot trigger receipt printing', () {
    for (final code in ['upi://pay?pa=shop@upi&am=65', '8901234567890', 'ITEM-12', '']) {
      expect(OrderBarcodeScan.isOrderReference(code), isFalse);
    }
  });
}
