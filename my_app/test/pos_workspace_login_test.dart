import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/models/admin_models.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/models/kitchen_models.dart';
import 'package:my_app/providers/pos_admin_controller.dart';
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

  test('menu-only role continues without the register bootstrap', () async {
    SharedPreferences.setMockInitialValues({});
    final api = MenuOnlyApi();
    final pos = PosController(api: api)..serverUrl = 'https://example.test';
    addTearDown(pos.dispose);

    await pos.login('staff', 'password');
    expect(pos.phase, PosAppPhase.contextPicker);
    await pos.selectBranch(1);
    expect(api.bootstrapCalls, 0);
    expect(api.kitchenBootstrapCalls, 0);
    expect(pos.errorMessage, isNull);
    expect(pos.phase, PosAppPhase.modePicker);
    expect(pos.canOpenStaffAction('menu'), isTrue);
    expect(pos.canUseRegister, isFalse);
  });

  test('assigned branch opens when switch-branch is forbidden', () async {
    SharedPreferences.setMockInitialValues({});
    final api = ForbiddenSwitchApi();
    final pos = PosController(api: api)..serverUrl = 'https://example.test';
    addTearDown(pos.dispose);

    await pos.login('staff', 'password');
    expect(pos.phase, PosAppPhase.modePicker);
    await pos.selectWorkMode(PosWorkMode.register);
    expect(pos.phase, PosAppPhase.contextPicker);
    await pos.selectBranch(2);
    expect(api.switchDenied, isTrue);
    expect(api.bootstrapCalls, 1);
    expect(pos.errorMessage, isNull);
    expect(pos.phase, PosAppPhase.terminalPicker);
    expect(pos.session?.branchId, 2);
    expect(pos.canUseRegister, isTrue);
  });

  test('turning a permission back on is reloaded before orders open', () async {
    SharedPreferences.setMockInitialValues({});
    final api = RestoredOrdersApi();
    final pos = PosController(api: api)
      ..serverUrl = 'https://example.test'
      ..session = PosSession(
        serverUrl: 'https://example.test',
        token: 'test',
        restaurantId: 1,
        branchId: 1,
      )
      ..profile = StaffProfile.fromJson({
        'permissions': ['access_pos'],
        'current_restaurant': {'id': 1},
        'current_branch': {'id': 1},
      })
      ..bootstrap = PosBootstrap.fromJson({
        'restaurant': {'id': 1, 'name': 'Cafe'},
        'branch': {'id': 1, 'name': 'Main'},
        'permissions': ['access_pos'],
      });
    addTearDown(pos.dispose);
    expect(pos.canViewStaffOrders, isFalse);

    api.permissions = ['access_pos', 'view_orders'];
    final admin = PosAdminController(api: api, pos: pos);
    addTearDown(admin.dispose);
    await admin.loadOrders();

    expect(api.orderCalls, greaterThanOrEqualTo(2));
    expect(admin.error, isNull);
    expect(admin.ordersPage, isNotNull);
    expect(pos.canViewStaffOrders, isTrue);
    expect(pos.profile!.permissions, contains('view_orders'));
  });
}

class RestoredOrdersApi extends LoginApi {
  List<String> permissions = ['access_pos'];
  int orderCalls = 0;

  StaffProfile _profile() => StaffProfile.fromJson({
    'permissions': permissions,
    'current_restaurant': {'id': 1},
    'current_branch': {'id': 1},
    'user': {'id': 9, 'name': '123', 'email': 'staff@example.test'},
    'restaurants': [
      {
        'id': 1,
        'name': 'Cafe',
        'branches': [
          {'id': 1, 'name': 'Main'},
        ],
      },
    ],
  });

  @override
  Future<StaffProfile> fetchMe(PosSession session) async => _profile();

  @override
  Future<PosBootstrap> bootstrap(PosSession session) async {
    bootstrapCalls++;
    return PosBootstrap.fromJson({
      'restaurant': {'id': 1, 'name': 'Cafe'},
      'branch': {'id': 1, 'name': 'Main'},
      'permissions': permissions,
      'admin_capabilities': {
        'can_access_admin': true,
        'can_view_orders': permissions.contains('view_orders'),
      },
    });
  }

  @override
  Future<AdminOrdersPage> fetchAdminOrders(
    PosSession session, {
    String? q,
    String? status,
    String? source,
    String period = 'today',
    String payment = 'all',
    int page = 1,
  }) async {
    orderCalls++;
    if (orderCalls == 1) {
      throw PosApiException(
        'You do not have permission to perform this action.',
        statusCode: 403,
      );
    }
    return AdminOrdersPage(orders: [], currentPage: 1, lastPage: 1, total: 0);
  }
}

class MenuOnlyApi extends LoginApi {
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
    profile: _profile,
  );

  StaffProfile get _profile => StaffProfile.fromJson({
    'permissions': ['view_menu'],
    'current_restaurant': {'id': 1},
    'current_branch': {'id': 1},
    'user': {'id': 9, 'name': '123', 'email': 'staff@example.test'},
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
  });

  @override
  Future<StaffProfile> fetchMe(PosSession session) async => _profile;

  @override
  Future<PosBootstrap> bootstrap(PosSession session) async {
    bootstrapCalls++;
    throw PosApiException(
      'You do not have permission to perform this action.',
      statusCode: 403,
    );
  }
}

class ForbiddenSwitchApi extends LoginApi {
  bool switchDenied = false;

  StaffProfile _profile({int branchId = 1}) => StaffProfile.fromJson({
    'permissions': ['access_pos', 'view_menu'],
    'current_restaurant': {'id': 1},
    'current_branch': {'id': branchId},
    'user': {'id': 9, 'name': '123', 'email': 'staff@example.test'},
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
  });

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
    profile: _profile(),
  );

  @override
  Future<StaffProfile> fetchMe(PosSession session) async =>
      _profile(branchId: session.branchId);

  @override
  Future<StaffProfile> switchBranch(PosSession session, int branchId) async {
    switchDenied = true;
    throw PosApiException(
      'You do not have permission to perform this action.',
      statusCode: 403,
    );
  }

  @override
  Future<PosBootstrap> bootstrap(PosSession session) async {
    bootstrapCalls++;
    expect(session.branchId, 2);
    return PosBootstrap.fromJson({
      'restaurant': {'id': 1, 'name': 'Cafe'},
      'branch': {'id': 2, 'name': 'Goa'},
      'permissions': ['access_pos', 'view_menu'],
      'admin_capabilities': {'can_access_admin': true, 'can_view_menu': true},
      'pos_terminals': [
        {'id': 1, 'code': 'A1', 'name': 'Counter'},
        {'id': 2, 'code': 'B2', 'name': 'Window'},
      ],
    });
  }
}
