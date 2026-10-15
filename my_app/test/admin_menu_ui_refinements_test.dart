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
}
