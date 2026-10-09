import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/pos_empty_menu_setup.dart';

void main() {
  testWidgets('dashboard food asset is bundled and decodes', (tester) async {
    await tester.runAsync(() async {
      final bytes = await rootBundle.load('assets/images/menu_setup_food.png');
      expect(bytes.lengthInBytes, greaterThan(0));
      final image = await decodeImageFromList(bytes.buffer.asUint8List());
      expect(image.width, greaterThan(0));
      expect(image.height, greaterThan(0));
      image.dispose();
    });
  });
  for (final width in [220.0, 320.0, 540.0, 760.0, 1100.0]) {
    testWidgets('empty menu actions fit and work at $width', (tester) async {
      tester.view.physicalSize = Size(width, width == 540 ? 640 : 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosEmptyMenuSetup(
              onAdd: () => tapped.add('add'),
              onImport: () => tapped.add('import'),
              onAi: () => tapped.add('ai'),
              onZomato: () => tapped.add('zomato'),
            ),
          ),
        ),
      );
      if (width == 540) {
        expect(
          tester.getBottomRight(find.text('Sync your Zomato menu')).dy,
          lessThanOrEqualTo(640),
        );
      }
      expect(
        find.byKey(const ValueKey('menu-setup-food')),
        width < 600 || width == 760 ? findsNothing : findsOneWidget,
      );
      for (final label in [
        'Add Menu Items',
        'Import Menu',
        'AI Setup',
        'Import from ZOMATO',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
      }
      expect(tapped, ['add', 'import', 'ai', 'zomato']);
      expect(tester.takeException(), isNull);
    });
  }
}
