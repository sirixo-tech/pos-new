import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/widgets/pos_category_rail.dart';

void main() {
  testWidgets(
    'compact left categories keep icons and the top rail stays text',
    (tester) async {
      Future<void> pump({required bool horizontal}) {
        return tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            home: Scaffold(
              body: PosCategoryRail(
                categories: [
                  MenuCategory(
                    id: 1,
                    name: 'Chicken',
                    items: const <MenuItem>[],
                  ),
                ],
                activeCategoryId: null,
                horizontal: horizontal,
                compact: true,
                allItemsLabel: 'All items',
                navLabel: 'Menu',
                onSelect: (_) {},
              ),
            ),
          ),
        );
      }

      await pump(horizontal: false);
      expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(find.text('Chicken'), findsOneWidget);

      await pump(horizontal: true);
      expect(find.byIcon(Icons.apps_rounded), findsNothing);
      expect(find.byIcon(Icons.restaurant_rounded), findsNothing);
      expect(find.text('Chicken'), findsOneWidget);
      expect(find.text('All items'), findsOneWidget);
    },
  );
}
