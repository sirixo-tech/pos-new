import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Parses order numbers from USB scanner input (plain ORD-… or track URLs).
class OrderBarcodeScan {
  OrderBarcodeScan({
    required this.onScan,
    this.maxGapMs = 750,
  });

  final void Function(String payload) onScan;
  final int maxGapMs;

  String _buffer = '';
  int _lastKeyMs = 0;
  Timer? _idleFlushTimer;

  static final RegExp _orderNumberPattern = RegExp(
    r'[A-Z0-9][A-Z0-9_-]{0,31}-[A-Z0-9][A-Z0-9_-]*',
  );

  void dispose() {
    _idleFlushTimer?.cancel();
    _idleFlushTimer = null;
  }

  /// True for an order slip: an order URL, or a code that starts with ORD-.
  /// A product barcode is not an order just because it contains a hyphen.
  static bool isOrderReference(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    if (RegExp(r'^ORD[-_]', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;
    final parameters = <String, String>{
      for (final entry in uri.queryParameters.entries)
        entry.key.toLowerCase(): entry.value,
    };
    const orderKeys = [
      'order_number',
      'ordernumber',
      'order_no',
      'orderno',
      'order',
      'reference',
    ];
    if (orderKeys.any((key) => (parameters[key] ?? '').trim().isNotEmpty)) {
      return true;
    }
    final segments = uri.pathSegments;
    for (var index = 0; index + 1 < segments.length; index++) {
      if (segments[index].toLowerCase() == 'order') return true;
    }
    return false;
  }

  static String? parseOrderNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final parameters = <String, String>{
        for (final entry in uri.queryParameters.entries)
          entry.key.toLowerCase(): entry.value,
      };
      for (final key in const [
        'order_number',
        'ordernumber',
        'order_no',
        'orderno',
        'order',
        'reference',
      ]) {
        final queryValue = parameters[key]?.trim();
        if (queryValue == null || queryValue.isEmpty) continue;
        final parsed = _orderNumberFromText(queryValue);
        if (parsed != null) return parsed;
      }
      final pathSegments = uri.pathSegments;
      for (var index = 0; index + 1 < pathSegments.length; index++) {
        if (pathSegments[index].toLowerCase() != 'order') continue;
        final token = Uri.decodeComponent(pathSegments[index + 1]).trim();
        if (token.isNotEmpty) return token.toUpperCase();
      }
    }

    return _orderNumberFromText(trimmed);
  }

  static String? _orderNumberFromText(String value) {
    final upper = Uri.decodeComponent(value).trim().toUpperCase();
    if (RegExp('^${_orderNumberPattern.pattern}\$').hasMatch(upper)) {
      return upper;
    }
    return _orderNumberPattern.firstMatch(upper)?.group(0);
  }

  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    if (_isTextInputFocused()) {
      return false;
    }

    final logical = event.logicalKey;
    if (_isModifier(logical)) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_buffer.isNotEmpty && now - _lastKeyMs > maxGapMs) {
      _buffer = '';
    }

    if (_isTerminator(event)) {
      final consumed = _commitBuffer();
      return consumed || _shouldConsumeAndroid(event);
    }

    final ch = _characterFromKey(event);
    if (ch == null) {
      return false;
    }

    _lastKeyMs = now;
    _buffer += ch;
    _scheduleIdleFlush();
    return _shouldConsumeAndroid(event);
  }

  bool _commitBuffer() {
    _idleFlushTimer?.cancel();
    final payload = _buffer.trim();
    _buffer = '';
    if (payload.isEmpty) return false;
    onScan(payload);
    return true;
  }

  void _scheduleIdleFlush() {
    _idleFlushTimer?.cancel();
    final delay = defaultTargetPlatform == TargetPlatform.android
        ? const Duration(milliseconds: 250)
        : Duration(milliseconds: maxGapMs + 40);
    _idleFlushTimer = Timer(delay, () {
      if (_buffer.trim().length < 3) {
        return;
      }
      _commitBuffer();
    });
  }

  static bool _shouldConsumeAndroid(KeyDownEvent event) {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return event.character?.isNotEmpty == true ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.tab;
  }

  static bool _isModifier(LogicalKeyboardKey logical) {
    return logical == LogicalKeyboardKey.shift ||
        logical == LogicalKeyboardKey.shiftLeft ||
        logical == LogicalKeyboardKey.shiftRight ||
        logical == LogicalKeyboardKey.control ||
        logical == LogicalKeyboardKey.controlLeft ||
        logical == LogicalKeyboardKey.controlRight ||
        logical == LogicalKeyboardKey.alt ||
        logical == LogicalKeyboardKey.altLeft ||
        logical == LogicalKeyboardKey.altRight ||
        logical == LogicalKeyboardKey.meta ||
        logical == LogicalKeyboardKey.metaLeft ||
        logical == LogicalKeyboardKey.metaRight ||
        logical == LogicalKeyboardKey.capsLock;
  }

  static bool _isTerminator(KeyDownEvent event) {
    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.numpadEnter ||
        logical == LogicalKeyboardKey.tab) {
      return true;
    }

    final character = event.character;
    return character == '\n' || character == '\r' || character == '\t';
  }

  static String? _characterFromKey(KeyDownEvent event) {
    final character = event.character;
    if (character != null && character.isNotEmpty) {
      final code = character.codeUnitAt(0);
      if (code >= 32 && code != 127) {
        return character;
      }
    }

    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.minus ||
        logical == LogicalKeyboardKey.numpadSubtract) {
      return '-';
    }
    if (logical == LogicalKeyboardKey.underscore) {
      return '_';
    }

    final label = logical.keyLabel;
    if (label.length == 1) {
      return label;
    }

    return null;
  }

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) {
      return false;
    }

    final context = focus.context;
    if (context == null) {
      return false;
    }

    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}

/// iMin may report one scan through both broadcast and keyboard output.
class ScannerDeliveryFilter {
  String? _lastOrder;
  bool _lastWasBroadcast = false;
  DateTime? _lastAt;

  bool accept(String order, {required bool broadcast, DateTime? now}) {
    final time = now ?? DateTime.now();
    if (_lastOrder == order &&
        _lastWasBroadcast != broadcast &&
        _lastAt != null &&
        time.difference(_lastAt!) < const Duration(seconds: 2)) {
      return false;
    }
    _lastOrder = order;
    _lastWasBroadcast = broadcast;
    _lastAt = time;
    return true;
  }
}
