import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/admin_models.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/providers/pos_admin_controller.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/services/pos_api.dart';

class _Pos extends PosController {
  @override
  PosAdminCapabilities get staffAdminCapabilities => const PosAdminCapabilities(
    canAccessAdmin: true,
    canManageMenu: true,
    canViewMenu: true,
  );
  final refresh = Completer<void>();
  @override
  Future<void> refreshBootstrap() => refresh.future;
}

class _Api extends PosApi {
  final upload = Completer<Map<String, dynamic>>();
  Map<String, dynamic>? sentBody;
  @override
  Future<Map<String, dynamic>> updateAdminMenuItem(
    PosSession session, {
    required int id,
    required Map<String, dynamic> body,
    XFile? imageFile,
  }) {
    sentBody = body;
    return upload.future;
  }

  @override
  Future<Map<String, dynamic>> updateAdminMenuCategory(
    PosSession session, {
    required int id,
    required Map<String, dynamic> body,
    XFile? imageFile,
  }) {
    sentBody = body;
    return upload.future;
  }

  @override
  Future<AdminMenuPayload> fetchAdminMenu(PosSession session) async =>
      AdminMenuPayload(categories: [], modifiers: [], timeSlots: []);
}

void main() {
  for (final category in [false, true]) {
    for (final active in [false, true]) {
      test(
        'saving ${category ? 'category' : 'item'} preserves $active status and only locks its record',
        () async {
          final api = _Api();
          final pos = _Pos()
            ..session = PosSession(
              serverUrl: 'https://example.test',
              token: 'test',
              restaurantId: 9100,
              branchId: 1,
            );
          final admin = PosAdminController(api: api, pos: pos);
          admin.categories = [
            AdminMenuCategory(
              id: 21,
              name: 'Breakfast',
              isActive: active,
              items: [
                AdminMenuItem(
                  id: 12,
                  name: 'Dosa',
                  price: 100,
                  isAvailable: active,
                ),
              ],
            ),
          ];
          final save = category
              ? admin.updateMenuCategory(21, {
                  'name': 'Breakfast',
                }, imageFile: XFile('test.jpg'))
              : admin.updateMenuItem(12, {
                  'name': 'Dosa',
                }, imageFile: XFile('test.jpg'));
          expect(admin.mutating, false);
          expect(admin.savingCategoryIds, category ? {21} : isEmpty);
          expect(admin.savingItemIds, category ? isEmpty : {12});
          expect(
            api.sentBody?[category ? 'is_active' : 'is_available'],
            active,
          );
          final duplicate = category
              ? await admin.updateMenuCategory(21, {'name': 'Duplicate'})
              : await admin.updateMenuItem(12, {'name': 'Duplicate'});
          expect(duplicate, false);
          api.upload.complete({'id': category ? 21 : 12});
          expect(await save.timeout(const Duration(seconds: 1)), true);
          expect(admin.savingItemIds, isEmpty);
          expect(admin.savingCategoryIds, isEmpty);
          // A slow bootstrap refresh must not leave the controls disabled.
          expect(pos.refresh.isCompleted, false);
          pos.refresh.complete();
          admin.dispose();
          pos.dispose();
        },
      );
    }
  }

  test('upload failure releases the record lock', () async {
    final api = _Api();
    final pos = _Pos()
      ..session = PosSession(
        serverUrl: 'https://example.test',
        token: 'test',
        restaurantId: 9101,
        branchId: 1,
      );
    final admin = PosAdminController(api: api, pos: pos);
    final save = admin.updateMenuItem(12, {'name': 'Dosa'});
    api.upload.completeError(PosApiException('Upload failed'));
    expect(await save, false);
    expect(admin.savingItemIds, isEmpty);
    expect(admin.mutating, false);
    expect(admin.error, isNotNull);
    admin.dispose();
    pos.dispose();
  });
}
