import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/pos_sales_insights_card.dart';

void main() {
  testWidgets('overview insights card generates from the web timeframe', (tester) async {
    String? sent;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: PosSalesInsightsCard(
            generate: (timeframe) async {
              sent = timeframe;
              return {
                'headline': 'Breakfast led the week.',
                'stats': {
                  'timeframe_label': 'Past month',
                  'orders': 12,
                  'revenue': '₹4,500',
                },
                'sections': [
                  {
                    'title': 'What sold',
                    'summary': 'Dosa stayed ahead.',
                    'bullets': ['Repeat guests asked for chutney.'],
                  },
                ],
              };
            },
          ),
        ),
      ),
    );
    expect(find.text('No insights generated yet'), findsOneWidget);
    await tester.tap(find.text('Generate insights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(sent, 'month');
    expect(find.text('Breakfast led the week.'), findsOneWidget);
    expect(find.text('What sold'), findsOneWidget);
    expect(find.text('Repeat guests asked for chutney.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
