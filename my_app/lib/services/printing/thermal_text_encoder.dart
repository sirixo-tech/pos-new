/// ESC/POS text encoding for thermal printers (ASCII + custom rupee glyph).
class ThermalTextEncoder {
  ThermalTextEncoder._();

  /// Placeholder byte replaced by the user-defined ₹ glyph (`^` is rare on receipts).
  static const int rupeeCharCode = 0x5E;

  static const int _rupeeRune = 0x20B9;

  /// Install ₹ via ESC & on `^` (0x5E), then ESC % 1 to enable.
  static List<int> rupeeSetupSequence({bool fontB = false}) {
    final width = fontB ? 9 : 12;
    final bitmap = fontB ? _rupeeBitmapFontB : _rupeeBitmapFontA;

    return [
      0x1B,
      0x25,
      0x00,
      0x1B,
      0x26,
      3,
      rupeeCharCode,
      rupeeCharCode,
      width,
      ...bitmap,
      0x1B,
      0x25,
      0x01,
    ];
  }

  static List<int> withoutUserDefinedChars(List<int> bytes) {
    final out = <int>[];
    var i = 0;
    while (i < bytes.length) {
      if (i + 2 < bytes.length && bytes[i] == 0x1B && bytes[i + 1] == 0x25) {
        i += 3;
        continue;
      }
      if (i + 5 < bytes.length && bytes[i] == 0x1B && bytes[i + 1] == 0x26) {
        final y = bytes[i + 2];
        final c1 = bytes[i + 3];
        final c2 = bytes[i + 4];
        var cursor = i + 5;
        final count = (c2 - c1 + 1).clamp(0, 32);
        var ok = y > 0 && count > 0;
        for (var n = 0; n < count && ok; n++) {
          if (cursor >= bytes.length) {
            ok = false;
            break;
          }
          final width = bytes[cursor];
          cursor += 1 + (y * width);
          if (cursor > bytes.length) {
            ok = false;
          }
        }
        if (ok) {
          i = cursor;
          continue;
        }
      }
      out.add(bytes[i]);
      i++;
    }
    return out;
  }

  static bool containsRupee(String value) {
    if (value.runes.contains(_rupeeRune)) {
      return true;
    }
    if (value.contains(String.fromCharCode(rupeeCharCode))) {
      return true;
    }

    return RegExp(r'\bRs\.?\s?', caseSensitive: false).hasMatch(value);
  }

  static List<int> encodeText(
    String value, {
    bool enableCurrencyGlyphs = true,
  }) {
    final normalized = normalizeText(
      value,
      enableCurrencyGlyphs: enableCurrencyGlyphs,
    );
    final bytes = <int>[];
    for (final rune in normalized.runes) {
      if (rune == _rupeeRune) {
        bytes.add(rupeeCharCode);
      } else if (rune >= 0x20 && rune <= 0x7E) {
        bytes.add(rune);
      } else {
        bytes.addAll(_fallbackBytes(rune));
      }
    }
    return bytes;
  }

  /// Normalize before wrapping so the ASCII currency fallback counts toward
  /// the paper's available columns, including right-aligned amounts.
  static String normalizeText(
    String value, {
    bool enableCurrencyGlyphs = true,
  }) {
    final rupee = enableCurrencyGlyphs
        ? String.fromCharCode(rupeeCharCode)
        : 'Rs ';
    return value
        .replaceAllMapped(
          RegExp(r'\bRs\.?\s?', caseSensitive: false),
          (_) => rupee,
        )
        .replaceAll('₹', rupee)
        .replaceAll('€', 'EUR ')
        .replaceAll('£', 'GBP ')
        .replaceAll('¥', 'JPY ')
        .replaceAll('₩', 'KRW ')
        .replaceAll('₱', 'PHP ')
        .replaceAll('฿', 'THB ')
        .replaceAll('₫', 'VND ')
        .replaceAll('₦', 'NGN ')
        .replaceAll('₺', 'TRY ')
        .replaceAll('₽', 'RUB ')
        .replaceAll('zł', 'PLN ')
        .replaceAll('·', ' - ')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u00a0', ' ');
  }

  static List<int> _fallbackBytes(int rune) {
    return [0x3F];
  }

  /// 12×24 ₹ — double top bars + left stem + diagonal leg (not a P-shaped loop).
  static const List<int> _rupeeBitmapFontA = [
    0x3F,
    0xFF,
    0xC0,
    0x3F,
    0xFF,
    0xC0,
    0xE0,
    0x01,
    0x00,
    0xE0,
    0x03,
    0x00,
    0xE0,
    0x06,
    0x00,
    0xE0,
    0x0C,
    0x00,
    0xE0,
    0x18,
    0x00,
    0xE0,
    0x30,
    0x00,
    0xE0,
    0x60,
    0x00,
    0xE0,
    0xC0,
    0x00,
    0x21,
    0x80,
    0x00,
    0x21,
    0x00,
    0x00,
  ];

  /// 9×24 ₹ for Font B (compressed receipts).
  static const List<int> _rupeeBitmapFontB = [
    0x3F,
    0xFF,
    0xC0,
    0xE0,
    0x01,
    0x00,
    0xE0,
    0x03,
    0x00,
    0xE0,
    0x06,
    0x00,
    0xE0,
    0x0C,
    0x00,
    0xE0,
    0x18,
    0x00,
    0xE0,
    0x30,
    0x00,
    0xE0,
    0x60,
    0x00,
    0xE0,
    0xC0,
    0x00,
  ];
}
