import '../config/pos_app_info.dart';
import '../utils/json_parse.dart';
import '../utils/menu_localization.dart';
import '../utils/order_charges_calculator.dart';
import '../utils/tax_calculator.dart';
import 'admin_models.dart';
import 'opening_hours_models.dart';
import 'pos_app_update.dart';
import 'receipt_print_models.dart';

export 'admin_models.dart' show PosAdminCapabilities;
export 'opening_hours_models.dart';
export 'receipt_print_models.dart' show PosReceiptSettings, PosTokenSettings;

class StaffBranchOption {
  StaffBranchOption({
    required this.id,
    required this.name,
    this.slug,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final String? slug;
  final bool isDefault;

  factory StaffBranchOption.fromJson(Map<String, dynamic> json) {
    return StaffBranchOption(
      id: parseJsonInt(json['id']),
      name: json['name'] as String,
      slug: json['slug'] as String?,
      isDefault: parseJsonBool(json['is_default']),
    );
  }
}

class StaffRestaurantOption {
  StaffRestaurantOption({
    required this.id,
    required this.name,
    required this.branches,
    this.slug,
    this.role,
  });

  final int id;
  final String name;
  final String? slug;
  final String? role;
  final List<StaffBranchOption> branches;

  factory StaffRestaurantOption.fromJson(Map<String, dynamic> json) {
    return StaffRestaurantOption(
      id: parseJsonInt(json['id']),
      name: json['name'] as String,
      slug: json['slug'] as String?,
      role: json['role'] as String?,
      branches: (json['branches'] as List<dynamic>? ?? [])
          .map((e) => StaffBranchOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StaffUserInfo {
  const StaffUserInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.hasPosPin,
  });

  final int id;
  final String name;
  final String email;
  final bool hasPosPin;

  factory StaffUserInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const StaffUserInfo(id: 0, name: '', email: '', hasPosPin: false);
    }
    return StaffUserInfo(
      id: parseJsonInt(json['id']),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      hasPosPin: parseJsonBool(json['has_pos_pin']),
    );
  }
}

class StaffProfile {
  StaffProfile({
    required this.user,
    required this.restaurants,
    this.currentRestaurantId,
    this.currentBranchId,
    this.permissions = const [],
  });

  final StaffUserInfo user;
  final List<StaffRestaurantOption> restaurants;
  final int? currentRestaurantId;
  final int? currentBranchId;
  final List<String> permissions;

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    final restaurant = json['current_restaurant'] as Map<String, dynamic>?;
    final branch = json['current_branch'] as Map<String, dynamic>?;
    return StaffProfile(
      user: StaffUserInfo.fromJson(json['user'] as Map<String, dynamic>?),
      restaurants: (json['restaurants'] as List<dynamic>? ?? [])
          .map((e) => StaffRestaurantOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentRestaurantId: restaurant != null ? parseJsonInt(restaurant['id']) : null,
      currentBranchId: branch != null ? parseJsonInt(branch['id']) : null,
      permissions: (json['permissions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  int get branchOptionCount =>
      restaurants.fold(0, (sum, r) => sum + r.branches.length);

  bool get needsContextPicker {
    if (restaurants.length > 1) return true;
    if (restaurants.length == 1 && restaurants.first.branches.length > 1) {
      return true;
    }
    return false;
  }

  StaffRestaurantOption? restaurantOption(int restaurantId) {
    for (final restaurant in restaurants) {
      if (restaurant.id == restaurantId) return restaurant;
    }
    return null;
  }

  bool canAccessLocation(int restaurantId, int branchId) {
    for (final restaurant in restaurants) {
      if (restaurant.id != restaurantId) continue;
      return restaurant.branches.any((branch) => branch.id == branchId);
    }
    return false;
  }
}

class PosTerminalInfo {
  PosTerminalInfo({
    required this.id,
    required this.code,
    required this.name,
    this.displayUrl,
    this.syncToken,
  });

  final int id;
  final String code;
  final String name;
  final String? displayUrl;
  final String? syncToken;

  factory PosTerminalInfo.fromJson(Map<String, dynamic> json) {
    return PosTerminalInfo(
      id: parseJsonInt(json['id']),
      code: (json['code'] as String? ?? '').toUpperCase(),
      name: json['name'] as String? ?? '',
      displayUrl: json['display_url'] as String?,
      syncToken: json['sync_token'] as String?,
    );
  }
}

class PosDeviceBinding {
  PosDeviceBinding({
    required this.restaurantId,
    required this.branchId,
    required this.terminalCode,
    this.restaurantName,
    this.branchName,
    this.terminalName,
  });

  final int restaurantId;
  final int branchId;
  final String terminalCode;
  final String? restaurantName;
  final String? branchName;
  final String? terminalName;

  factory PosDeviceBinding.fromJson(Map<String, dynamic> json) {
    return PosDeviceBinding(
      restaurantId: parseJsonInt(json['restaurant_id']),
      branchId: parseJsonInt(json['branch_id']),
      terminalCode: (json['terminal_code'] as String? ?? '').toUpperCase(),
      restaurantName: json['restaurant_name'] as String?,
      branchName: json['branch_name'] as String?,
      terminalName: json['terminal_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'restaurant_id': restaurantId,
        'branch_id': branchId,
        'terminal_code': terminalCode,
        if (restaurantName != null) 'restaurant_name': restaurantName,
        if (branchName != null) 'branch_name': branchName,
        if (terminalName != null) 'terminal_name': terminalName,
      };
}

class PosPairingStartResult {
  PosPairingStartResult({
    required this.pairingCode,
    required this.deviceUuid,
    required this.expiresAt,
  });

  final String pairingCode;
  final String deviceUuid;
  final String expiresAt;

  factory PosPairingStartResult.fromJson(Map<String, dynamic> json) {
    return PosPairingStartResult(
      pairingCode: json['pairing_code'] as String? ?? '',
      deviceUuid: json['device_uuid'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
    );
  }
}

class PosSession {
  PosSession({
    required this.serverUrl,
    required this.token,
    required this.restaurantId,
    required this.branchId,
    this.userId,
    this.userName,
    this.userEmail,
    this.hasPosPin = false,
  });

  final String serverUrl;
  final String token;
  final int restaurantId;
  final int branchId;
  final int? userId;
  final String? userName;
  final String? userEmail;
  final bool hasPosPin;

  String get v1BaseUrl {
    var base = serverUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/api/v1';
  }

  String get apiBaseUrl {
    return '$v1BaseUrl/pos';
  }

  String get authBaseUrl {
    var base = serverUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/api/v1/auth';
  }

  factory PosSession.fromJson(Map<String, dynamic> json) {
    return PosSession(
      serverUrl: json['server_url'] as String,
      token: json['token'] as String,
      restaurantId: parseJsonInt(json['restaurant_id']),
      branchId: parseJsonInt(json['branch_id']),
      userId: json['user_id'] == null ? null : parseJsonInt(json['user_id']),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
      hasPosPin: parseJsonBool(json['has_pos_pin']),
    );
  }

  Map<String, dynamic> toJson() => {
        'server_url': serverUrl,
        'token': token,
        'restaurant_id': restaurantId,
        'branch_id': branchId,
        if (userId != null) 'user_id': userId,
        if (userName != null) 'user_name': userName,
        if (userEmail != null) 'user_email': userEmail,
        'has_pos_pin': hasPosPin,
      };

  PosSession copyWith({
    int? restaurantId,
    int? branchId,
    int? userId,
    String? userName,
    bool? hasPosPin,
  }) {
    return PosSession(
      serverUrl: serverUrl,
      token: token,
      restaurantId: restaurantId ?? this.restaurantId,
      branchId: branchId ?? this.branchId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail,
      hasPosPin: hasPosPin ?? this.hasPosPin,
    );
  }
}

class MenuCategory {
  MenuCategory({
    required this.id,
    required this.name,
    required this.items,
    this.imageUrl,
    this.translations = const {},
  });

  final int id;
  final String name;
  final String? imageUrl;
  final Map<String, Map<String, String>> translations;
  final List<MenuItem> items;

  String localizedName(String languageCode) => MenuLocalization.field(
        translations,
        languageCode,
        'name',
        name,
      );

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['menu_items'] ?? json['items'] ?? json['menuItems'];
    return MenuCategory(
      id: parseJsonInt(json['id']),
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      translations: parseMenuTranslations(json['translations']),
      items: (rawItems as List<dynamic>? ?? [])
          .map((e) {
            if (e is Map<String, dynamic>) {
              return MenuItem.fromJson(e);
            }
            if (e is Map) {
              return MenuItem.fromJson(Map<String, dynamic>.from(e));
            }
            return null;
          })
          .whereType<MenuItem>()
          .toList(),
    );
  }
}

class MenuItem {
  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.itemType,
    this.barcode,
    this.sku,
    this.orderTypeSurcharges,
    this.isAvailable = true,
    this.isOrderable = true,
    this.isLiveNow = true,
    this.scheduleMode = 'always',
    this.scheduleHiddenReason,
    this.translations = const {},
    required this.variants,
    required this.modifiers,
  });

  final int id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final String? itemType;
  final String? barcode;
  final String? sku;
  final Map<String, dynamic>? orderTypeSurcharges;
  final Map<String, Map<String, String>> translations;
  /// Manual availability toggle (false = sold out / turned off in admin).
  final bool isAvailable;
  /// Server-computed guest/POS orderability (toggle + schedule).
  final bool isOrderable;
  /// False when the item is manually available but outside its time slots.
  final bool isLiveNow;
  final String scheduleMode;
  final String? scheduleHiddenReason;
  final List<MenuVariant> variants;
  final List<MenuModifier> modifiers;

  bool get hasOptions => variants.isNotEmpty || modifiers.isNotEmpty;

  bool get isManuallyUnavailable =>
      !isAvailable || scheduleHiddenReason == 'off';

  bool get isOutsideSchedule =>
      !isManuallyUnavailable &&
      (scheduleHiddenReason == 'schedule' ||
          (scheduleMode == 'scheduled' && !isLiveNow));

  String localizedName(String languageCode) => MenuLocalization.field(
        translations,
        languageCode,
        'name',
        name,
      );

  String? localizedDescription(String languageCode) {
    final resolved = MenuLocalization.field(
      translations,
      languageCode,
      'description',
      description ?? '',
    );
    return resolved.isEmpty ? null : resolved;
  }

  bool matchesSearch(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    if (barcode != null && barcode!.toLowerCase().contains(q)) return true;
    if (sku != null && sku!.toLowerCase().contains(q)) return true;
    for (final fields in translations.values) {
      final translated = fields['name']?.toLowerCase();
      if (translated != null && translated.contains(q)) return true;
    }
    return false;
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final schedule = json['schedule'];
    final scheduleMap = schedule is Map
        ? Map<String, dynamic>.from(schedule)
        : const <String, dynamic>{};
    final mode = (scheduleMap['mode'] as String?) ?? 'always';
    final live = scheduleMap['is_live_now'];
    final hiddenRaw = scheduleMap['hidden_reason'];
    final hiddenReason = hiddenRaw is String ? hiddenRaw : null;
    final isAvailable = json.containsKey('is_available')
        ? parseJsonBool(json['is_available'], fallback: true)
        : hiddenReason != 'off';
    final isLiveNow = live == null ? true : parseJsonBool(live, fallback: true);
    final isOrderable = json.containsKey('is_orderable')
        ? parseJsonBool(json['is_orderable'], fallback: true)
        : (isAvailable && hiddenReason == null);

    return MenuItem(
      id: parseJsonInt(json['id']),
      name: json['name'] as String? ?? '',
      price: parseJsonDouble(json['price']),
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      itemType: json['item_type'] as String?,
      barcode: _codeText(json['barcode']),
      sku: _codeText(json['sku']),
      orderTypeSurcharges:
          json['order_type_surcharges'] as Map<String, dynamic>?,
      translations: parseMenuTranslations(json['translations']),
      isAvailable: isAvailable,
      isOrderable: isOrderable,
      isLiveNow: isLiveNow,
      scheduleMode: mode,
      scheduleHiddenReason: hiddenReason,
      variants: (json['variants'] as List<dynamic>? ?? [])
          .map((e) => MenuItem._mapJson(e))
          .map(MenuVariant.fromJson)
          .toList(),
      modifiers: (json['modifiers'] as List<dynamic>? ?? [])
          .map((e) => MenuItem._mapJson(e))
          .map(MenuModifier.fromJson)
          .toList(),
    );
  }

  static String? _codeText(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  static Map<String, dynamic> _mapJson(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  double baseUnitPrice(MenuVariant? variant) => variant?.price ?? price;
}

class MenuVariant {
  MenuVariant({
    required this.id,
    required this.name,
    required this.price,
    this.barcode,
  });

  final int id;
  final String name;
  final double price;
  final String? barcode;

  factory MenuVariant.fromJson(Map<String, dynamic> json) {
    return MenuVariant(
      id: parseJsonInt(json['id']),
      name: json['name'] as String? ?? '',
      price: parseJsonDouble(json['price']),
      barcode: MenuItem._codeText(json['barcode'] ?? json['sku']),
    );
  }
}

class MenuBarcodeMatch {
  const MenuBarcodeMatch({required this.item, this.variant});

  final MenuItem item;
  final MenuVariant? variant;
}

class MenuModifier {
  MenuModifier({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.options,
  });

  final int id;
  final String name;
  final bool isRequired;
  final int minSelections;
  final int? maxSelections;
  final List<ModifierOption> options;

  factory MenuModifier.fromJson(Map<String, dynamic> json) {
    return MenuModifier(
      id: parseJsonInt(json['id']),
      name: json['name'] as String,
      isRequired: parseJsonBool(json['is_required']),
      minSelections: parseJsonInt(json['min_selections']),
      maxSelections: parseJsonIntOrNull(json['max_selections']),
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) {
            if (e is Map<String, dynamic>) {
              return ModifierOption.fromJson(e);
            }
            if (e is Map) {
              return ModifierOption.fromJson(Map<String, dynamic>.from(e));
            }
            return null;
          })
          .whereType<ModifierOption>()
          .toList(),
    );
  }
}

class ModifierOption {
  ModifierOption({
    required this.id,
    required this.name,
    required this.priceAdjustment,
  });

  final int id;
  final String name;
  final double priceAdjustment;

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    return ModifierOption(
      id: parseJsonInt(json['id']),
      name: json['name'] as String,
      priceAdjustment: parseJsonDouble(json['price_adjustment']),
    );
  }
}

class CartLine {
  CartLine({
    required this.menuItem,
    this.variant,
    this.selectedModifiers = const [],
    this.quantity = 1,
    this.notes,
  });

  final MenuItem menuItem;
  final MenuVariant? variant;
  final List<ModifierOption> selectedModifiers;
  final int quantity;
  final String? notes;

  double get unitPrice {
    var total = menuItem.baseUnitPrice(variant);
    for (final mod in selectedModifiers) {
      total += mod.priceAdjustment;
    }
    return total;
  }

  double get lineTotal => unitPrice * quantity;

  String get displayName => displayNameFor('en');

  String displayNameFor(String languageCode) {
    final itemName = menuItem.localizedName(languageCode);
    return variant != null ? '$itemName (${variant!.name})' : itemName;
  }

  Map<String, dynamic> toOrderJson() => {
        'menu_item_id': menuItem.id,
        if (variant != null) 'variant_id': variant!.id,
        'quantity': quantity,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (selectedModifiers.isNotEmpty)
          'modifiers': selectedModifiers
              .map((m) => {'modifier_option_id': m.id, 'quantity': 1})
              .toList(),
      };

  CartLine copyWith({
    int? quantity,
    String? notes,
    bool clearNotes = false,
  }) =>
      CartLine(
        menuItem: menuItem,
        variant: variant,
        selectedModifiers: selectedModifiers,
        quantity: quantity ?? this.quantity,
        notes: clearNotes ? null : (notes ?? this.notes),
      );
}

class TipSettings {
  const TipSettings({
    this.enabled = true,
    this.presets = const [10, 15, 18, 20],
  });

  final bool enabled;
  final List<double> presets;

  factory TipSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TipSettings();
    final raw = json['presets'];
    final presets = raw is List
        ? raw
            .map<double>(
              (e) =>
                  (e is num ? e.toDouble() : double.tryParse('$e') ?? 0),
            )
            .where((e) => e > 0)
            .toList()
        : const <double>[10, 15, 18, 20];
    return TipSettings(
      enabled: json['enabled'] != false,
      presets: presets.isEmpty ? const <double>[10, 15, 18, 20] : presets,
    );
  }
}

class PosRestaurantInfo {
  PosRestaurantInfo({
    required this.id,
    required this.name,
    this.logoUrl,
    this.printLogoUrl,
    this.taxId,
    this.primaryColor,
    required this.defaultCurrency,
    required this.taxSettings,
    required this.serviceCharge,
    required this.orderTypeCharges,
    required this.orderTypeSurchargeSettings,
    this.ordering = const PosOrderingSettings(),
    this.tips = const TipSettings(),
  });

  final int id;
  final String name;
  final String? logoUrl;
  final String? printLogoUrl;
  final String? taxId;
  final String? primaryColor;
  final String defaultCurrency;
  final TaxSettings taxSettings;
  final ServiceChargeConfig serviceCharge;
  final Map<String, dynamic> orderTypeCharges;
  final Map<String, dynamic> orderTypeSurchargeSettings;
  final PosOrderingSettings ordering;
  final TipSettings tips;

  factory PosRestaurantInfo.fromJson(Map<String, dynamic> json) {
    final taxId = (json['tax_id'] as String?)?.trim();
    return PosRestaurantInfo(
      id: parseJsonInt(json['id']),
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      printLogoUrl: json['print_logo_url'] as String?,
      taxId: taxId != null && taxId.isNotEmpty ? taxId : null,
      primaryColor: json['primary_color'] as String?,
      defaultCurrency: (json['default_currency'] as String?) ?? 'USD',
      taxSettings: TaxSettings.fromJson(
        json['tax_settings'] as Map<String, dynamic>? ?? const {},
      ),
      serviceCharge: ServiceChargeConfig.fromJson(
        json['service_charge'] as Map<String, dynamic>?,
      ),
      orderTypeCharges:
          (json['order_type_charges'] as Map<String, dynamic>?) ?? const {},
      orderTypeSurchargeSettings:
          (json['order_type_surcharge_settings'] as Map<String, dynamic>?) ??
              defaultSurchargeSettings(),
      ordering: PosOrderingSettings.fromJson(
        json['ordering'] as Map<String, dynamic>?,
      ),
      tips: TipSettings.fromJson(json['tips'] as Map<String, dynamic>?),
    );
  }
}

class PosOrderingSettings {
  const PosOrderingSettings({
    this.enablePickup = true,
    this.enableDelivery = true,
    this.enableDineIn = true,
    this.posOrderTypes = const ['dine_in', 'takeaway', 'delivery'],
  });

  final bool enablePickup;
  final bool enableDelivery;
  final bool enableDineIn;
  final List<String> posOrderTypes;

  factory PosOrderingSettings.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    final rawTypes = (data['pos_order_types'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();

    return PosOrderingSettings(
      enablePickup: data['enable_pickup'] as bool? ?? true,
      enableDelivery: data['enable_delivery'] as bool? ?? true,
      enableDineIn: data['enable_dine_in'] as bool? ?? true,
      posOrderTypes: rawTypes.isNotEmpty
          ? rawTypes
          : const ['dine_in', 'takeaway', 'delivery'],
    );
  }

  bool get allowsPosDelivery {
    if (!enableDelivery) return false;
    if (posOrderTypes.isEmpty) return true;
    return posOrderTypes.contains('delivery');
  }

  List<String> get activePosOrderTypes {
    final types = posOrderTypes.isEmpty
        ? const ['dine_in', 'takeaway', 'delivery']
        : List<String>.from(posOrderTypes);
    if (allowsPosDelivery) return types;
    return types.where((type) => type != 'delivery').toList();
  }
}

class PosBranchInfo {
  PosBranchInfo({required this.id, required this.name, this.address});

  final int id;
  final String name;
  final String? address;

  factory PosBranchInfo.fromJson(Map<String, dynamic> json) {
    final address = (json['address'] as String?)?.trim();
    return PosBranchInfo(
      id: parseJsonInt(json['id']),
      name: json['name'] as String,
      address: address != null && address.isNotEmpty ? address : null,
    );
  }
}

class PosShift {
  PosShift({
    required this.id,
    this.openingFloat,
    this.openedAt,
    this.openedByName,
  });

  final int id;
  final double? openingFloat;
  final String? openedAt;
  final String? openedByName;

  factory PosShift.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError('shift json required');
    }
    final openedBy = json['opened_by'] as Map<String, dynamic>?;
    return PosShift(
      id: parseJsonInt(json['id']),
      openingFloat: parseJsonDoubleOrNull(json['opening_float']),
      openedAt: json['opened_at'] as String?,
      openedByName: openedBy?['name'] as String?,
    );
  }
}

class PosShiftCloseSummary {
  const PosShiftCloseSummary({
    required this.shiftId,
    required this.openingFloat,
    required this.ordersCount,
    required this.ordersTotal,
    required this.unpaidOrdersCount,
    required this.unpaidOrdersTotal,
    required this.tipsTotal,
    required this.cashFromSales,
    required this.changeGivenTotal,
    required this.expectedCash,
    required this.paymentMethods,
    this.openedAt,
  });

  final int shiftId;
  final String? openedAt;
  final double openingFloat;
  final int ordersCount;
  final double ordersTotal;
  final int unpaidOrdersCount;
  final double unpaidOrdersTotal;
  final double tipsTotal;
  final double cashFromSales;
  final double changeGivenTotal;
  final double expectedCash;
  final Map<String, PosShiftPaymentMethodTotal> paymentMethods;

  factory PosShiftCloseSummary.fromJson(Map<String, dynamic> json) {
    final methodsRaw = json['payment_methods'];
    final methods = <String, PosShiftPaymentMethodTotal>{};
    if (methodsRaw is Map) {
      methodsRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          methods['$key'] = PosShiftPaymentMethodTotal.fromJson(value);
        } else if (value is Map) {
          methods['$key'] = PosShiftPaymentMethodTotal.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return PosShiftCloseSummary(
      shiftId: parseJsonInt(json['shift_id']),
      openedAt: json['opened_at'] as String?,
      openingFloat: parseJsonDoubleOrNull(json['opening_float']) ?? 0,
      ordersCount: parseJsonInt(json['orders_count']),
      ordersTotal: parseJsonDoubleOrNull(json['orders_total']) ?? 0,
      unpaidOrdersCount: parseJsonInt(json['unpaid_orders_count']),
      unpaidOrdersTotal:
          parseJsonDoubleOrNull(json['unpaid_orders_total']) ?? 0,
      tipsTotal: parseJsonDoubleOrNull(json['tips_total']) ?? 0,
      cashFromSales: parseJsonDoubleOrNull(json['cash_from_sales']) ?? 0,
      changeGivenTotal: parseJsonDoubleOrNull(json['change_given_total']) ?? 0,
      expectedCash: parseJsonDoubleOrNull(json['expected_cash']) ?? 0,
      paymentMethods: methods,
    );
  }
}

class PosShiftPaymentMethodTotal {
  const PosShiftPaymentMethodTotal({
    required this.count,
    required this.total,
  });

  final int count;
  final double total;

  factory PosShiftPaymentMethodTotal.fromJson(Map<String, dynamic> json) {
    return PosShiftPaymentMethodTotal(
      count: parseJsonInt(json['count']),
      total: parseJsonDoubleOrNull(json['total']) ?? 0,
    );
  }
}

class PosSyncInfo {
  PosSyncInfo({
    this.menuRevision,
    this.bootstrapRevision,
  });

  final String? menuRevision;
  final String? bootstrapRevision;

  factory PosSyncInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PosSyncInfo();
    return PosSyncInfo(
      menuRevision: json['menu_revision'] as String?,
      bootstrapRevision: json['bootstrap_revision'] as String?,
    );
  }
}

/// Response from `GET /api/v1/pos/sync` (revisions + app update).
class PosSyncStatus {
  PosSyncStatus({
    this.menuRevision,
    this.bootstrapRevision,
    this.appUpdate = const PosAppUpdate(status: 'none', currentVersion: ''),
  });

  final String? menuRevision;
  final String? bootstrapRevision;
  final PosAppUpdate appUpdate;

  factory PosSyncStatus.fromJson(Map<String, dynamic> json) {
    final sync = json['sync'] as Map<String, dynamic>?;
    return PosSyncStatus(
      menuRevision: sync?['menu_revision'] as String?,
      bootstrapRevision: sync?['bootstrap_revision'] as String?,
      appUpdate: PosAppUpdate.fromJson(
        mergedPosAppUpdateJson(json),
      ),
    );
  }
}

class PaymentGatewayOption {
  const PaymentGatewayOption({
    required this.slug,
    required this.label,
    required this.type,
  });

  final String slug;
  final String label;
  final String type;

  bool get isDynamicQr => type == 'dynamic_qr';

  factory PaymentGatewayOption.fromJson(Map<String, dynamic> json) {
    return PaymentGatewayOption(
      slug: json['slug'] as String,
      label: json['label'] as String? ?? json['slug'] as String,
      type: json['type'] as String? ?? 'dynamic_qr',
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'label': label,
        'type': type,
      };
}

class PaymentQrData {
  const PaymentQrData({
    required this.upiUrl,
    required this.qrUrl,
    required this.displayUpiId,
    required this.payeeName,
  });

  final String upiUrl;
  final String qrUrl;
  final String displayUpiId;
  final String payeeName;

  factory PaymentQrData.fromJson(Map<String, dynamic> json) {
    return PaymentQrData(
      upiUrl: json['upi_url'] as String? ?? '',
      qrUrl: json['qr_url'] as String? ?? '',
      displayUpiId: json['display_upi_id'] as String? ?? '',
      payeeName: json['payee_name'] as String? ?? '',
    );
  }
}

class PosOrderPaymentInfo {
  const PosOrderPaymentInfo({
    required this.type,
    required this.gateway,
    this.timeoutSeconds = 300,
    this.amount,
    this.qr,
  });

  final String type;
  final String gateway;
  final int timeoutSeconds;
  final double? amount;
  final PaymentQrData? qr;

  bool get isDynamicQr => type == 'dynamic_qr';

  factory PosOrderPaymentInfo.fromJson(Map<String, dynamic> json) {
    final qrJson = json['qr'];
    return PosOrderPaymentInfo(
      type: json['type'] as String? ?? 'dynamic_qr',
      gateway: json['gateway'] as String? ?? '',
      timeoutSeconds: parseJsonInt(json['timeout_seconds'], fallback: 300),
      amount: parseJsonDoubleOrNull(json['amount']) ??
          parseJsonDoubleOrNull(json['amount_due']),
      qr: qrJson is Map<String, dynamic>
          ? PaymentQrData.fromJson(qrJson)
          : null,
    );
  }
}

class PosPlatformBranding {
  const PosPlatformBranding({
    this.name = PosAppInfo.displayName,
    this.tagline,
    this.adminLogoUrl,
    this.showName = true,
    this.logoWidth = 40,
    this.poweredByText,
    this.poweredByLogoUrl,
    this.poweredByVisible = false,
  });

  final String name;
  final String? tagline;
  final String? adminLogoUrl;
  final bool showName;
  final int logoWidth;
  final String? poweredByText;
  final String? poweredByLogoUrl;
  final bool poweredByVisible;

  factory PosPlatformBranding.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PosPlatformBranding();
    final name = (json['name'] as String?)?.trim();
    final width = parseJsonInt(json['logo_width'], fallback: 40);
    return PosPlatformBranding(
      name: name != null && name.isNotEmpty ? name : PosAppInfo.displayName,
      tagline: (json['tagline'] as String?)?.trim(),
      adminLogoUrl: (json['admin_logo_url'] as String?)?.trim(),
      showName: parseJsonBool(json['show_name'], fallback: true),
      logoWidth: width.clamp(24, 360),
      poweredByText: (json['powered_by_text'] as String?)?.trim(),
      poweredByLogoUrl: (json['powered_by_logo_url'] as String?)?.trim(),
      poweredByVisible: parseJsonBool(json['powered_by_visible']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (tagline != null) 'tagline': tagline,
        if (adminLogoUrl != null) 'admin_logo_url': adminLogoUrl,
        'show_name': showName,
        'logo_width': logoWidth,
        if (poweredByText != null) 'powered_by_text': poweredByText,
        if (poweredByLogoUrl != null) 'powered_by_logo_url': poweredByLogoUrl,
        'powered_by_visible': poweredByVisible,
      };
}

class PosLanguageOption {
  const PosLanguageOption({
    required this.code,
    required this.name,
    this.isRtl = false,
  });

  final String code;
  final String name;
  final bool isRtl;

  factory PosLanguageOption.fromJson(Map<String, dynamic> json) {
    return PosLanguageOption(
      code: ((json['code'] as String?) ?? '').trim().toLowerCase(),
      name: ((json['name'] as String?) ?? '').trim(),
      isRtl: json['is_rtl'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'is_rtl': isRtl,
      };
}

class PosBootstrap {
  PosBootstrap({
    required this.restaurant,
    required this.branch,
    required this.categories,
    required this.popularItems,
    required this.showPopularItems,
    required this.requireShiftForPos,
    required this.posBlocked,
    required this.posTerminals,
    this.currentShift,
    this.sync,
    this.receiptSettings,
    this.receiptSettingsRaw,
    this.posReceiptPrintMode,
    this.paymentGateways = const [],
    this.paymentQrTimeoutSeconds = 300,
    this.platform = const PosPlatformBranding(),
    this.appUpdate = const PosAppUpdate(status: 'none', currentVersion: ''),
    this.showLanguageSwitcher = false,
    this.supportedLanguages = const [],
    this.languageCatalogs = const {},
    this.adminCapabilities = const PosAdminCapabilities(),
    this.permissions = const [],
    this.guestOrdering = const PosGuestOrdering(),
    this.openingHours = const PosOpeningHours(),
    this.marketplacePlatforms = const [],
  });

  final PosRestaurantInfo restaurant;
  final PosBranchInfo branch;
  final List<MenuCategory> categories;
  final List<MenuItem> popularItems;
  final bool showPopularItems;
  final bool requireShiftForPos;
  final bool posBlocked;
  final List<PosTerminalInfo> posTerminals;
  final PosShift? currentShift;
  final PosSyncInfo? sync;
  final PosReceiptSettings? receiptSettings;
  /// Unparsed bootstrap `receipt_settings` so POS can honor customer/counter flags.
  final Map<String, dynamic>? receiptSettingsRaw;
  final String? posReceiptPrintMode;
  final List<PaymentGatewayOption> paymentGateways;
  final int paymentQrTimeoutSeconds;
  final PosPlatformBranding platform;
  final PosAppUpdate appUpdate;
  final bool showLanguageSwitcher;
  final List<PosLanguageOption> supportedLanguages;
  final Map<String, Map<String, String>> languageCatalogs;
  final PosAdminCapabilities adminCapabilities;

  /// Staff permission keys for the current restaurant (e.g. access_pos).
  final List<String> permissions;
  final PosGuestOrdering guestOrdering;
  final PosOpeningHours openingHours;

  /// Enabled delivery partners for this branch (e.g. zomato, swiggy).
  final List<MarketplacePlatformInfo> marketplacePlatforms;

  bool get canUseRegister => permissions.contains('access_pos');

  bool get canUseCaptain => permissions.contains('access_pos_captain');

  bool get canChooseWorkMode => canUseRegister && canUseCaptain;

  bool marketplaceEnabled(String provider) {
    final key = provider.trim().toLowerCase();
    return marketplacePlatforms.any((p) => p.provider == key);
  }

  bool get allowsPosDelivery => restaurant.ordering.allowsPosDelivery;

  PosBootstrap copyWith({
    PosGuestOrdering? guestOrdering,
    PosOpeningHours? openingHours,
    PosAdminCapabilities? adminCapabilities,
    List<String>? permissions,
    List<MarketplacePlatformInfo>? marketplacePlatforms,
  }) {
    return PosBootstrap(
      restaurant: restaurant,
      branch: branch,
      categories: categories,
      popularItems: popularItems,
      showPopularItems: showPopularItems,
      requireShiftForPos: requireShiftForPos,
      posBlocked: posBlocked,
      posTerminals: posTerminals,
      currentShift: currentShift,
      sync: sync,
      receiptSettings: receiptSettings,
      receiptSettingsRaw: receiptSettingsRaw,
      posReceiptPrintMode: posReceiptPrintMode,
      paymentGateways: paymentGateways,
      paymentQrTimeoutSeconds: paymentQrTimeoutSeconds,
      platform: platform,
      appUpdate: appUpdate,
      showLanguageSwitcher: showLanguageSwitcher,
      supportedLanguages: supportedLanguages,
      languageCatalogs: languageCatalogs,
      adminCapabilities: adminCapabilities ?? this.adminCapabilities,
      permissions: permissions ?? this.permissions,
      guestOrdering: guestOrdering ?? this.guestOrdering,
      openingHours: openingHours ?? this.openingHours,
      marketplacePlatforms:
          marketplacePlatforms ?? this.marketplacePlatforms,
    );
  }

  factory PosBootstrap.fromJson(Map<String, dynamic> json) {
    final shiftJson = json['current_shift'] as Map<String, dynamic>?;
    final syncJson = json['sync'] as Map<String, dynamic>?;
    final receiptJson = json['receipt_settings'] as Map<String, dynamic>?;
    final platformJson = json['platform'] as Map<String, dynamic>?;
    final languagesPayload =
        json['languages'] as Map<String, dynamic>? ?? const {};
    final supportedLanguages =
        (languagesPayload['supported'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (row) => PosLanguageOption.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .where((lang) => lang.code.isNotEmpty)
            .toList();
    final languageCatalogs = <String, Map<String, String>>{};
    final catalogsRaw = languagesPayload['catalogs'];
    if (catalogsRaw is Map) {
      catalogsRaw.forEach((localeKey, value) {
        if (value is! Map) return;
        final code = localeKey.toString().trim().toLowerCase();
        if (code.isEmpty || code == 'en') return;
        final flat = <String, String>{};
        value.forEach((stringKey, stringValue) {
          if (stringKey == null || stringValue == null) return;
          final key = stringKey.toString();
          final text = stringValue.toString();
          if (key.isEmpty || text.trim().isEmpty) return;
          flat[key] = text;
        });
        if (flat.isNotEmpty) {
          languageCatalogs[code] = flat;
        }
      });
    }
    return PosBootstrap(
      restaurant: PosRestaurantInfo.fromJson(
        json['restaurant'] as Map<String, dynamic>,
      ),
      branch: PosBranchInfo.fromJson(json['branch'] as Map<String, dynamic>),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      popularItems: (json['popular_items'] as List<dynamic>? ?? [])
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      showPopularItems: parseJsonBool(json['show_popular_items'], fallback: true),
      requireShiftForPos: parseJsonBool(json['require_shift_for_pos']),
      posBlocked: parseJsonBool(json['pos_blocked']),
      posTerminals: (json['pos_terminals'] as List<dynamic>? ?? [])
          .map((e) => PosTerminalInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentShift:
          shiftJson != null ? PosShift.fromJson(shiftJson) : null,
      sync: PosSyncInfo.fromJson(syncJson),
      receiptSettings: PosReceiptSettings.fromJson(receiptJson),
      receiptSettingsRaw: receiptJson == null
          ? null
          : Map<String, dynamic>.from(receiptJson),
      posReceiptPrintMode: json['pos_receipt_print_mode'] as String?,
      paymentGateways: (json['payment_gateways'] as List<dynamic>? ?? [])
          .map((e) => PaymentGatewayOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      paymentQrTimeoutSeconds:
          parseJsonInt(json['payment_qr_timeout_seconds'], fallback: 300),
      platform: PosPlatformBranding.fromJson(platformJson),
      appUpdate: PosAppUpdate.fromJson(
        mergedPosAppUpdateJson(json),
      ),
      showLanguageSwitcher:
          languagesPayload['show_switcher'] as bool? ?? false,
      supportedLanguages: supportedLanguages,
      languageCatalogs: languageCatalogs,
      adminCapabilities: PosAdminCapabilities.fromJson(
        json['admin_capabilities'] as Map<String, dynamic>?,
      ),
      permissions: (json['permissions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      guestOrdering: PosGuestOrdering.fromJson(
        json['guest_ordering'] as Map<String, dynamic>?,
      ),
      openingHours: PosOpeningHours.fromJson(
        json['opening_hours'] as Map<String, dynamic>?,
      ),
      marketplacePlatforms:
          (json['marketplace_platforms'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (row) => MarketplacePlatformInfo.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .where((p) => p.provider.isNotEmpty)
              .toList(),
    );
  }
}

class MarketplacePlatformInfo {
  const MarketplacePlatformInfo({
    required this.provider,
    required this.label,
  });

  final String provider;
  final String label;

  factory MarketplacePlatformInfo.fromJson(Map<String, dynamic> json) {
    return MarketplacePlatformInfo(
      provider: '${json['provider'] ?? ''}'.trim().toLowerCase(),
      label: '${json['label'] ?? json['provider'] ?? ''}'.trim(),
    );
  }
}

class PlacedPosOrder {
  PlacedPosOrder({
    required this.id,
    required this.orderNumber,
    this.token,
    this.total,
    this.amountDue,
    this.payment,
  });

  final int id;
  final String orderNumber;
  final String? token;
  final double? total;
  final double? amountDue;
  final PosOrderPaymentInfo? payment;

  /// Amount shown / charged on the QR screen (remaining balance when split).
  double get chargeAmount {
    final fromPayment = payment?.amount;
    if (fromPayment != null && fromPayment > 0) return fromPayment;
    final due = amountDue;
    if (due != null && due > 0) return due;
    return total ?? 0;
  }

  bool get isQrPayment =>
      payment?.isDynamicQr == true ||
      payment?.gateway == 'phonepe' ||
      payment?.gateway == 'paytm';

  factory PlacedPosOrder.fromJson(Map<String, dynamic> json) {
    final paymentJson = json['payment'];
    final tokenRaw = json['token'];
    final payment = paymentJson is Map<String, dynamic>
        ? PosOrderPaymentInfo.fromJson(paymentJson)
        : null;
    return PlacedPosOrder(
      id: parseJsonInt(json['id']),
      orderNumber: json['order_number'] as String? ?? '#${json['id']}',
      token: tokenRaw == null ? null : '$tokenRaw',
      total: parseJsonDoubleOrNull(json['total']),
      amountDue: parseJsonDoubleOrNull(json['amount_due']) ??
          parseJsonDoubleOrNull(json['remaining']) ??
          payment?.amount,
      payment: payment,
    );
  }
}

/// Cart-level discount applied before tax / service charge (matches web POS).
class CartDiscount {
  const CartDiscount({
    required this.type,
    required this.value,
    this.reason,
  });

  /// `percent` or `amount`
  final String type;
  final double value;
  final String? reason;

  double amountFor(double subtotal) {
    if (value <= 0 || subtotal <= 0) return 0;
    if (type == 'percent') {
      final pct = value.clamp(0, 100);
      return roundMoney(subtotal * pct / 100);
    }
      return roundMoney(value.clamp(0.0, subtotal));
  }

  Map<String, dynamic> toApiJson() => {
        'type': type,
        'value': value,
        if (reason != null && reason!.trim().isNotEmpty)
          'reason': reason!.trim(),
      };

  static CartDiscount? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final type = json['type'] as String?;
    final value = parseJsonDouble(json['value']);
    if (type != 'percent' && type != 'amount') return null;
    if (value <= 0) return null;
    final reason = json['reason'] as String?;
    return CartDiscount(
      type: type!,
      value: value,
      reason: (reason != null && reason.trim().isNotEmpty) ? reason.trim() : null,
    );
  }
}
