import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/screens/admin/menu_import_source_sheet.dart';

void main() {
  testWidgets('full-width source page keeps all three choices and routes taps', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MenuImportSource? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MenuImportSourcePage(
      enableVoice: true, onSelect: (value) => selected = value,
    ))));
    expect(find.text('AI Menu Upload'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getSize(find.byType(MenuImportSourcePage)).width, 360);
    for (final entry in {
      'Photo or PDF': MenuImportSource.photo,
      'Voice': MenuImportSource.voice,
      'Zomato': MenuImportSource.zomato,
    }.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      expect(selected, entry.value);
    }
    expect(tester.takeException(), isNull);
  });
}
