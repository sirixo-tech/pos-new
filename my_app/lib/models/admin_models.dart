List<int> _asIntList(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final entry in value)
      if (entry is num)
        entry.toInt()
      else if (entry != null && int.tryParse('$entry') != null)
        int.parse('$entry'),
  ];
}

List<T> _asObjectList<T>(
  dynamic value,
  T Function(Map<String, dynamic> json) map,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => map(Map<String, dynamic>.from(e)))
      .toList();
}

class PosAdminCapabilities {
  const PosAdminCapabilities({
    this.permissions = const [],
    this.canViewOrders = false,
    this.canManageOrders = false,
    this.canViewMenu = false,
    this.canManageMenu = false,
    this.canManageMenuCategories = false,
    this.canManageMenuItems = false,
    this.canManageMenuModifiers = false,
    this.canManageMenuTimeSlots = false,
    this.canToggleMenuAvailability = false,
    this.canViewTables = false,
    this.canManageTables = false,
    this.canManageSettings = false,
    this.canManageBilling = false,
    this.canAccessAdmin = false,
  });

  final List<String> permissions;
  final bool canViewOrders;
  final bool canManageOrders;
  final bool canViewMenu;
  final bool canManageMenu;
  final bool canManageMenuCategories;
  final bool canManageMenuItems;
  final bool canManageMenuModifiers;
  final bool canManageMenuTimeSlots;
  final bool canToggleMenuAvailability;
  final bool canViewTables;
  final bool canManageTables;
  final bool canManageSettings;
  final bool canManageBilling;
  final bool canAccessAdmin;

  factory PosAdminCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PosAdminCapabilities();
    }
    return PosAdminCapabilities(
      permissions: (json['permissions'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      canViewOrders: json['can_view_orders'] == true,
      canManageOrders: json['can_manage_orders'] == true,
      canViewMenu: json['can_view_menu'] == true,
      canManageMenu: json['can_manage_menu'] == true,
      canManageMenuCategories: json['can_manage_menu_categories'] == true,
      canManageMenuItems: json['can_manage_menu_items'] == true,
      canManageMenuModifiers: json['can_manage_menu_modifiers'] == true,
      canManageMenuTimeSlots: json['can_manage_menu_time_slots'] == true,
      canToggleMenuAvailability: json['can_toggle_menu_availability'] == true,
      canViewTables: json['can_view_tables'] == true,
      canManageTables: json['can_manage_tables'] == true,
      canManageSettings: json['can_manage_settings'] == true,
      canManageBilling: json['can_manage_billing'] == true,
      canAccessAdmin: json['can_access_admin'] == true,
    );
  }
}

class AdminOrderSummary {
  AdminOrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.type,
    this.source,
    this.posChannel,
    required this.total,
    this.token,
    this.customerName,
    this.tableName,
    this.createdAt,
    this.paymentHint,
  });

  final int id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String? type;
  final String? source;
  final String? posChannel;
  final double total;
  final int? token;
  final String? customerName;
  final String? tableName;
  final DateTime? createdAt;
  final String? paymentHint;

  factory AdminOrderSummary.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] as String?;
    final table = json['table'];
    String? tableName;
    if (table is Map) {
      final name = table['name']?.toString().trim();
      if (name != null && name.isNotEmpty) tableName = name;
    }
    tableName ??= json['table_name']?.toString().trim();
    final idRaw = json['id'];
    final id = idRaw is num
        ? idRaw.toInt()
        : int.tryParse('$idRaw') ?? 0;
    return AdminOrderSummary(
      id: id,
      orderNumber: '${json['order_number'] ?? '#$id'}',
      status: json['status'] as String? ?? 'pending',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String?,
      type: json['type'] as String?,
      source: json['source'] as String?,
      posChannel: json['pos_channel'] as String?,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      token: json['token'] is int
          ? json['token'] as int
          : int.tryParse('${json['token'] ?? ''}'),
      customerName: json['customer_name'] as String?,
      tableName: tableName,
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
      paymentHint: json['payment_hint'] as String?,
    );
  }

  /// Sparse summary when opening detail from a notification / list card.
  factory AdminOrderSummary.placeholder({
    required int id,
    String? orderNumber,
    String? status,
    String? paymentStatus,
    double? total,
    String? token,
    String? customerName,
    String? tableName,
    String? type,
    String? source,
  }) {
    return AdminOrderSummary(
      id: id,
      orderNumber: (orderNumber ?? '').trim().isEmpty ? '#$id' : orderNumber!.trim(),
      status: status ?? 'pending',
      paymentStatus: paymentStatus ?? 'pending',
      total: total ?? 0,
      token: token != null ? int.tryParse(token) : null,
      customerName: customerName,
      tableName: tableName,
      type: type,
      source: source,
    );
  }
}

