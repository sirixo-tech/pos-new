import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/models/admin_models.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/screens/admin/admin_menu_edit_dialogs.dart';
import 'package:my_app/screens/pos_billing_screen.dart';
import 'package:my_app/widgets/pos_plan_selection_header_card.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('ItemEditDialog shows Cancel and Save side-by-side on mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showAdminMenuItemEditDialog(
                  context,
                  item: AdminMenuItem(
                    id: 1,
                    name: 'pakoda',
                    price: 100.0,
                    isAvailable: true,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    final cancelTop = tester.getTopLeft(find.text('Cancel')).dy;
    final saveTop = tester.getTopLeft(find.text('Save')).dy;

    // Both buttons must be rendered on the same horizontal row (side-by-side)
    expect((cancelTop - saveTop).abs(), lessThan(5.0));
  });

  testWidgets('CategoryEditDialog shows Delete option when editing category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AdminMenuCategoryEditResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showAdminMenuCategoryEditDialog(
                  context,
                  category: AdminMenuCategory(
                    id: 10,
                    name: 'Beverages',
                    isActive: true,
                    items: const [],
                  ),
                );
              },
              child: const Text('Open Category'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Category'));
    await tester.pumpAndSettle();

    // Verify Delete category option exists
    expect(find.text('Delete category'), findsOneWidget);

    // Tap Delete category
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('Delete category?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(result?.isDelete, isTrue);
  });

  testWidgets('PosPlanSelectionHeaderCard renders and navigates to PosBillingScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pos = PosController()
      ..session = PosSession(
        serverUrl: 'https://example.test',
        token: 'test',
        restaurantId: 1,
        branchId: 1,
      );
    addTearDown(pos.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PosController>.value(
        value: pos,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: PosPlanSelectionHeaderCard(),
          ),
        ),
      ),
    );

    expect(find.text('Business Growth Plan'), findsOneWidget);
    await tester.tap(find.byType(PosPlanSelectionHeaderCard));
    await tester.pumpAndSettle();

    expect(find.byType(PosBillingScreen), findsOneWidget);
  });

  testWidgets('CategoryEditDialog shows Save & New and Save in create mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AdminMenuCategoryEditResult? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showAdminMenuCategoryEditDialog(context);
              },
              child: const Text('New Category'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('New Category'));
    await tester.pumpAndSettle();

    expect(find.text('Save & New'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Desserts');
    await tester.tap(find.text('Save & New'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Desserts');
    expect(result?.saveAndNew, isTrue);
  });

  testWidgets('Category and item creation buttons sit directly above keyboard without extra bottom gap', (
    tester,
  ) async {
    const screenHeight = 740.0;
    const keyboardHeight = 300.0;
    tester.view.physicalSize = const Size(360, screenHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAdminMenuCategoryEditDialog(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Simulate keyboard opening
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
    await tester.pumpAndSettle();

    // The Save button should be visible and positioned directly above keyboard (at screenHeight - keyboardHeight)
    final saveFinder = find.widgetWithText(FilledButton, 'Save');
    expect(saveFinder, findsOneWidget);
    final saveBottom = tester.getBottomRight(saveFinder).dy;
    // Bottom of the button plus footer padding (16) should sit right at the top of the keyboard (440)
    // It should NEVER be pushed up to < 200 by a duplicate keyboard inset
    expect(saveBottom, greaterThan(screenHeight - keyboardHeight - 50));
    expect(saveBottom, lessThanOrEqualTo(screenHeight - keyboardHeight));
  });

  testWidgets('Category creation dialog displays remaining categories and detects duplicates', (
    tester,
  ) async {
    final existing = [
      AdminMenuCategory(id: 1, name: 'Breakfast', isActive: true, items: const []),
      AdminMenuCategory(id: 2, name: 'Lunch', isActive: true, items: const []),
      AdminMenuCategory(id: 3, name: 'Dinner', isActive: true, items: const []),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAdminMenuCategoryEditDialog(
                context,
                existingCategories: existing,
              ),
              child: const Text('Add Category'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Category'));
    await tester.pumpAndSettle();

    // Verify ALL CATEGORIES heading and list
    expect(find.text('ALL CATEGORIES'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);

    // Enter a non-duplicate name
    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Snacks');
    await tester.pumpAndSettle();
    expect(find.text('A category with this name already exists'), findsNothing);

    // Enter duplicate name 'Lunch'
    await tester.enterText(nameField, 'lunch');
    await tester.pumpAndSettle();
    expect(find.text('A category with this name already exists'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
  });

  testWidgets('CategoryEditDialog omits helper text on mobile view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAdminMenuCategoryEditDialog(
                context,
                canManageSlots: true,
              ),
              child: const Text('Add Category Mobile'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Category Mobile'));
    await tester.pumpAndSettle();

    expect(find.text('Time slots'), findsOneWidget);
    expect(
      find.text('Schedule windows for items in this category unless an item overrides them.'),
      findsNothing,
    );
  });

  testWidgets('CategoryEditDialog displays helper text on desktop view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAdminMenuCategoryEditDialog(
                context,
                canManageSlots: true,
              ),
              child: const Text('Add Category Desktop'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Category Desktop'));
    await tester.pumpAndSettle();

    expect(find.text('Time slots'), findsOneWidget);
    expect(
      find.text('Schedule windows for items in this category unless an item overrides them.'),
      findsOneWidget,
    );
  });
}


