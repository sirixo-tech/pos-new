import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/printing/report_slip_layout.dart';

void main() {
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
    expect(lines.where((line) => line.contains('SPECIAL') || line.contains('CHOW')).length, greaterThan(1));
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
