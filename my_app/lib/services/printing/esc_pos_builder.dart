import 'dart:convert';

import 'receipt_typography.dart';
import 'thermal_text_encoder.dart';

/// Minimal ESC/POS byte builder for thermal receipt printers.
class EscPosBuilder {
  EscPosBuilder({
    required this.typography,
    this.enableCurrencyGlyphs = true,
  }) : lineWidth = typography.lineWidth;

  final ReceiptTypography typography;
  final bool enableCurrencyGlyphs;
  final int lineWidth;
  final List<int> _bytes = [];

  int _widthMul = 1;
  int _heightMul = 1;
  bool _emphasis = false;

  int get effectiveLineWidth => (lineWidth / _widthMul).floor().clamp(8, lineWidth);

  List<int> build() => List<int>.from(_bytes);

  void raw(List<int> value) => _bytes.addAll(value);

  void initialize() {
    _bytes.addAll([0x1B, 0x40]);
    resetToBaseFont();
  }

  /// Re-define the ₹ glyph for the active font (Font A vs Font B).
  void ensureRupeeGlyph() {
    if (!enableCurrencyGlyphs) {
      return;
    }
    _bytes.addAll(
      ThermalTextEncoder.rupeeSetupSequence(
        fontB: typography.useCompressedFont,
      ),
    );
  }

  void resetFontStyle() {
    _widthMul = 1;
    _heightMul = typography.useDoubleHeight ? 2 : 1;
    _bytes.addAll([0x1B, 0x4D, typography.useCompressedFont ? 0x01 : 0x00]);
    if (typography.useDoubleHeight) {
      _writeCharacterSize(widthMul: 1, heightMul: 2);
    } else {
      _writeCharacterSize(widthMul: 1, heightMul: 1);
    }
    bold(false);
    ensureRupeeGlyph();
  }

  void resetToBaseFont() {
    resetFontStyle();
    alignLeft();
  }

  void alignLeft() => _bytes.addAll([0x1B, 0x61, 0x00]);

  void alignCenter() => _bytes.addAll([0x1B, 0x61, 0x01]);

  void alignRight() => _bytes.addAll([0x1B, 0x61, 0x02]);

  void bold(bool enabled) {
    _emphasis = enabled;
    _bytes.addAll([0x1B, 0x45, enabled ? 0x01 : 0x00]);
  }

  void _resetCharacterSizeToBase() {
    _widthMul = 1;
    _heightMul = typography.useDoubleHeight ? 2 : 1;
    _bytes.addAll([0x1B, 0x4D, typography.useCompressedFont ? 0x01 : 0x00]);
    if (typography.useDoubleHeight) {
      _writeCharacterSize(widthMul: 1, heightMul: 2);
    } else {
      _writeCharacterSize(widthMul: 1, heightMul: 1);
    }
  }

  void _reapplyActiveFontState() {
    final baseHeight = typography.useDoubleHeight ? 2 : 1;
    if (_widthMul != 1 || _heightMul != baseHeight) {
      _writeCharacterSize(widthMul: _widthMul, heightMul: _heightMul);
    }
    if (_emphasis) {
      _bytes.addAll([0x1B, 0x45, 0x01]);
    }
  }

  void applyBlockStyle(String style) {
    switch (style.toLowerCase()) {
      case 'title':
      case 'large_bold':
        _resetCharacterSizeToBase();
        bold(true);
        _widthMul = 2;
        _heightMul = typography.useDoubleHeight ? 4 : 2;
        _writeCharacterSize(widthMul: 2, heightMul: _heightMul);
        return;
      case 'bold':
        _resetCharacterSizeToBase();
        bold(true);
        return;
      default:
        resetFontStyle();
    }
  }

  void clearBlockStyle(String style) {
    switch (style.toLowerCase()) {
      case 'title':
      case 'large_bold':
      case 'bold':
        resetFontStyle();
        return;
    }
  }

  void text(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final segments = normalized.split('\n');
    final maxChars = effectiveLineWidth;

    for (final segment in segments) {
      if (segment.isEmpty) {
        blankLine();
        continue;
      }
      var remaining = segment;
      while (remaining.isNotEmpty) {
        final chunk =
            remaining.length <= maxChars ? remaining : remaining.substring(0, maxChars);
        remaining =
            remaining.length <= maxChars ? '' : remaining.substring(maxChars);
        _emitTextLine(chunk);
      }
    }
  }

  void _emitTextLine(String line) {
    if (enableCurrencyGlyphs && ThermalTextEncoder.containsRupee(line)) {
      ensureRupeeGlyph();
      _reapplyActiveFontState();
    }
    _bytes.addAll(ThermalTextEncoder.encodeText(line));
    _bytes.add(0x0A);
  }