class AdminOrdersPage {
  AdminOrdersPage({
    required this.orders,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<AdminOrderSummary> orders;
  final int currentPage;
  final int lastPage;
  final int total;

  factory AdminOrdersPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    return AdminOrdersPage(
      orders: (json['data'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => AdminOrderSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      currentPage: meta['current_page'] as int? ?? 1,
      lastPage: meta['last_page'] as int? ?? 1,
      total: meta['total'] as int? ?? 0,
    );
  }
}

class AdminMenuCategory {
  AdminMenuCategory({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.items,
    this.imageUrl,
    this.timeSlotIds = const [],
  });

  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final List<AdminMenuItem> items;
  final String? imageUrl;
  final List<int> timeSlotIds;

  factory AdminMenuCategory.fromJson(Map<String, dynamic> json) {
    return AdminMenuCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      timeSlotIds: _asIntList(json['time_slot_ids']),
      items: _asObjectList(json['items'], AdminMenuItem.fromJson),
    );
  }

  AdminMenuCategory copyWith({
    String? name,
    String? description,
    bool? isActive,
    List<AdminMenuItem>? items,
    String? imageUrl,
    List<int>? timeSlotIds,
  }) =>
      AdminMenuCategory(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        items: items ?? this.items,
        imageUrl: imageUrl ?? this.imageUrl,
        timeSlotIds: timeSlotIds ?? this.timeSlotIds,
      );
}

class AdminMenuItem {
  AdminMenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.isAvailable,
    this.imageUrl,
    this.itemType,
    this.timeSlotIds = const [],
    this.modifierIds = const [],
  });

  final int id;
  final String name;
  final String? description;
  final double price;
  final bool isAvailable;
  final String? imageUrl;
  final String? itemType;
  final List<int> timeSlotIds;
  final List<int> modifierIds;

  factory AdminMenuItem.fromJson(Map<String, dynamic> json) {
    final modifiers = _asObjectList(json['modifiers'], AdminMenuModifier.fromJson);
    final modifierIds = _asIntList(json['modifier_ids']);
    return AdminMenuItem(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      isAvailable: json['is_available'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      timeSlotIds: _asIntList(json['time_slot_ids']),
      modifierIds: modifierIds.isNotEmpty
          ? modifierIds
          : modifiers.map((m) => m.id).toList(),
    );
  }

  AdminMenuItem copyWith({
    String? name,
    String? description,
    double? price,
    bool? isAvailable,
    String? imageUrl,
    String? itemType,
    List<int>? timeSlotIds,
    List<int>? modifierIds,
  }) =>
      AdminMenuItem(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        isAvailable: isAvailable ?? this.isAvailable,
        imageUrl: imageUrl ?? this.imageUrl,
        itemType: itemType ?? this.itemType,
        timeSlotIds: timeSlotIds ?? this.timeSlotIds,
        modifierIds: modifierIds ?? this.modifierIds,
      );
}

class AdminMenuModifierOption {
  AdminMenuModifierOption({
    this.id,
    required this.name,
    required this.priceAdjustment,
    this.sortOrder = 0,
    this.isAvailable = true,
  });

  final int? id;
  final String name;
  final double priceAdjustment;
  final int sortOrder;
  final bool isAvailable;

  factory AdminMenuModifierOption.fromJson(Map<String, dynamic> json) {
    return AdminMenuModifierOption(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      priceAdjustment: (json['price_adjustment'] as num?)?.toDouble() ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'price_adjustment': priceAdjustment,
        'sort_order': sortOrder,
        'is_available': isAvailable,
      };
}

class AdminMenuModifier {
  AdminMenuModifier({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.minSelections,
    this.maxSelections,
    this.sortOrder = 0,
    this.options = const [],
  });

  final int id;
  final String name;
  final bool isRequired;
  final int minSelections;
  final int? maxSelections;
  final int sortOrder;
  final List<AdminMenuModifierOption> options;

  String get summaryLabel {
    final count = options.length;
    final req = isRequired ? 'Required' : 'Optional';
    return '$req · $count option${count == 1 ? '' : 's'}';
  }

  factory AdminMenuModifier.fromJson(Map<String, dynamic> json) {
    return AdminMenuModifier(
      id: json['id'] as int,
      name: json['name'] as String,
      isRequired: json['is_required'] as bool? ?? false,
      minSelections: json['min_selections'] as int? ?? 0,
      maxSelections: json['max_selections'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      options: _asObjectList(json['options'], AdminMenuModifierOption.fromJson),
    );
  }
}

class AdminMenuTimeSlot {
  AdminMenuTimeSlot({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.daysOfWeek = const [],
    required this.sortOrder,
    required this.isActive,
    required this.isLive,
  });

