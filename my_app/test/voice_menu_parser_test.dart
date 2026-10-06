import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/voice_menu_parser.dart';

void main() {
  test('spoken items become priced menu rows', () {
    final lines = parseVoiceMenu(
      'Cappuccino 120, Latte 140 in Hot drinks. Category starters, paneer tikka 250',
    );
    expect(lines, hasLength(3));
    expect(lines[0].name, 'Cappuccino');
    expect(lines[0].price, 120);
    expect(lines[0].category, 'General');
    expect(lines[1].name, 'Latte');
    expect(lines[1].category, 'Hot drinks');
    expect(lines[1].price, 140);
    expect(lines[2].name, 'paneer tikka');
    expect(lines[2].category, 'starters');
    expect(lines[2].price, 250);
    expect(lines.every((line) => line.isReady), isTrue);
  });

  test('spoken number words are prices', () {
    final lines = parseVoiceMenu('masala dosa one hundred twenty');
    expect(lines.single.name, 'masala dosa');
    expect(lines.single.price, 120);
  });

  test('a missing price stays visible for review', () {
    final lines = parseVoiceMenu('filter coffee');
    expect(lines.single.isReady, isFalse);
  });
}
