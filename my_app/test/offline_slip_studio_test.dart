import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/providers/pos_register_preferences.dart';
import 'package:my_app/widgets/pos_offline_receipt_studio.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('kitchen ticket preview follows title and line switches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PosRegisterPreferences(),
        child: const MaterialApp(
          home: Scaffold(body: PosOfflineReceiptStudio(initialKitchen: true)),
        ),
      ),
    );

    expect(find.text('Kitchen ticket'), findsWidgets);
    expect(_previewText('KITCHEN ORDER'), findsOneWidget);
    expect(_previewText('TOKEN #12'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('kot-title')), 'GRILL');
    await tester.pump();

    expect(_previewText('GRILL'), findsOneWidget);
    expect(_previewText('KITCHEN ORDER'), findsNothing);

    await tester.enterText(find.byKey(const Key('kot-title')), '');
    await tester.pump();

    expect(_previewText('GRILL'), findsNothing);
    expect(_previewText('KITCHEN ORDER'), findsNothing);
    expect(_previewText('TOKEN #12'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('kot-title')), 'GRILL');
    await tester.pump();
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(_previewText('GRILL'), findsNothing);
    expect(_previewText('TOKEN #12'), findsOneWidget);
  });

  testWidgets('one screen switches the preview between bill and ticket', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PosRegisterPreferences(),
        child: const MaterialApp(
          home: Scaffold(body: PosOfflineReceiptStudio()),
        ),
      ),
    );

    expect(find.text('Customer bill'), findsWidgets);
    expect(_previewText('Bill No: —'), findsOneWidget);
    expect(_previewText('KITCHEN ORDER'), findsNothing);

    await tester.tap(find.text('Kitchen ticket'));
    await tester.pump();

    expect(_previewText('KITCHEN ORDER'), findsOneWidget);
    expect(_previewText('Bill No: —'), findsNothing);
  });
}

Finder _previewText(String text) {
  return find.descendant(
    of: find.byKey(const Key('slip-preview')),
    matching: find.text(text),
  );
}
