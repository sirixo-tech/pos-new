import 'dart:typed_data';

import 'menu_spreadsheet_export.dart';

class VoiceMenuLine {
  const VoiceMenuLine({
    required this.category,
    required this.name,
    required this.price,
  });

  final String category;
  final String name;
  final double? price;

  bool get isReady => name.isNotEmpty && price != null && price! >= 0;
}

/// Turns a spoken menu list into import rows.
///
/// Example: "Cappuccino 120, Latte 140 in Hot drinks. Category starters,
/// paneer tikka 250."
List<VoiceMenuLine> parseVoiceMenu(String transcript) {
  var category = 'General';
  final lines = <VoiceMenuLine>[];
  final chunks = transcript
      .replaceAll(RegExp(r'\.\s+'), ', ')
      .replaceAll(RegExp(r'[\n;]+'), ',')
      .split(RegExp(r'\s*,\s*|\s+next\s+|\s+then\s+', caseSensitive: false))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);

  final categoryOnly = RegExp(
    r'^(?:new\s+)?(?:category|in\s+category|under)\s+(.+)$',
    caseSensitive: false,
  );
  final trailingCategory = RegExp(
    r'^(.*?)\s+(?:in|under|category)\s+(.+)$',
    caseSensitive: false,
  );

  for (final raw in chunks) {
    final only = categoryOnly.firstMatch(raw);
    if (only != null && _priceOf(only.group(1)!) == null) {
      final next = _clean(only.group(1)!);
      if (next.isNotEmpty) category = next;
      continue;
    }

    var text = raw;
    var lineCategory = category;
    final trail = trailingCategory.firstMatch(text);
    if (trail != null && _priceOf(trail.group(2)!) == null) {
      final tail = _clean(trail.group(2)!);
      final head = trail.group(1)!.trim();
      if (tail.isNotEmpty && head.isNotEmpty) {
        text = head;
        lineCategory = tail;
        category = tail;
      }
    }

    final parsed = _priceOf(text);
    final name = _clean(parsed?.rest ?? text);
    if (name.isEmpty) continue;
    lines.add(
      VoiceMenuLine(category: lineCategory, name: name, price: parsed?.price),
    );
  }
  return lines;
}

Uint8List voiceMenuCsv(List<VoiceMenuLine> lines) {
  return MenuSpreadsheetExport.csv([
    for (final line in lines)
      {
        'category_name': line.category,
        'item_name': line.name,
        'price': line.price == null
            ? ''
            : (line.price! % 1 == 0
                  ? line.price!.toStringAsFixed(0)
                  : line.price!.toString()),
        'is_available': '1',
      },
  ]);
}

class _Priced {
  const _Priced(this.price, this.rest);
  final double price;
  final String rest;
}

_Priced? _priceOf(String source) {
  var text = source.trim();
  text = text.replaceFirst(
    RegExp(r'\s*(?:rupees?|rs\.?|inr)\s*$', caseSensitive: false),
    '',
  );
  final digit = RegExp(
    r'^(.*?)(?:\s*(?:for|at|₹|rs\.?|inr))?\s*(\d+(?:\.\d{1,2})?)\s*$',
    caseSensitive: false,
  ).firstMatch(text);
  if (digit != null) {
    final price = double.tryParse(digit.group(2)!);
    if (price != null) return _Priced(price, digit.group(1)!);
  }
  final words = _takeSpokenNumber(text);
  if (words == null) return null;
  return _Priced(words.$1, words.$2);
}

(double, String)? _takeSpokenNumber(String source) {
  const ones = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
  };
  const tens = {
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };
  final words = source
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return null;
  var index = words.length;
  var total = 0;
  var matched = false;
  while (index > 0) {
    final word = words[index - 1].replaceAll(RegExp(r'[^a-z]'), '');
    if (word == 'and') {
      index--;
      continue;
    }
    if (word == 'hundred' && index > 1) {
      final lead = words[index - 2].replaceAll(RegExp(r'[^a-z]'), '');
      final value = ones[lead];
      if (value == null || value < 1 || value > 9) break;
      total += value * 100;
      index -= 2;
      matched = true;
      continue;
    }
    if (tens.containsKey(word)) {
      total += tens[word]!;
      index--;
      matched = true;
      continue;
    }
    if (ones.containsKey(word)) {
      total += ones[word]!;
      index--;
      matched = true;
      continue;
    }
    break;
  }
  if (!matched) return null;
  return (total.toDouble(), words.take(index).join(' '));
}

String _clean(String value) {
  return value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s,.-]+|[\s,.-]+$'), '')
      .trim();
}
