import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/admin/admin_menu_setup_guide.dart';

void main() {
  for (final width in [320.0, 760.0, 1050.0, 1400.0]) {
    testWidgets('menu setup fits width $width and starts editing', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width >= 1050 ? 500 : 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMenuSetupGuide(onGetStarted: () => started = true),
          ),
        ),
      );
      expect(find.text('Set up your menu'), findsOneWidget);
      expect(find.text('Add variations (optional)'), findsOneWidget);
      final cardSizes = [
        for (var i = 0; i < 4; i++)
          tester.getSize(find.byKey(ValueKey('menu-setup-step-$i'))),
      ];
      final previewSizes = [
        for (var i = 0; i < 4; i++)
          tester.getSize(find.byKey(ValueKey('menu-setup-preview-$i'))),
      ];
      expect(cardSizes.every((size) => size == cardSizes.first), isTrue);
      expect(previewSizes.every((size) => size == previewSizes.first), isTrue);
      if (width >= 1050) {
        expect(find.byType(Scrollable), findsNothing);
        expect(
          tester.getBottomRight(find.text('Get started')).dy,
          lessThanOrEqualTo(500),
        );
      }
      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      expect(started, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
