import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/widgets/pos_more_menu_sections.dart';
import 'package:my_app/widgets/pos_more_menu.dart';

PosController staff(
  List<String> permissions, {
  Map<String, dynamic> caps = const {},
}) => PosController()
  ..session = PosSession(
    serverUrl: 'https://example.test',
    token: 'test',
    restaurantId: 1,
    branchId: 1,
  )
  ..bootstrap = PosBootstrap.fromJson({
    'restaurant': {'id': 1, 'name': 'Test'},
    'branch': {'id': 1, 'name': 'Test'},
    'permissions': permissions,
    'admin_capabilities': caps,
  });

void main() {
  test('current backend revocation removes reports and admin access', () {
    final pos =
        staff([], caps: {'can_access_admin': true, 'can_view_menu': true})
          ..profile = StaffProfile.fromJson({
            'permissions': ['view_reports', 'view_menu'],
          });
    addTearDown(pos.dispose);
    expect(pos.canViewStaffReports, isFalse);
    expect(pos.canViewStaffMenu, isFalse);
    expect(pos.canOpenStaffAction('manage'), isFalse);
  });

  test('kitchen-only login cannot inherit broad bootstrap permissions', () {
    final pos =
        staff(
            [
              'access_pos',
              'access_pos_captain',
              'access_kitchen',
              'view_reports',
            ],
            caps: {
              'can_access_admin': true,
              'can_view_menu': true,
              'can_manage_menu': true,
              'can_view_orders': true,
              'can_manage_settings': true,
            },
          )
          ..profile = StaffProfile.fromJson({
            'permissions': ['access_kitchen'],
          });
    addTearDown(pos.dispose);
    expect(pos.canUseKitchen, isTrue);
    expect(pos.canUseRegister, isFalse);
    expect(pos.canUseCaptain, isFalse);
    expect(pos.canChooseWorkMode, isFalse);
    for (final action in [
      'reports',
      'manage',
      'menu',
      'ai_menu',
      'orders',
      'printer',
      'customer_display',
    ]) {
      expect(pos.canOpenStaffAction(action), isFalse, reason: action);
    }
    expect(pos.canOpenStaffAction('kitchen_display'), isTrue);
  });
  test('register access does not grant kitchen, reports or administration', () {
    final pos = staff(['access_pos']);
    addTearDown(pos.dispose);
    expect(pos.canUseRegister, isTrue);
    for (final action in [
      'kitchen_display',
      'reports',
      'menu',
      'manage',
      'printer',
      'orders',
      'open_shift',
    ]) {
      expect(pos.canOpenStaffAction(action), isFalse, reason: action);
    }
    expect(pos.canOpenStaffAction('logout'), isTrue);
  });

  test(
    'empty current permissions do not restore stale login kitchen access',
    () {
      final pos = staff([])
        ..profile = StaffProfile.fromJson({
          'permissions': ['access_kitchen', 'access_pos'],
        });
      addTearDown(pos.dispose);
      expect(pos.canUseKitchen, isFalse);
      expect(pos.canUseRegister, isFalse);
      expect(pos.ensureKitchenApiToken(), throwsStateError);
    },
  );

  test('custom role keys grant access without capability flags', () {
    final pos =
        staff([
            'access_pos',
            'view_menu',
            'view_reports',
            'manage_printers',
            'manage_menu_import',
          ])
          ..profile = StaffProfile.fromJson({
            'permissions': {
              'pos': [
                {'key': 'access_pos', 'name': 'Access POS'},
              ],
              'menu': [
                {'key': 'view_menu', 'name': 'View menu'},
                {'key': 'manage_menu_import', 'name': 'Import menu'},
              ],
              'reports': [
                {'key': 'view_reports', 'name': 'View reports'},
              ],
              'devices': [
                {'key': 'manage_printers', 'name': 'Manage printers'},
              ],
            },
          });
    addTearDown(pos.dispose);
    expect(pos.profile!.permissions, [
      'access_pos',
      'view_menu',
      'manage_menu_import',
      'view_reports',
      'manage_printers',
    ]);
    expect(pos.canUseRegister, isTrue);
    expect(pos.canUseKitchen, isFalse);
    expect(pos.canViewStaffMenu, isTrue);
    expect(pos.canViewStaffReports, isTrue);
    expect(pos.canOpenStaffAction('menu'), isTrue);
    expect(pos.canOpenStaffAction('ai_menu'), isTrue);
    expect(pos.canOpenStaffAction('reports'), isTrue);
    expect(pos.canOpenStaffAction('printer'), isTrue);
    expect(pos.canOpenStaffAction('manage'), isTrue);
    expect(pos.canOpenStaffAction('orders'), isFalse);
    expect(pos.canOpenStaffAction('store_toggle'), isFalse);
  });

  test('permissions grant their own actions without unrelated access', () {
    final pos = staff(
      ['access_pos', 'access_kitchen', 'view_reports'],
      caps: {'can_access_admin': true, 'can_view_menu': true},
    );
    addTearDown(pos.dispose);
    expect(pos.canOpenStaffAction('kitchen_display'), isTrue);
    expect(pos.canOpenStaffAction('reports'), isTrue);
    expect(pos.canOpenStaffAction('menu'), isTrue);
    expect(pos.canOpenStaffAction('ai_menu'), isFalse);
    expect(pos.canOpenStaffAction('printer'), isFalse);
  });

  for (final kitchen in [false, true]) {
    testWidgets(
      'shared desktop/mobile menu filters restricted actions, kitchen=$kitchen',
      (tester) async {
        final pos = staff(['access_pos', if (kitchen) 'access_kitchen']);
        addTearDown(pos.dispose);
        List<PosMoreMenuSection> sections = [];
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: pos,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  sections = buildPosMoreMenuSections(
                    context: context,
                    l10n: AppLocalizations.of(context),
                    storeAccepting: true,
                    storeStatusLabel: 'Open',
                    canManageStore: true,
                    canAccessAdmin: true,
                    canViewMenu: true,
                    marketplacePlatforms: [],
                    showLanguageSwitcher: false,
                    terminalCount: 1,
                    canChangeLocation: false,
                    hasPin: false,
                    canUseCaptain: false,
                    canChooseWorkMode: false,
                    checkingForUpdates: false,
                    pendingOrderCount: 0,
                    hasDeviceBinding: false,
                    includeShortcuts: false,
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        final ids = sections
            .expand((section) => section.items)
            .map((item) => item.id)
            .toSet();
        expect(ids.contains('kitchen_display'), kitchen);
        expect(
          ids.intersection({
            'reports',
            'manage',
            'menu',
            'printer',
            'store_toggle',
          }),
          isEmpty,
        );
        expect(sections.every((section) => section.items.isNotEmpty), isTrue);
      },
    );
  }
}
