import 'esc_pos_builder.dart';
import 'receipt_typography.dart';
import 'thermal_logo.dart';
import 'package:qr/qr.dart';

/// Executes server-generated print_object commands on a thermal printer.
class PrintObjectExecutor {
  PrintObjectExecutor({
    required this.paper,
    required this.fontSize,
    this.enableCurrencyGlyphs,
  }) : _typography = ReceiptTypography(receiptWidth: paper, fontSize: fontSize);

  final String paper;
  final String fontSize;
  final bool? enableCurrencyGlyphs;
  final ReceiptTypography _typography;

  Future<List<int>> buildBytes(List<dynamic> printObject) async {
    final esc = EscPosBuilder(
      typography: _typography,
      enableCurrencyGlyphs: enableCurrencyGlyphs,
    );
    var initialized = false;

    for (final entry in printObject) {
      if (entry is! Map) continue;
      final command = Map<String, dynamic>.from(entry);
      final type = command['type']?.toString() ?? '';

      switch (type) {
        case 'init':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
        case 'text':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
          await _text(esc, command);
        case 'row':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
          _row(esc, command);
        case 'divider':
        case 'dottedLine':
        case 'dotted_line':
        case 'separator':
        case 'line':
        case 'hr':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
          esc.resetToBaseFont();
          esc.hr();
        case 'feed':
        case 'feedLine':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
          esc.feed(_intValue(command['lines'], fallback: 1));
        case 'logo':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
          await _logo(esc, command);
        case 'qr':
        case 'qr_code':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
          _qr(esc, command);
        case 'cut':
        case 'fullCutPaper':
        case 'halfCutPaper':
        case 'partialCutPaper':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
          _cut(esc, command, type);
        case 'drawer':
        case 'open_drawer':
        case 'openDrawer':
          if (!initialized) {
            esc.initialize();
            initialized = true;
          }
          esc.openDrawer(
            pin: _intValue(command['pin'] ?? command['m'], fallback: 0),
            t1: _intValue(command['t1'] ?? command['on_time'], fallback: 0x3C),
            t2: _intValue(command['t2'] ?? command['off_time'], fallback: 0x78),
          );
        default:
          break;
      }
    }

    return esc.build();
  }

  static PrintObjectExecutor fromPayload(
    Map<String, dynamic> payload, {
    bool? enableCurrencyGlyphs,
  }) {
    final document = payloadFrom(payload);
    return PrintObjectExecutor(
      paper: _paperFrom(document) ?? '80mm',
      fontSize: document['font_size']?.toString() ?? 'medium',
      enableCurrencyGlyphs: enableCurrencyGlyphs,
    );
  }

  /// Keep enclosing API metadata when commands are wrapped in print_object.
  /// A document's own width takes precedence over an enclosing default.
  static Map<String, dynamic> payloadFrom(Map<String, dynamic> payload) {
    final direct = payload['print_object'] ?? payload['printObject'];
    if (direct is! Map) return Map<String, dynamic>.from(payload);
    final nested = Map<String, dynamic>.from(direct);
    final paper = _paperFrom(nested) ?? _paperFrom(payload);
    return {
      ...payload,
      ...nested,
      if (paper != null) 'paper': paper,
      if (paper != null) 'receipt_width': paper,
    };
  }

