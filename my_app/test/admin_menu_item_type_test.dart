import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/admin_models.dart';

void main() {
  test('admin menu reads saved item types and preserves them after updates', () {
    for (final type in ['veg', 'non_veg', 'egg', 'vegan', 'drink']) {
      final item = AdminMenuItem.fromJson({
        'id': 1,
        'name': 'Item',
        'price': 10,
        'item_type': type,
      });
      expect(item.itemType, type);
      expect(item.copyWith(isAvailable: false).itemType, type);
    }
  });

  test('unspecified item type stays unspecified', () {
    final item = AdminMenuItem.fromJson({
      'id': 1,
      'name': 'Item',
      'price': 10,
    });
    expect(item.itemType, isNull);
  });
}
