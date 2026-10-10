import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/screens/admin/admin_menu_edit_dialogs.dart';
import 'package:my_app/screens/admin/admin_menu_image_picker.dart';
import 'package:my_app/services/pos_api.dart';

class _ImageApi extends PosApi {
  String? generatedName;
  String? generatedCategory;
  final file = XFile.fromData(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
    ),
    name: 'category.png',
    mimeType: 'image/png',
  );

  @override
  Future<XFile> generateMenuItemImage(
    PosSession session, {
    required String name,
    String description = '',
    String style = 'catalog',
    String keywords = '',
    String? itemType,
    String? categoryName,
  }) async {
    generatedName = name;
    generatedCategory = categoryName;
    return file;
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in [320.0, 1200.0]) {
    testWidgets('photo actions fit and run at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var gallery = 0;
      var camera = 0;
      var ai = 0;
      Widget content(bool busy) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AdminMenuImagePickerSection(
                label: 'Photo',
                imageUrl: null,
                pickedImage: null,
                picking: busy,
                compactPreview: true,
                onPick: () => gallery++,
                onCamera: () => camera++,
                onGenerate: () => ai++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(content(false));
      await tester.tap(find.text('Update photo'));
      await tester.tap(find.text('Take photo'));
      await tester.tap(find.text('Generate with AI'));
      expect([gallery, camera, ai], [1, 1, 1]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(content(true));
      await tester.tap(find.text('Take photo'));
      await tester.tap(find.text('Generate with AI'));
      expect([gallery, camera, ai], [1, 1, 1]);
    });
  }

  testWidgets('category AI image is included when saving the category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _ImageApi();
    final pos = PosController()
      ..session = PosSession(
        serverUrl: 'https://example.test',
        token: 'test',
        restaurantId: 1,
        branchId: 1,
      );
    addTearDown(pos.dispose);
    AdminMenuCategoryEditResult? result;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PosApi>.value(value: api),
          ChangeNotifierProvider<PosController>.value(value: pos),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAdminMenuCategoryEditDialog(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Take photo'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Breakfast');
    await tester.tap(find.text('Generate with AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(api.generatedName, 'Breakfast');
    expect(api.generatedCategory, 'Breakfast');
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(result?.imageFile, same(api.file));
    expect(tester.takeException(), isNull);
  });
}