  static String? _paperFrom(Map<String, dynamic> payload) {
    for (final key in ['receipt_width', 'paper']) {
      final value = payload[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static List<dynamic> commandsFromPayload(Map<String, dynamic> payload) {
    final direct =
        payload['print_object'] ??
        payload['printObject'] ??
        payload['commands'];
    if (direct is List) return direct;
    if (direct is Map) {
      final nested = Map<String, dynamic>.from(direct);
      final inner =
          nested['print_object'] ?? nested['printObject'] ?? nested['commands'];
      if (inner is List) return inner;
    }
    return const [];
  }

  Future<void> _text(EscPosBuilder esc, Map<String, dynamic> command) async {
    final options = command['options'] is Map
        ? Map<String, dynamic>.from(command['options'] as Map)
        : <String, dynamic>{};

    final text = command['text']?.toString() ?? '';
    if (text.isEmpty) return;

    final align = _alignFrom(command['align'] ?? options['align']);
    final style = _styleFrom(command['style'], options).toLowerCase();

    _applyAlign(esc, align);
    esc.applyBlockStyle(style);
    esc.text(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
    esc.clearBlockStyle(style);
  }

  void _row(EscPosBuilder esc, Map<String, dynamic> command) {
    final left = command['left']?.toString() ?? '';
    final right = command['right']?.toString() ?? '';
    final style = (command['style']?.toString() ?? 'normal').toLowerCase();

    esc.resetToBaseFont();
    esc.alignLeft();
    if (style == 'bold' || style == 'title' || style == 'large_bold') {
      esc.bold(true);
    }
    esc.row(left, right);
    esc.bold(false);
    esc.resetToBaseFont();
  }

  Future<void> _logo(EscPosBuilder esc, Map<String, dynamic> command) async {
    final url = command['url']?.toString();
    final align = _alignFrom(command['align']);

    final raster = await ThermalLogo.rasterBytes(
      url: url,
      maxWidthDots: _logoMaxWidthDots(command),
      align: align,
      paperWidthDots: _typography.paperWidthDots,
    );

    esc.alignLeft();
    if (raster != null) {
      esc.raw(raster);
      esc.feed(1);
      esc.ensureRupeeGlyph();
    }
    esc.resetToBaseFont();
  }

  void _qr(EscPosBuilder esc, Map<String, dynamic> command) {
    final data = command['data']?.toString() ?? '';
    if (data.trim().isEmpty) return;

    _applyAlign(esc, _alignFrom(command['align']));
    final code = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
    // Reserve four blank modules on each side; use larger dots on wide heads.
    final preferredSize = _typography.paperWidthDots >= 576 ? 6 : 4;
    final fittingSize = (_typography.paperWidthDots / (code.moduleCount + 8)).floor();
    final moduleSize = preferredSize.clamp(1, fittingSize.clamp(1, 16));
    esc.feed(1);
    esc.qrCode(data, moduleSize: moduleSize);
    esc.feed(1);
    esc.resetToBaseFont();
  }

  void _cut(EscPosBuilder esc, Map<String, dynamic> command, String type) {
    final mode = (type == 'halfCutPaper' || type == 'partialCutPaper')
        ? 'partial'
        : (command['mode']?.toString() ?? 'full');
    esc.feed(_intValue(command['lines'], fallback: 2));
    esc.cut(mode: mode == 'partial' ? 'partial' : 'full');
  }

  void _applyAlign(EscPosBuilder esc, String align) {
    switch (align) {
      case 'center':
        esc.alignCenter();
      case 'right':
        esc.alignRight();
      default:
        esc.alignLeft();
    }
  }

  String _alignFrom(dynamic value) {
    if (value is int) {
      return switch (value) {
        1 => 'center',
        2 => 'right',
        _ => 'left',
      };
    }

    final normalized = value?.toString().toLowerCase() ?? 'left';
    if (normalized == 'center' || normalized == 'right') {
      return normalized;
    }
    return 'left';
  }

  String _styleFrom(dynamic style, Map<String, dynamic> options) {
    if (style != null && style.toString().isNotEmpty) {
      return style.toString();
    }

    final widthTimes = _intValue(options['widthTimes'], fallback: 1);
    final heightTimes = _intValue(options['heightTimes'], fallback: 1);
    if (widthTimes > 1 || heightTimes > 1) {
      return 'large_bold';
    }

    return 'normal';
  }

  int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _logoMaxWidthDots(Map<String, dynamic> command) {
    final fromCommand = _intValue(command['max_width_dots'], fallback: 0);
    if (fromCommand >= 16) {
      return fromCommand;
    }
    return _typography.logoMaxWidthDots;
  }
}
