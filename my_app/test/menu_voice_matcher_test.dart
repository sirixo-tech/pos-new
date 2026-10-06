import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/menu_voice_matcher.dart';

void main() {
  const names = ['Masala dosa', 'Plain dosa', 'Idli', 'Filter coffee'];
  test('matches actual item names and shared item words', () {
    expect(matchMenuVoice('DOSA.', names), 'dosa');
    expect(
      matchMenuVoice('Please search for masala dosa', names),
      'masala dosa',
    );
    expect(matchMenuVoice('Dosai', names), 'dosa');
    expect(matchMenuVoice('idly', names), 'idli');
    expect(matchMenuVoice('Filter coffee', names), 'filter coffee');
    expect(matchMenuVoice('paneer dosa', ['Paneer-Dosa']), 'Paneer-Dosa');
  });
  test('rejects unrelated dictation and items absent from the menu', () {
    for (final words in [
      'good news',
      'the window and',
      'of the',
      'Moon',
      'pizza',
      'do',
      'dose',
    ]) {
      expect(matchMenuVoice(words, names), isNull, reason: words);
    }
    expect(matchMenuVoice('dosai', ['Coffee']), isNull);
  });
  test('vocabulary includes translated names without punctuation', () {
    expect(menuVoiceVocabulary(['Dosa', 'Dosa', 'தோசை']), ['dosa', 'தோசை']);
  });
}
