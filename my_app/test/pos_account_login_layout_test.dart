import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/widgets/pos_ui.dart';

void main() {
  for (final width in [320.0, 1920.0]) {
    testWidgets('account login is centered without hero at $width', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PosAuthScaffold(
            accent: Colors.orange,
            showHeroPanel: false,
            maxFormWidth: 500,
            compactHeader: const Text('SELFX'),
            headline: 'Staff panel',
            statusLabel: 'Staff POS',
            statusIcon: Icons.point_of_sale,
            form: const SizedBox(
              height: 400,
              width: double.infinity,
              child: Text('Log in to your account'),
            ),
          ),
        ),
      );
      expect(find.text('Staff panel'), findsNothing);
      expect(find.text('Log in to your account'), findsOneWidget);
      final rect = tester.getRect(find.text('Log in to your account'));
      expect(rect.center.dx, closeTo(width / 2, 1));
      expect(tester.takeException(), isNull);
    });
  }
}
