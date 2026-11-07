import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/screens/mode_picker_screen.dart';
import 'package:my_app/services/customer_display/customer_display_models.dart';
import 'package:my_app/services/customer_display/customer_display_repository.dart';
import 'package:my_app/services/pos_work_mode_storage.dart';

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

  testWidgets(
    'Order board permission displays Token Display tile on workspace picker',
    (tester) async {
      final pos = PosController()
        ..phase = PosAppPhase.modePicker
        ..session = PosSession(
          serverUrl: 'https://example.test',
          token: 'test',
          restaurantId: 1,
          branchId: 1,
        )
        ..profile = StaffProfile.fromJson({
          'permissions': ['access_order_board'],
        });
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
      expect(find.text('Token Display'), findsOneWidget);
      expect(find.text('Register POS'), findsNothing);
      expect(find.text('Kitchen Display'), findsNothing);
      expect(pos.canUseTokenDisplay, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Kitchen and Order board permissions show both Kitchen Display and Token Display',
    (tester) async {
      final pos = PosController()
        ..phase = PosAppPhase.modePicker
        ..session = PosSession(
          serverUrl: 'https://example.test',
          token: 'test',
          restaurantId: 1,
          branchId: 1,
        )
        ..profile = StaffProfile.fromJson({
          'permissions': ['access_kitchen', 'order_board'],
        });
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
      expect(find.text('Kitchen Display'), findsOneWidget);
      expect(find.text('Token Display'), findsOneWidget);
      expect(find.text('Register POS'), findsNothing);
      expect(pos.canUseKitchen, isTrue);
      expect(pos.canUseTokenDisplay, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('PosWorkModeStorage persists and restores PosWorkMode.tokenDisplay', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PosWorkModeStorage.write(1, PosWorkMode.tokenDisplay);
    final read = await PosWorkModeStorage.read(1);
    expect(read, PosWorkMode.tokenDisplay);
    await PosWorkModeStorage.clear(1);
    final cleared = await PosWorkModeStorage.read(1);
    expect(cleared, isNull);
  });

  test('CustomerDisplayRepository readSetup resolves restaurant slug from StaffProfile when bootstrap is null', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final repository = CustomerDisplayRepository();
    final profile = StaffProfile.fromJson({
      'user': {'id': 1, 'name': 'Staff'},
      'current_restaurant': {'id': 10, 'name': 'Cafe Royale', 'slug': 'cafe-royale'},
      'current_branch': {'id': 20, 'name': 'Downtown Branch'},
      'restaurants': [
        {
          'id': 10,
          'name': 'Cafe Royale',
          'slug': 'cafe-royale',
          'branches': [
            {'id': 20, 'name': 'Downtown Branch'},
          ],
        },
      ],
      'permissions': ['access_order_board'],
    });

    final setup = await repository.readSetup(
      session: PosSession(serverUrl: 'https://example.com', token: 'token', branchId: 20, restaurantId: 10),
      profile: profile,
      bootstrap: null,
    );

    expect(setup.restaurantName, 'Cafe Royale');
    expect(setup.restaurantSlug, 'cafe-royale');
    expect(setup.branchName, 'Downtown Branch');
    expect(setup.branchId, 20);
  });

  test('CustomerBoardSnapshot.fromJson parses list payloads and nested order tokens', () {
    final listPayload = {
      'status': 'success',
      'data': [
        {
          'id': '101',
          'order_number': 'ORD-101',
          'token': 'A1',
          'status': 'preparing',
        },
        {
          'id': '102',
          'order': {
            'order_number': 'ORD-102',
            'token': 'B2',
            'status': 'ready',
          },
        },
      ],
    };

    final snapshot = CustomerBoardSnapshot.fromJson(listPayload);
    expect(snapshot.preparing.length, 1);
    expect(snapshot.preparing.first.token, 'A1');
    expect(snapshot.ready.length, 1);
    expect(snapshot.ready.first.token, 'B2');
  });
}
