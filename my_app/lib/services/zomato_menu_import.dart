import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'voice_menu_parser.dart';

class ZomatoDish {
  const ZomatoDish({
    required this.category,
    required this.name,
    required this.price,
  });

  final String category;
  final String name;
  final double price;
}

class ZomatoMenuException implements Exception {
  const ZomatoMenuException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A Zomato outlet share link, or a numeric restaurant id from the partner app.
class ZomatoMenuTarget {
  const ZomatoMenuTarget._(this.urls);
  final List<Uri> urls;

  static ZomatoMenuTarget parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const ZomatoMenuException('Paste the outlet link or restaurant ID.');
    }
    if (RegExp(r'^\d{3,12}$').hasMatch(text)) {
      return ZomatoMenuTarget._([
        Uri.https('www.zomato.com', '/webroutes/getPage', {
          'page_url': '/restaurant/$text',
        }),
      ]);
    }
    final withScheme = text.contains('://') ? text : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    final host = uri?.host.toLowerCase() ?? '';
    final allowed = host == 'zomato.com' ||
        host.endsWith('.zomato.com') ||
        host == 'zoma.to' ||
        host.endsWith('.zoma.to');
    if (uri == null || !uri.hasScheme || !allowed) {
      throw const ZomatoMenuException(
        'Use a Zomato outlet link, or the restaurant ID from the partner app.',
      );
    }
    return ZomatoMenuTarget._([uri]);
  }
}

/// Reads dishes from a Zomato page or the JSON that page embeds.
List<ZomatoDish> dishesFromZomatoBody(String body) {
  final found = <ZomatoDish>[];
  final seen = <String>{};
  for (final node in _jsonNodes(body)) {
    _walk(node, 'General', found, seen);
  }
  return found;
}

List<dynamic> _jsonNodes(String body) {
  final nodes = <dynamic>[];
  final trimmed = body.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    final decoded = _tryDecode(trimmed);
    if (decoded != null) return [decoded];
  }
  final scripts = RegExp(
    r'<script[^>]*>(.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(body);
  for (final match in scripts) {
    final text = match.group(1)?.trim() ?? '';
    if (!text.contains('price') && !text.contains('Price')) continue;
    final decoded = _tryDecode(text);
    if (decoded != null) nodes.add(decoded);
  }
  return nodes;
}

dynamic _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

void _walk(
  dynamic node,
  String category,
  List<ZomatoDish> found,
  Set<String> seen,
) {
  if (node is List) {
    for (final item in node) {
      _walk(item, category, found, seen);
    }
    return;
  }
  if (node is! Map) return;
  final map = Map<String, dynamic>.from(node);
  final nextCategory = _categoryOf(map) ?? category;
  final name = _nameOf(map);
  final price = _priceOf(map);
  if (name != null && price != null) {
    final key = '${nextCategory.toLowerCase()}|${name.toLowerCase()}';
    if (seen.add(key)) {
      found.add(ZomatoDish(category: nextCategory, name: name, price: price));
    }
  }
  for (final value in map.values) {
    _walk(value, nextCategory, found, seen);
  }
}

String? _categoryOf(Map<String, dynamic> map) {
  for (final key in ['category_name', 'categoryName', 'section_name']) {
    final value = _clean(map[key]);
    if (value != null) return value;
  }
  final nested = map['category'];
  if (nested is Map) return _clean(nested['name']);
  if (nested is String) return _clean(nested);
  final section = _clean(map['name']);
  final looksLikeSection = map.containsKey('items') ||
      map.containsKey('dishes') ||
      map.containsKey('hasMenuItem') ||
      map.containsKey('menu_items');
  if (looksLikeSection) return section;
  return null;
}

String? _nameOf(Map<String, dynamic> map) {
  if (map.containsKey('items') ||
      map.containsKey('categories') ||
      map.containsKey('menus') ||
      map.containsKey('hasMenuSection')) {
    return null;
  }
  final value = _clean(map['item_name'] ?? map['dish_name'] ?? map['name']);
  if (value == null || value.length < 2 || value.length > 80) return null;
  final lower = value.toLowerCase();
  if (lower == 'zomato' || lower == 'menu' || lower.contains('restaurant')) {
    return null;
  }
  return value;
}

double? _priceOf(Map<String, dynamic> map) {
  final raw = map['price'] ??
      map['display_price'] ??
      map['min_price'] ??
      map['default_price'] ??
      map['base_price'];
  final direct = _amount(raw);
  if (direct != null) return direct;
  final offers = map['offers'];
  if (offers is Map) return _amount(offers['price'] ?? offers['lowPrice']);
  if (offers is List && offers.isNotEmpty && offers.first is Map) {
    final first = Map<String, dynamic>.from(offers.first as Map);
    return _amount(first['price']);
  }
  return null;
}

double? _amount(dynamic raw) {
  if (raw is num) {
    final value = raw.toDouble();
    if (value <= 0 || value > 100000) return null;
    return value;
  }
  if (raw is String) {
    final match = RegExp(r'\d+(?:\.\d{1,2})?').firstMatch(raw.replaceAll(',', ''));
    if (match == null) return null;
    return _amount(double.tryParse(match.group(0)!));
  }
  if (raw is Map) {
    return _amount(raw['amount'] ?? raw['value'] ?? raw['price'] ?? raw['display']);
  }
  return null;
}

String? _clean(dynamic raw) {
  final text = '$raw'.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty || text == 'null') return null;
  return text;
}

Future<List<ZomatoDish>> fetchZomatoMenu(
  String input, {
  http.Client? client,
}) async {
  final target = ZomatoMenuTarget.parse(input);
  final httpClient = client ?? http.Client();
  final close = client == null;
  try {
    Object? lastError;
    for (final uri in target.urls) {
      try {
        final response = await httpClient
            .get(
              uri,
              headers: const {
                'Accept': 'text/html,application/json',
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              },
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = ZomatoMenuException(
            'Zomato did not open that link (${response.statusCode}).',
          );
          continue;
        }
        final dishes = dishesFromZomatoBody(response.body);
        if (dishes.isNotEmpty) return dishes;
        lastError = const ZomatoMenuException(
          'That link opened, but it did not include a menu. Use the share link from Manage outlet.',
        );
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError is ZomatoMenuException) throw lastError;
    throw const ZomatoMenuException(
      'The Zomato menu could not be fetched. Check the link and try again.',
    );
  } finally {
    if (close) httpClient.close();
  }
}

Uint8List zomatoMenuCsv(List<ZomatoDish> dishes) {
  return voiceMenuCsv([
    for (final dish in dishes)
      VoiceMenuLine(category: dish.category, name: dish.name, price: dish.price),
  ]);
}
