import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/l10n/pos_l10n.dart';
import 'package:my_app/screens/admin/admin_menu_image_picker.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(620, 880),
    const Size(1440, 900),
  ]) {
    testWidgets('category preview stays compact at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: size.width > 600 ? 448 : size.width - 32,
                child: AdminMenuImagePickerSection(
                  label: 'Category image',
                  imageUrl: null,
                  pickedImage: null,
                  picking: false,
                  onPick: () {},
                  compactPreview: true,
                ),
              ),
            ),
          ),
        ),
      );
      final preview = find.byType(ClipRRect);
      expect(tester.getSize(preview).height, lessThanOrEqualTo(180));
      expect(tester.takeException(), isNull);
    });
  }
}
