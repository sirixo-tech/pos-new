import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/l10n/pos_l10n.dart';
import 'package:my_app/models/admin_models.dart';
import 'package:my_app/screens/admin/admin_menu_browser.dart';

void main() {
  final categories = [
    AdminMenuCategory(
      id: 28,
      name: 'Fresh Lime Soda',
      isActive: true,
      items: [
        AdminMenuItem(
          id: 1,
          name: 'Lime Soda',
          price: 70,
          isAvailable: true,
          itemType: 'veg',
        ),
      ],
    ),
    AdminMenuCategory(
      id: 4,
      name: 'Veg Starters',
      isActive: true,
      items: [
        AdminMenuItem(
          id: 2,
          name: 'Gobi Manchurian',
          price: 139,
          isAvailable: true,
        ),
      ],
    ),
  ];

  Future<void> pump(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('phone menu keeps categories as tabs', (tester) async {
    await pump(
      tester,
      AdminMobileMenuBrowser(
        categories: categories,
        selectedCategoryId: null,
        currency: 'INR',
        canManageItems: true,
        canEditItems: true,
        canToggle: true,
        busy: false,
        onSelectCategory: (_) {},
        onToggleItem: (_) {},
        onEditItem: (_, _) {},
        onDeleteItem: (_) {},
      ),
      const Size(390, 844),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Fresh Lime Soda'), findsWidgets);
    expect(find.text('Veg Starters'), findsWidgets);
    expect(find.text('Gobi Manchurian'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop menu puts the selected category items beside the list', (tester) async {
    await pump(
      tester,
      AdminDesktopMenuBrowser(
        categories: categories,
        selected: categories.first,
        currency: 'INR',
        timeSlots: const [],
        categorySearch: TextEditingController(),
        itemSearch: TextEditingController(),
        canManageCategories: true,
        canManageItems: true,
        canEditItems: true,
        canToggle: true,
        busy: false,
        onCategoryQuery: (_) {},
        onItemQuery: (_) {},
        onSelectCategory: (_) {},
        onToggleCategory: (_) {},
        onEditCategory: (_) {},
        onDeleteCategory: (_) {},
        onAddItem: (_) {},
        onToggleItem: (_) {},
        onEditItem: (_, _) {},
        onDeleteItem: (_) {},
      ),
      const Size(1280, 800),
    );

    expect(find.text('Lime Soda'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);
    expect(find.text('Veg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone upload disables only the item being saved', (tester) async {
    await pump(tester, AdminMobileMenuBrowser(
      categories: categories, selectedCategoryId: null, currency: 'INR',
      canManageItems: true, canEditItems: true, canToggle: true, busy: false,
      savingItemIds: const {1},
      onSelectCategory: (_) {}, onToggleItem: (_) {},
      onEditItem: (_, _) {}, onDeleteItem: (_) {},
    ), const Size(390, 844));
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[0].onChanged, isNull);
    expect(switches[1].onChanged, isNotNull);
  });

  testWidgets('desktop category upload leaves item controls enabled', (tester) async {
    final categorySearch = TextEditingController();
    final itemSearch = TextEditingController();
    addTearDown(categorySearch.dispose);
    addTearDown(itemSearch.dispose);
    await pump(tester, AdminDesktopMenuBrowser(
      categories: categories, selected: categories.first, currency: 'INR',
      timeSlots: const [], categorySearch: categorySearch, itemSearch: itemSearch,
      canManageCategories: true, canManageItems: true, canEditItems: true,
      canToggle: true, busy: false, savingCategoryIds: const {28},
      onCategoryQuery: (_) {}, onItemQuery: (_) {}, onSelectCategory: (_) {},
      onToggleCategory: (_) {}, onEditCategory: (_) {}, onDeleteCategory: (_) {},
      onAddItem: (_) {}, onToggleItem: (_) {}, onEditItem: (_, _) {},
      onDeleteItem: (_) {},
    ), const Size(1280, 800));
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[0].onChanged, isNull);
    expect(switches[1].onChanged, isNotNull);
  });
}
