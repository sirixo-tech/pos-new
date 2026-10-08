import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/admin/menu_import_view.dart';

Widget view({bool review = true, bool published = false, VoidCallback? onCamera, TargetPlatform platform = TargetPlatform.windows}) => MaterialApp(
  theme: ThemeData(platform: platform),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child ?? const SizedBox.shrink(),
  ),
  home: MenuImportView(
    capabilities: {
      'max_upload_kb': 20480,
      'pdf_max_pages': 5,
      'ai_assist_available': true,
      'image_import_available': true,
    },
    import: published ? {'id': 42, 'status': 'completed', 'result': {'created': 0, 'updated': 0, 'skipped': 48, 'failed': 0}} : review
        ? {
            'id': 42,
            'filename': 'menu.csv',
            'status': 'awaiting_confirmation',
            'result': {
              'preview_rows': [
                {'secret_raw_result': 'should not render'},
              ],
            },
          }
        : null,
    rows: review
        ? [
            {'item_name': 'Soup', 'category_name': 'Starters', 'price': '100'},
            {'item_name': 'Tea', 'category_name': 'Drinks', 'price': '25'},
          ]
        : [],
    review: review,
    terminal: published,
    busy: false,
    ai: false,
    error: null,
    errors: null,
    selectedFile: null,
    selectedBytes: 0,
    onPick: () {},
    onCamera: onCamera,
    onUpload: () {},
    onClear: () {},
    onAiChanged: (_) {},
    onRetry: () {},
    onSave: () {},
    onConfirm: () {},
    onCancel: () {},
    onEdit: (_) {},
    onImage: (_) {},
    onRowChanged: (_, _, _) {},
    onDelete: (_) {},
    onErrors: () {},
  ),
);

void main() {
  testWidgets('phone offers camera capture and desktop keeps file upload', (tester) async {
    var captures = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(view(review: false, onCamera: () => captures++, platform: TargetPlatform.android));
    await tester.scrollUntilVisible(find.text('Take photo of menu'), 200);
    await tester.ensureVisible(find.text('Take photo of menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo of menu'));
    expect(captures, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(view(review: false, onCamera: () => captures++));
    await tester.pumpAndSettle();
    expect(find.text('Take photo of menu'), findsNothing);
  });
  testWidgets('published screen shows counts and actions without storefront preview', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(view(review: false, published: true));
    expect(find.text('Menu is live'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('View menu items'), findsOneWidget);
    expect(find.text('Open POS'), findsOneWidget);
    expect(find.text('Upload another menu'), findsOneWidget);
    expect(find.text('Preview storefront'), findsNothing);
    expect(find.text('Choose a menu photo or PDF'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'review shows editable items and fixed confirm action without raw results',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(view());
      expect(find.text('Confirm and go live'), findsOneWidget);
      expect(find.text('2 items ready'), findsOneWidget);
      expect(find.textContaining('secret_raw_result'), findsNothing);
      await tester.tap(find.text('Drinks 1'));
      await tester.pumpAndSettle();
      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Soup'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('upload is responsive and extraction waits for a selected file', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(view(review: false));
    await tester.scrollUntilVisible(find.text('Import spreadsheet'), 200);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Import spreadsheet'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
