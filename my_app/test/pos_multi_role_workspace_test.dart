import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/screens/mode_picker_screen.dart';

const assignedRoles = [
  {
    'name': 'Custom floor team',
    'permissions': [
      {'name': 'access_pos_captain'},
    ],
  },
  {
    'name': 'Custom cooking team',
    'permissions': ['access_kitchen', 'access_pos_captain'],
  },
];

void main() {
  test('all assigned role permissions combine without duplicate keys', () {
    final profile = StaffProfile.fromJson({'roles': assignedRoles});
    expect(profile.permissions, ['access_pos_captain', 'access_kitchen']);
    final bootstrap = PosBootstrap.fromJson({
      'restaurant': {'id': 1, 'name': 'Cafe'},
      'branch': {'id': 1, 'name': 'Branch'},
      'roles': assignedRoles,
    });
    expect(bootstrap.permissions, profile.permissions);
  });

  test('explicit effective permissions override role metadata', () {
    for (final keys in [
      <String>[],
      ['access_kitchen'],
    ]) {
      final profile = StaffProfile.fromJson({
        'roles': assignedRoles,
        'permissions': keys,
      });
      expect(profile.permissions, keys);
    }
    expect(
      StaffProfile.fromJson({
        'roles': [
          {'name': 'Owner'},
        ],
      }).permissions,
      isEmpty,
    );
  });

  testWidgets(
    'Captain and Kitchen roles show both workspaces without Register',
    (tester) async {
      final pos = PosController()
        ..phase = PosAppPhase.modePicker
        ..session = PosSession(
          serverUrl: 'https://example.test',
          token: 'test',
          restaurantId: 1,
          branchId: 1,
        )
        ..profile = StaffProfile.fromJson({'roles': assignedRoles});
      addTearDown(pos.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: pos,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ModePickerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Waiter / Captain'), findsOneWidget);
      expect(find.text('Kitchen Display'), findsOneWidget);
      expect(find.text('Register POS'), findsNothing);
      expect(pos.workMode, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