  void blankLine() => _bytes.add(0x0A);

  void hr() {
    final preserveBold = _emphasis;
    _resetCharacterSizeToBase();
    if (preserveBold) {
      bold(true);
    }
    text('-' * lineWidth);
  }

  void row(String left, String right) {
    final preserveBold = _emphasis;
    resetToBaseFont();
    alignLeft();
    if (preserveBold) {
      bold(true);
    }

    final width = lineWidth;
    // Keep amount on one line; wrap long labels (matches HTML receipt preview).
    final rightPart = right.length <= width ? right : _truncate(right, width);
    final maxLeft = width - rightPart.length;

    if (maxLeft < 1) {
      _wrapEmitLines(left, width);
      alignRight();
      text(rightPart);
      alignLeft();
      return;
    }

    if (left.length <= maxLeft) {
      final gap = width - left.length - rightPart.length;
      _emitTextLine('$left${' ' * gap}$rightPart');
      return;
    }

    final firstChunk = _fitChunk(left, maxLeft);
    final gap = width - firstChunk.length - rightPart.length;
    _emitTextLine('$firstChunk${' ' * gap}$rightPart');
    _wrapEmitLines(left.substring(firstChunk.length).trimLeft(), width);
  }

  void _wrapEmitLines(String value, int width) {
    var remaining = value;
    while (remaining.isNotEmpty) {
      final chunk = _fitChunk(remaining, width);
      _emitTextLine(chunk);
      remaining = remaining.substring(chunk.length).trimLeft();
    }
  }

  /// Take up to [maxLength] characters, preferring a word boundary.
  static String _fitChunk(String value, int maxLength) {
    if (maxLength < 1) return '';
    if (value.length <= maxLength) return value;
    final window = value.substring(0, maxLength);
    final space = window.lastIndexOf(' ');
    final minBreak = (maxLength / 3).floor();
    if (space >= minBreak) {
      return window.substring(0, space);
    }
    return window;
  }

  void feed(int lines) {
    for (var i = 0; i < lines; i++) {
      _bytes.add(0x0A);
    }
  }

  /// ESC/POS QR code (model 2, error correction M).
  void qrCode(String data, {int moduleSize = 4}) {
    final payload = utf8.encode(data);
    if (payload.isEmpty) {
      return;
    }

    final size = moduleSize.clamp(1, 16);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

    final storeLen = payload.length + 3;
    _bytes.addAll([
      0x1D,
      0x28,
      0x6B,
      storeLen & 0xFF,
      (storeLen >> 8) & 0xFF,
      0x31,
      0x50,
      0x30,
    ]);
    _bytes.addAll(payload);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
  }

  /// [mode] `full` (GS V 0) separates the slip; `partial` (GS V 1) leaves a small tab.
  void cut({String mode = 'full'}) {
    _bytes.addAll(cutCommand(mode: mode));
  }

  /// Feed lines + cut without initializing the printer (for multi-segment jobs).
  static List<int> cutSequence({String mode = 'full', int feedLines = 2}) {
    final bytes = <int>[];
    for (var i = 0; i < feedLines; i++) {
      bytes.add(0x0A);
    }
    bytes.addAll(cutCommand(mode: mode));
    return bytes;
  }

  static List<int> cutCommand({String mode = 'full'}) {
    final partial = mode == 'partial';
    return [0x1D, 0x56, partial ? 0x01 : 0x00];
  }

  /// Kick a connected cash drawer (ESC p pin 2).
  void openDrawer({int pin = 0, int t1 = 0x3C, int t2 = 0x78}) {
    raw(drawerCommand(pin: pin, t1: t1, t2: t2));
  }

  static List<int> drawerCommand({
    int pin = 0,
    int t1 = 0x3C,
    int t2 = 0x78,
  }) {
    return [0x1B, 0x70, pin.clamp(0, 1), t1.clamp(0, 255), t2.clamp(0, 255)];
  }

  void _writeCharacterSize({required int widthMul, required int heightMul}) {
    final w = (widthMul - 1).clamp(0, 7);
    final h = (heightMul - 1).clamp(0, 7);
    _widthMul = widthMul.clamp(1, 8);
    _heightMul = heightMul.clamp(1, 8);
    final n = w | (h << 4);
    _bytes.addAll([0x1D, 0x21, n]);
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    if (maxLength <= 3) return value.substring(0, maxLength);
    return '${value.substring(0, maxLength - 3)}...';
  }
}
