import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/admin/menu_import_progress.dart';

Widget panel(num? progress) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: MenuImportProgress(
        progress: progress,
        items: 0,
        filename: 'menu.jpg',
        publishing: false,
        busy: false,
        onRetry: () {},
        onCancel: () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('shows server percentage and the corresponding progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(panel(43));
    expect(find.text('43%'), findsOneWidget);
    expect(find.text('AI is scanning your menu'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.43,
    );
    expect(find.textContaining('Elapsed:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'does not fabricate a percentage when server progress is absent',
    (tester) async {
      await tester.pumpWidget(panel(null));
      expect(find.text('Waiting for progress'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
