import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/widgets/pos_ui.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1920, 900),
  ]) {
    testWidgets('account login is centered without hero at $size', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PosAuthScaffold(
            accent: Colors.orange,
            showHeroPanel: false,
            maxFormWidth: 500,
            compactHeader: const SizedBox(
              key: ValueKey('login-header'),
              height: 64,
              child: Text('SELFX'),
            ),
            headline: 'Staff panel',
            statusLabel: 'Staff POS',
            statusIcon: Icons.point_of_sale,
            form: const SizedBox(
              key: ValueKey('login-form'),
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
      expect(rect.center.dx, closeTo(size.width / 2, 1));
      final header = tester.getRect(find.byKey(const ValueKey('login-header')));
      final form = tester.getRect(find.byKey(const ValueKey('login-form')));
      expect((header.top + form.bottom) / 2, closeTo(size.height / 2, 1));
      expect(tester.takeException(), isNull);

      // A keyboard or a short landscape viewport must allow scrolling.
      tester.view.viewInsets = FakeViewPadding(bottom: size.height - 300);
      await tester.pump();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('login-form'))).bottom,
        lessThanOrEqualTo(300),
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    });
  }
}
