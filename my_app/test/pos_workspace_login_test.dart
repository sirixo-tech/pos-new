import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/models/kitchen_models.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/services/pos_api.dart';

class LoginApi extends PosApi {
  int bootstrapCalls = 0;
  int kitchenBootstrapCalls = 0;
  List<String> currentPermissions = ['access_kitchen'];

  @override
  Future<StaffProfile> fetchMe(PosSession session) async {
    final original = (await login(
      serverUrl: session.serverUrl,
      email: 'staff',
      password: 'password',
    )).profile;
    return StaffProfile(
      user: original.user,
      restaurants: original.restaurants,
      currentRestaurantId: original.currentRestaurantId,
      currentBranchId: original.currentBranchId,
      permissions: currentPermissions,
    );
  }

  @override
  Future<StaffProfile> switchBranch(PosSession session, int branchId) async {
    expect(branchId, 1);
    return (await login(
      serverUrl: session.serverUrl,
      email: 'staff',
      password: 'password',
    )).profile;
  }

  @override
  Future<String> issueScopedToken(
    PosSession session, {
    required String ability,
  }) async {
    expect(ability, 'kitchen');
    return 'kitchen-token';
  }

  @override
  Future<KitchenBootstrap> fetchKitchenBootstrap({
    required PosSession session,
    required String kitchenToken,
  }) async {
    kitchenBootstrapCalls++;
    expect(kitchenToken, 'kitchen-token');
    return const KitchenBootstrap(queueRequired: false, kitchens: []);
  }

  @override
  Future<StaffLoginResult> login({
    required String serverUrl,
    required String email,
    required String password,
    int? restaurantId,
    int? branchId,
  }) async => StaffLoginResult(
    session: PosSession(
      serverUrl: serverUrl,
      token: 'test',
      restaurantId: 1,
      branchId: 1,
    ),
    profile: StaffProfile.fromJson({
      'permissions': ['access_kitchen'],
      'current_restaurant': {'id': 1},
      'current_branch': {'id': 1},
      'restaurants': [
        {
          'id': 1,
          'name': 'Cafe',
          'branches': [
            {'id': 1, 'name': 'Bangalore'},
            {'id': 2, 'name': 'Goa'},
          ],
        },
      ],
    }),
  );

  @override
  Future<PosBootstrap> bootstrap(PosSession session) async {
    bootstrapCalls++;
    throw StateError('Bootstrap must wait for location selection');
  }
}

class CaptainApi extends LoginApi {
  @override
  Future<StaffProfile> switchBranch(PosSession session, int branchId) =>
      fetchMe(session);

  @override
  Future<PosBootstrap> bootstrap(PosSession session) async {
    bootstrapCalls++;
    return PosBootstrap.fromJson({
      'restaurant': {'id': 1, 'name': 'Cafe'},
      'branch': {'id': 1, 'name': 'Bangalore'},
      'permissions': ['access_kitchen'],
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // These controller tests do not exercise the native offline cache.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async =>
              throw PlatformException(code: 'cache_unavailable_in_test'),
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  test(
    'bootstrap cannot silently replace selected Captain with Kitchen',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = CaptainApi()
        ..currentPermissions = ['access_pos_captain', 'access_kitchen'];
      final pos = PosController(api: api)..serverUrl = 'https://example.test';
      addTearDown(pos.dispose);
      await pos.login('staff', 'password');
      await pos.refreshWorkspacePermissions();
      await pos.selectWorkMode(PosWorkMode.waiter);
      await pos.selectBranch(1);
      expect(api.bootstrapCalls, 1);
      expect(pos.phase, PosAppPhase.modePicker);
      expect(pos.workMode, isNull);
      expect(
        pos.errorMessage,
        contains('Waiter / Captain access is not available'),
      );
    },
  );

  test(
    'workspace refresh replaces kitchen access with current captain access',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = LoginApi();
      final pos = PosController(api: api)..serverUrl = 'https://example.test';
      addTearDown(pos.dispose);
      await pos.login('staff', 'password');
      expect(pos.canUseKitchen, isTrue);
      api.currentPermissions = ['access_pos_captain'];
      await pos.refreshWorkspacePermissions();
      expect(pos.canUseCaptain, isTrue);
      expect(pos.canUseKitchen, isFalse);
      expect(pos.canUseRegister, isFalse);
      expect(pos.phase, PosAppPhase.modePicker);
      await pos.selectWorkMode(PosWorkMode.waiter);
      expect(pos.workMode, PosWorkMode.waiter);
      expect(pos.phase, PosAppPhase.contextPicker);
    },
  );

  test(
    'login selects permitted workspace before location and bootstrap',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = LoginApi();
      final pos = PosController(api: api)..serverUrl = 'https://example.test';
      addTearDown(pos.dispose);

      await pos.login('staff', 'password');
      expect(pos.phase, PosAppPhase.modePicker);
      expect(pos.canUseKitchen, isTrue);
      expect(pos.canUseRegister, isFalse);
      expect(api.bootstrapCalls, 0);
      expect(api.kitchenBootstrapCalls, 0);

      await pos.selectWorkMode(PosWorkMode.register);
      expect(pos.phase, PosAppPhase.modePicker);

      await pos.selectWorkMode(PosWorkMode.kitchen);
      expect(pos.phase, PosAppPhase.contextPicker);
      expect(pos.workMode, PosWorkMode.kitchen);
      expect(api.bootstrapCalls, 0);
      await pos.selectBranch(1);
      expect(pos.phase, PosAppPhase.ready);
      expect(pos.errorMessage, isNull);
      expect(pos.workMode, PosWorkMode.kitchen);
      expect(api.bootstrapCalls, 0);
      expect(api.kitchenBootstrapCalls, 1);
    },
  );
}
