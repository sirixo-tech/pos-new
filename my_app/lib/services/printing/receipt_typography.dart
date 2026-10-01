/// Line widths and ESC/POS sizing for thermal receipt printers.
class ReceiptTypography {
  ReceiptTypography({required this.receiptWidth, required this.fontSize});

  final String receiptWidth;
  final String fontSize;

  static String normalizeReceiptWidth(String? width) {
    switch ((width ?? '').trim().toLowerCase().replaceAll(' ', '')) {
      case '56':
      case '58':
      case '56mm':
      case '58mm':
        return '56mm';
      case '72':
      case '72mm':
        return '72mm';
      case '112':
      case '112mm':
      case 'full':
        return '112mm';
      case '80':
      case '80mm':
        return '80mm';
      default:
        return '80mm';
    }
  }

  String get _paper => normalizeReceiptWidth(receiptWidth);

  int get lineWidth {
    switch (_paper) {
      case '56mm':
        return 32;
      case '72mm':
        switch (fontSize) {
          case 'small':
            return 48;
          case 'large':
            return 42;
          default:
            return 42;
        }
      case '112mm':
        switch (fontSize) {
          case 'small':
            return 78;
          case 'large':
            return 67;
          default:
            return 67;
        }
      default:
        switch (fontSize) {
          case 'small':
            return 56;
          case 'large':
            return 48;
          default:
            return 48;
        }
    }
  }

  int lineWidthForStyle(String style) {
    if (style == 'title' || style == 'large_bold') {
      return (lineWidth / 2).floor().clamp(16, lineWidth);
    }
    return lineWidth;
  }

  bool get useCompressedFont => fontSize == 'small';

  /// Character cell width in dots (Font A = 12, Font B = 9 at 203 dpi).
  int get charWidthDots => useCompressedFont ? 9 : 12;

  /// Printable row width in dots — derived from column count, not raw paper width.
  int get rowPrintableWidthDots => lineWidth * charWidthDots;

  bool get useDoubleHeight => fontSize == 'large';

  /// Printable width in dots (203 dpi thermal).
  int get paperWidthDots {
    switch (_paper) {
      case '56mm':
        return 384;
      case '72mm':
        return 512;
      case '112mm':
        return 806;
      default:
        return 576;
    }
  }

  int get logoMaxWidthDots => paperWidthDots;

  static String normalizeLogoSize(String? size) {
    switch (size) {
      case 'small':
      case 'large':
        return size!;
      default:
        return 'medium';
    }
  }

  static String effectiveLogoSize({
    required String receiptLogoSize,
    String? tokenLogoSize,
  }) {
    if (tokenLogoSize == 'small' ||
        tokenLogoSize == 'medium' ||
        tokenLogoSize == 'large') {
      return tokenLogoSize!;
    }
    return normalizeLogoSize(receiptLogoSize);
  }

  static int logoMaxWidthDotsFor(String paper, String logoSize) {
    final base = switch (normalizeReceiptWidth(paper)) {
      '56mm' => 384,
      '72mm' => 512,
      '112mm' => 806,
      _ => 576,
    };

    final scale = switch (normalizeLogoSize(logoSize)) {
      'small' => 0.28,
      'large' => 0.52,
      _ => 0.40,
    };

    return (base * scale).round();
  }

  int logoMaxWidthDotsForReceipt(String logoSize) =>
      logoMaxWidthDotsFor(_paper, logoSize);

  int logoMaxWidthDotsForToken({
    required String receiptLogoSize,
    String? tokenLogoSize,
  }) => logoMaxWidthDotsFor(
    _paper,
    effectiveLogoSize(
      receiptLogoSize: receiptLogoSize,
      tokenLogoSize: tokenLogoSize,
    ),
  );
}
