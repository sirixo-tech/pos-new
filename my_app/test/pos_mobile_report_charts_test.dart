import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/pos_daily_report.dart';

void main() {
  test('last 7 days ends today and stays in order', () {
    final days = last7ReportDays(DateTime(2026, 10, 7, 15));
    expect(days, hasLength(7));
    expect(days.first, DateTime(2026, 10, 1));
    expect(days.last, DateTime(2026, 10, 7));
  });

  test('summary total is revenue and order counts are ignored', () {
    final amount = revenueFromThermalDocument({
      'totals': [
        {'label': 'Total orders', 'display': '42'},
        {'label': 'Total', 'display': '₹90,494.00'},
      ],
    });
    expect(amount, 90494);
  });

  test('plain amount fields are accepted', () {
    expect(parseReportAmount('1,250.50'), 1250.50);
    expect(parseReportAmount(80), 80);
  });

  test('order totals accept wrapped, string, and decimal counts', () {
    expect(
      ordersTotalFromResponse({
        'data': [
          {'id': 1},
        ],
        'meta': {'total': 291},
      }),
      291,
    );
    expect(
      ordersTotalFromResponse({
        'data': {
          'data': [
            {'id': 1},
          ],
          'meta': {'total': '382'},
        },
      }),
      382,
    );
    expect(
      ordersTotalFromResponse({
        'meta': {'total': 494.0},
      }),
      494,
    );
    expect(
      ordersTotalFromResponse({
        'data': [
          {'id': 1},
        ],
        'pagination': {'total': 266},
      }),
      266,
    );
  });

  test('day labels do not depend on locale data', () {
    expect(reportDayLabel(DateTime(2026, 10, 1)), 'Oct 1');
  });
}
