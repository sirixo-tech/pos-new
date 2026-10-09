import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/screens/pos_mobile_settings_page.dart';
import 'package:my_app/widgets/pos_more_menu.dart';
import 'package:my_app/services/pos_storage.dart';

void main() {
  testWidgets('mobile customization is inline and persists hidden actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await PosStorage().saveMoreMenuHiddenIds({});
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosSettingsOverview(
            sections: List.generate(
              8,
              (i) => PosMoreMenuSection(
                items: [
                  PosMoreMenuItem(
                    id: 'action$i',
                    icon: Icons.notifications_outlined,
                    label: 'Action $i',
                  ),
                ],
              ),
            ),
            onSelected: (value) async {
              selected.add(value);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(8));
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(await PosStorage().getMoreMenuHiddenIds(), contains('action0'));
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Quick Actions'), findsNothing);
    expect(find.text('Action 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
