import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/printing/report_slip_layout.dart';

void main() {
  test('56mm item reports use compact aligned columns and wrap names', () {
    final commands = wrapLongReportItemNames({}, [
      {'type': 'text', 'text': '81   CHOW CHOW BHATH  10   650.00'},
    ], lineWidth: 32);
    final lines = commands
        .whereType<Map>()
        .map((c) => c['text'] as String)
        .toList();
    expect(lines.first, startsWith('81   CHOW CHOW'));
    expect(lines.first, endsWith(' 10   650.00'));
    expect(lines.join('\n'), contains('BHATH'));
    expect(lines.every((line) => line.length <= 32), isTrue);
    expect(lines.any((line) => line == '-' * 32), isFalse);
  });
  test('56mm quantities never come from digits within the amount', () {
    for (final pair in [
      ('2', '200.00'),
      ('1', '121.00'),
      ('3', '3420.00'),
      ('4', '440.00'),
    ]) {
      final commands = wrapLongReportItemNames({}, [
        {
          'type': 'text',
          'text': '60   ONION UTTAPPA    ${pair.$1}   ${pair.$2}',
        },
      ], lineWidth: 32);
      final line = commands.first['text'] as String;
      expect(line.substring(20, 23).trim(), pair.$1);
      expect(line.substring(23).trim(), pair.$2);
      expect(line.length, 32);
    }
  });
  test('long report item names wrap instead of a clipped question mark', () {
    const clipped = '81   CHOW CHOW BH?  3   185.70';
    final commands = wrapLongReportItemNames(
      {
        'document': {
          'rows': [
            {
              'code': '81',
              'description': 'CHOW CHOW BHATH SPECIAL',
              'qty': '3',
              'amount': '185.70',
            },
          ],
        },
      },
      [
        {'type': 'text', 'text': 'ITEM WISE REPORT', 'align': 'center'},
        {'type': 'text', 'text': clipped},
        {'type': 'text', 'text': 'Gross Amount              890.46'},
      ],
    );

    final lines = commands
        .whereType<Map>()
        .map((command) => command['text'].toString())
        .toList();
    expect(lines.first, 'ITEM WISE REPORT');
    expect(lines.last, 'Gross Amount              890.46');
    final itemLines = lines.where((line) => line.contains('185.70')).toList();
    expect(itemLines, hasLength(1));
    expect(itemLines.single.contains('?'), isFalse);
    expect(itemLines.single.contains('CHOW CHOW'), isTrue);
    expect(lines.join('\n'), contains('SPECIAL'));
    expect(
      lines
          .where((line) => line.contains('SPECIAL') || line.contains('CHOW'))
          .length,
      greaterThan(1),
    );
    expect(lines.join('\n'), isNot(contains('?')));
  });

  test('short report item names stay on one line', () {
    const line = '73   IDLI - (2)     1    38.10';
    final commands = wrapLongReportItemNames(
      {
        'document': {
          'rows': [
            {
              'code': '73',
              'description': 'IDLI - (2)',
              'qty': '1',
              'amount': '38.10',
            },
          ],
        },
      },
      [
        {'type': 'text', 'text': line},
      ],
    );
    expect(commands.single['text'], line);
  });
}
