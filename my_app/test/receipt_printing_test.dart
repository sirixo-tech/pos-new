import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/receipt_print_models.dart';
import 'package:my_app/models/receipt_template.dart';
import 'package:my_app/services/printing/esc_pos_builder.dart';
import 'package:my_app/services/printing/print_object_executor.dart';
import 'package:my_app/services/printing/receipt_template_renderer.dart';
import 'package:my_app/services/printing/receipt_typography.dart';
import 'package:my_app/services/printing/thermal_text_encoder.dart';

void main() {
  test('payment QR uses larger modules on 80mm and retains narrow-paper sizing', () async {
    const data = 'upi://pay?pa=SIRIXO01@ybl&pn=Coffee%20Cafe&am=240.00&cu=INR';
    for (final entry in {'56mm': 4, '80mm': 6}.entries) {
      final bytes = await PrintObjectExecutor(paper: entry.key, fontSize: 'normal')
          .buildBytes([{'type': 'qr', 'data': data, 'align': 'center'}]);
      expect(bytes, containsAllInOrder([0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x43, entry.value]));
    }
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Android USB KOT and receipt omit unsupported character bitmaps',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final bytes = await PrintObjectExecutor.fromPayload({'paper': '80mm'})
          .buildBytes([
            {'type': 'init'},
            {'type': 'text', 'text': 'KITCHEN ORDER', 'style': 'title'},
            {'type': 'text', 'text': 'TOKEN #7', 'style': 'title'},
            {'type': 'text', 'text': 'Date: 01 Oct 2026 11:42 AM'},
            {'type': 'divider'},
            {'type': 'text', 'text': '1x Bisibele Bhath'},
            {'type': 'cut'},
            {'type': 'text', 'text': 'Coffee Cafe', 'style': 'title'},
            {'type': 'row', 'left': '1x Bisibele Bhath', 'right': '₹60.00'},
            {'type': 'cut'},
          ]);
      expect(_contains(bytes, [0x1b, 0x26]), isFalse);
      expect(_contains(bytes, [0x1b, 0x25]), isFalse);
      expect(bytes.every((byte) => byte < 128), isTrue);
      final lines = _textLines(bytes);
      expect(lines, contains('KITCHEN ORDER'));
      expect(lines, contains('Date: 01 Oct 2026 11:42 AM'));
      expect(
        lines.where((line) => line.contains('Rs 60.00')).single.length,
        48,
      );
    },
  );

  test('Windows retains supported currency glyphs and normal title sizing', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final esc = EscPosBuilder(
      typography: ReceiptTypography(receiptWidth: '80mm', fontSize: 'medium'),
    );
    esc.initialize();
    esc.applyBlockStyle('title');
    esc.text('KITCHEN ORDER');
    expect(_contains(esc.build(), [0x1b, 0x26]), isTrue);
    expect(_contains(esc.build(), [0x1d, 0x21, 0x11]), isTrue);
    expect(_textLines(esc.build()), contains('KITCHEN ORDER'));
  });

  test('large font doubles height without reducing the API paper columns', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final esc = EscPosBuilder(
      typography: ReceiptTypography(receiptWidth: '80mm', fontSize: 'large'),
    );
    esc.initialize();
    esc.text('Date: 01 Oct 2026 11:42 AM');
    expect(_contains(esc.build(), [0x1d, 0x21, 0x01]), isTrue);
    expect(_contains(esc.build(), [0x1d, 0x21, 0x10]), isFalse);
    esc.applyBlockStyle('title');
    expect(_contains(esc.build(), [0x1d, 0x21, 0x13]), isTrue);
  });

  for (final entry in {
    '58mm': 32,
    '72mm': 42,
    '80mm': 48,
    '112mm': 67,
  }.entries) {
    test(
      'wrapped API payload preserves ${entry.key} paper and row alignment',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final payload = PrintObjectExecutor.payloadFrom({
          'receipt_width': entry.key,
          'font_size': 'medium',
          'print_object': {
            'commands': [
              {'type': 'divider'},
              {'type': 'row', 'left': 'Item', 'right': 'Amount'},
              {'type': 'row', 'left': '1x Bisibele Bhath', 'right': '60.00'},
            ],
          },
        });
        final executor = PrintObjectExecutor.fromPayload(payload);
        final bytes = await executor.buildBytes(
          PrintObjectExecutor.commandsFromPayload(payload),
        );
        final lines = _textLines(bytes);
        expect(lines.first, '-' * entry.value);
        expect(lines.every((line) => line.length == entry.value), isTrue);
        expect(lines.last.endsWith('60.00'), isTrue);
      },
    );
  }

  test(
    'document paper overrides enclosing defaults and accepts API aliases',
    () {
      expect(
        PrintObjectExecutor.fromPayload({
          'receipt_width': '80mm',
          'printObject': {'paper': '58mm', 'commands': []},
        }).paper,
        '58mm',
      );
      expect(
        PrintObjectExecutor.fromPayload({'receipt_width': 58}).paper,
        '58',
      );
      final settings = PosReceiptSettings.fromJson({'receipt_width': 58});
      expect(settings.paper, '56mm');
      final type = ReceiptTypography(receiptWidth: '58 MM', fontSize: 'medium');
      expect(type.lineWidth, 32);
      expect(type.paperWidthDots, 384);
    },
  );

  test(
    'ASCII currency fallback fits a narrow receipt and preserves literal carets',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final esc = EscPosBuilder(
        typography: ReceiptTypography(receiptWidth: '58mm', fontSize: 'medium'),
      );
      esc.initialize();
      esc.row('A long item name filling the slip', '₹1,234.00');
      esc.text('Note ^ is literal');
      final lines = _textLines(esc.build());
      expect(lines.every((line) => line.length <= 32), isTrue);
      expect(lines.first.endsWith('Rs 1,234.00'), isTrue);
      expect(lines, contains('Note ^ is literal'));
    },
  );

  test('offline Android templates use the same safe currency output', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final renderer = ReceiptTemplateRenderer(
      venue: const PrintVenueContext(
        restaurantName: 'Coffee Cafe',
        currencyCode: 'INR',
        branchName: 'Bangalore',
      ),
      order: const OfflinePrintOrder(
        orderNumber: 'ORD-7',
        paymentStatus: 'paid',
        subtotal: 60,
        total: 60,
        items: [],
      ),
      settings: PosReceiptSettings(paper: '58mm', showCurrencySymbol: true),
      template: ReceiptTemplate(
        version: 1,
        blocks: [ReceiptTemplateBlock(type: 'text', value: 'Total ₹60.00')],
      ),
    );
    final bytes = await renderer.buildBytes();
    expect(_contains(bytes, [0x1b, 0x26]), isFalse);
    expect(_textLines(bytes), contains('Total Rs 60.00'));
  });
}

bool _contains(List<int> bytes, List<int> sequence) {
  for (var i = 0; i <= bytes.length - sequence.length; i++) {
    if (listEquals(bytes.sublist(i, i + sequence.length), sequence)) {
      return true;
    }
  }
  return false;
}

/// Read text from these text-only ESC/POS jobs, excluding control commands and
/// Windows currency bitmaps. This checks physical columns rather than source
/// strings containing commands that a printer could accidentally render.
List<String> _textLines(List<int> input) {
  final bytes = ThermalTextEncoder.withoutUserDefinedChars(input);
  final lines = <String>[];
  final line = <int>[];
  var cursor = 0;
  while (cursor < bytes.length) {
    final byte = bytes[cursor];
    if (byte == 0x1b || byte == 0x1d) {
      cursor += byte == 0x1b && bytes[cursor + 1] == 0x40 ? 2 : 3;
    } else if (byte == 0x0a) {
      if (line.isNotEmpty) lines.add(String.fromCharCodes(line));
      line.clear();
      cursor++;
    } else {
      line.add(byte);
      cursor++;
    }
  }
  return lines;
}