  final int id;
  final String name;
  final String startTime;
  final String endTime;
  final List<int> daysOfWeek;
  final int sortOrder;
  final bool isActive;
  final bool isLive;

  String get windowLabel => '$startTime – $endTime';

  factory AdminMenuTimeSlot.fromJson(Map<String, dynamic> json) {
    return AdminMenuTimeSlot(
      id: json['id'] as int,
      name: json['name'] as String,
      startTime: json['start_time'] as String? ?? '00:00',
      endTime: json['end_time'] as String? ?? '23:59',
      daysOfWeek: _asIntList(json['days_of_week']),
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isLive: json['is_live'] as bool? ?? false,
    );
  }
}

class AdminMenuPayload {
  AdminMenuPayload({
    required this.categories,
    required this.timeSlots,
    this.modifiers = const [],
  });

  final List<AdminMenuCategory> categories;
  final List<AdminMenuTimeSlot> timeSlots;
  final List<AdminMenuModifier> modifiers;

  factory AdminMenuPayload.fromJson(Map<String, dynamic> json) {
    return AdminMenuPayload(
      categories: _asObjectList(json['categories'], AdminMenuCategory.fromJson),
      timeSlots: _asObjectList(json['time_slots'], AdminMenuTimeSlot.fromJson),
      modifiers: _asObjectList(json['modifiers'], AdminMenuModifier.fromJson),
    );
  }
}

class AdminTableArea {
  AdminTableArea({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.tables = const [],
  });

  final int id;
  final String name;
  final int sortOrder;
  final List<AdminTable> tables;

  factory AdminTableArea.fromJson(Map<String, dynamic> json) {
    return AdminTableArea(
      id: json['id'] as int,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      tables: _asObjectList(json['tables'], AdminTable.fromJson),
    );
  }
}

class AdminTable {
  AdminTable({
    required this.id,
    this.tableAreaId,
    required this.name,
    required this.status,
    this.capacity,
    this.sortOrder = 0,
    this.posX,
    this.posY,
    this.width,
    this.height,
    this.shape,
  });

  final int id;
  final int? tableAreaId;
  final String name;
  final String status;
  final int? capacity;
  final int sortOrder;
  final int? posX;
  final int? posY;
  final int? width;
  final int? height;
  final String? shape;

  factory AdminTable.fromJson(Map<String, dynamic> json) {
    return AdminTable(
      id: json['id'] as int,
      tableAreaId: json['table_area_id'] as int?,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'available',
      capacity: json['capacity'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      posX: json['pos_x'] as int?,
      posY: json['pos_y'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      shape: json['shape'] as String?,
    );
  }
}

class AdminTablesPayload {
  AdminTablesPayload({
    required this.areas,
    required this.tablesWithoutArea,
    required this.tables,
  });

  final List<AdminTableArea> areas;
  final List<AdminTable> tablesWithoutArea;
  final List<AdminTable> tables;

  factory AdminTablesPayload.fromJson(Map<String, dynamic> json) {
    return AdminTablesPayload(
      areas: _asObjectList(json['table_areas'], AdminTableArea.fromJson),
      tablesWithoutArea:
          _asObjectList(json['tables_without_area'], AdminTable.fromJson),
      tables: _asObjectList(json['tables'], AdminTable.fromJson),
    );
  }
}

class AdminPaymentCheckResult {
  AdminPaymentCheckResult({
    required this.paid,
    required this.failed,
    required this.timedOut,
    required this.paymentStatus,
    required this.checkedWithGateway,
    required this.message,
    this.failureMessage,
    this.order,
  });

  final bool paid;
  final bool failed;
  final bool timedOut;
  final String paymentStatus;
  final bool checkedWithGateway;
  final String message;
  final String? failureMessage;
  final Map<String, dynamic>? order;

  factory AdminPaymentCheckResult.fromJson(Map<String, dynamic> json) {
    final orderJson = json['order'];
    return AdminPaymentCheckResult(
      paid: json['paid'] as bool? ?? false,
      failed: json['failed'] as bool? ?? false,
      timedOut: json['timed_out'] as bool? ?? false,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      checkedWithGateway: json['checked_with_gateway'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      failureMessage: json['failure_message'] as String?,
      order: orderJson is Map
          ? Map<String, dynamic>.from(orderJson)
          : null,
    );
  }
}
