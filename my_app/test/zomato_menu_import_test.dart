import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/zomato_menu_import.dart';

void main() {
  test('reads dishes from an embedded Zomato menu', () {
    const body = '''
<script type="application/ld+json">
{
  "name": "Cafe",
  "hasMenuSection": [
    {
      "name": "Starters",
      "hasMenuItem": [
        {"name": "Paneer tikka", "offers": {"price": "250"}},
        {"name": "Soup", "offers": {"price": "120"}}
      ]
    }
  ]
}
</script>
''';
    final dishes = dishesFromZomatoBody(body);
    expect(dishes.map((dish) => dish.name), ['Paneer tikka', 'Soup']);
    expect(dishes.first.category, 'Starters');
    expect(dishes.first.price, 250);
  });

  test('accepts a zomato link and a restaurant id', () {
    expect(
      ZomatoMenuTarget.parse('https://www.zomato.com/ncr/cafe').urls.single.host,
      'www.zomato.com',
    );
    expect(
      ZomatoMenuTarget.parse('184739').urls.single.queryParameters['page_url'],
      '/restaurant/184739',
    );
  });

  test('rejects a link that is not Zomato', () {
    expect(
      () => ZomatoMenuTarget.parse('https://example.com/menu'),
      throwsA(isA<ZomatoMenuException>()),
    );
  });
}
