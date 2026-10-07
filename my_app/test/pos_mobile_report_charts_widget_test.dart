import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/pos_daily_report.dart';
import 'package:my_app/widgets/pos_mobile_report_charts.dart';

void main() {
  testWidgets('revenue and status charts paint without an error', (tester) async {
    final days = [
      for (var i = 0; i < 7; i++)
        PosDayRevenue(day: DateTime(2026, 10, 1 + i), amount: i == 5 ? 90494 : 120),
    ];
    final slices = [
      for (final slice in posReportStatusSlices)
        PosStatusCount(
          status: slice.status,
          label: slice.label,
          count: slice.status == 'pending' ? 291 : 10,
          colorValue: slice.color,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PosRevenueChartCard(days: days, loading: false),
              PosStatusChartCard(slices: slices, loading: false),
              PosRevenueChartCard(days: const [], loading: false),
              PosStatusChartCard(slices: const [], loading: false),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Revenue (last 7 days)'), findsWidgets);
    expect(find.text('Orders by status'), findsWidgets);
    expect(find.text('Pending 291'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: PosRevenueChartCard(days: days, loading: false),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosStatusChartCard(
            slices: [],
            loading: false,
            error: 'Too many attempts. Wait a moment, then try again.',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No orders in the last 7 days.'), findsNothing);
    expect(
      find.text('Too many attempts. Wait a moment, then try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
