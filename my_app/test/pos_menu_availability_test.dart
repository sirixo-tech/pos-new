import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/widgets/pos_menu_item_card.dart';

void main() {
  testWidgets('mobile unavailable card has red photo strip and cannot add', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    var added = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 240,
              child: PosMenuItemCard(
                item: MenuItem(
                  id: 1,
                  name: 'Bisibele Bhath',
                  price: 10,
                  isAvailable: false,
                  variants: [],
                  modifiers: [],
                ),
                currency: 'INR',
                handheld: true,
                photoGrid: true,
                onTap: () => added = true,
              ),
            ),
          ),
        ),
      ),
    );
    final label = find.text('Not available');
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).style!.color, Colors.white);
    final strip = find.ancestor(of: label, matching: find.byType(ColoredBox));
    expect(
      tester.widget<ColoredBox>(strip.first).color,
      const Color(0xCCB93232),
    );
    expect(
      tester.getBottomLeft(label).dy,
      lessThan(tester.getTopLeft(find.text('Bisibele Bhath')).dy),
    );
    await tester.tap(find.text('Bisibele Bhath'));
    expect(added, isFalse);
    expect(tester.takeException(), isNull);
  });
}
