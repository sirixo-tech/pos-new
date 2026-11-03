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

  test('web switches hide dine in and takeaway the same way as delivery', () {
    final ordering = PosOrderingSettings.fromJson({
      'enable_dine_in': false,
      'enable_pickup': false,
      'enable_delivery': false,
      'pos_order_types': ['dine_in', 'takeaway', 'delivery'],
    });
    expect(ordering.activePosOrderTypes, isEmpty);
  });

  test('an empty web type list does not bring dine in and takeaway back', () {
    final ordering = PosOrderingSettings.fromJson({
      'enable_dine_in': false,
      'enable_pickup': false,
      'enable_delivery': false,
      'pos_order_types': [],
    });
    expect(ordering.activePosOrderTypes, isEmpty);
    expect(
      visiblePosOrderTypes(
        serverAllowed: ordering.activePosOrderTypes,
        dineIn: true,
        takeaway: true,
        delivery: true,
      ),
      isEmpty,
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
