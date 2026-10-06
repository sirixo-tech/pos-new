/// Names and individual item words that the microphone may search for.
List<String> menuVoiceVocabulary(Iterable<String> names) {
  final words = <String>{};
  for (final name in names) {
    final normalized = normalizeMenuVoice(name);
    if (normalized.isEmpty) continue;
    words.add(normalized);
    words.addAll(normalized.split(' ').where((word) => word.length >= 3));
  }
  return words.toList(growable: false);
}

String normalizeMenuVoice(String words) => words
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Reject arbitrary dictation; never guess an item from unrelated words.
String? matchMenuVoice(String spoken, Iterable<String> names) {
  var query = normalizeMenuVoice(spoken);
  query = query.replaceFirst(
    RegExp(r'^(please )?(search( for)?|find|show( me)?) '),
    '',
  );
  if (query.isEmpty) return null;
  final vocabulary = menuVoiceVocabulary(names).toSet();
  String searchText(String matched) {
    for (final name in names) {
      if (name.toLowerCase().contains(matched)) return matched;
      if (normalizeMenuVoice(name) == matched) return name.trim();
    }
    return matched;
  }

  if (vocabulary.contains(query)) return searchText(query);
  // Common spellings for the same item, only when it exists in this menu.
  const aliases = {'dosai': 'dosa', 'dosha': 'dosa', 'idly': 'idli'};
  final corrected = query
      .split(' ')
      .map((word) => aliases[word] ?? word)
      .join(' ');
  return vocabulary.contains(corrected) ? searchText(corrected) : null;
}
