import 'package:flutter_test/flutter_test.dart';
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
}
