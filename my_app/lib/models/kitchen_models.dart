import '../utils/json_parse.dart';

class KitchenStation {
  const KitchenStation({
    required this.id,
    required this.name,
    this.counterName,
  });

  final int id;
  final String name;
  final String? counterName;

  String get label {
    final counter = counterName?.trim();
    if (counter != null && counter.isNotEmpty) return counter;
    return name;
  }

  factory KitchenStation.fromJson(Map<String, dynamic> json) {
    return KitchenStation(
      id: parseJsonInt(json['id']),
      name: json['name']?.toString() ?? '',
      counterName: json['counter_name']?.toString(),
    );
  }
}

class KitchenBootstrap {
  const KitchenBootstrap({
    required this.queueRequired,
    required this.kitchens,
    this.branchName,
    this.restaurantName,
  });

  final bool queueRequired;
  final List<KitchenStation> kitchens;
  final String? branchName;
  final String? restaurantName;

  factory KitchenBootstrap.fromJson(Map<String, dynamic> json) {
    final kitchensRaw = json['kitchens'];
    return KitchenBootstrap(
      queueRequired: parseJsonBool(json['queue_required']),
      kitchens: kitchensRaw is List
          ? kitchensRaw
              .whereType<Map>()
              .map((e) => KitchenStation.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      branchName: (json['branch'] as Map?)?['name']?.toString(),
      restaurantName: (json['restaurant'] as Map?)?['name']?.toString(),
    );
  }
}

class KitchenBoard {
  const KitchenBoard({
    required this.pending,
    required this.confirmed,
    required this.preparing,
    required this.ready,
  });

  final List<KitchenBoardOrder> pending;
  final List<KitchenBoardOrder> confirmed;
  final List<KitchenBoardOrder> preparing;
  final List<KitchenBoardOrder> ready;

  List<KitchenBoardOrder> forStatus(String status) => switch (status) {
        'pending' => pending,
        'confirmed' => confirmed,
        'preparing' => preparing,
        'ready' => ready,
        _ => const [],
      };

  int get totalActive =>
      pending.length + confirmed.length + preparing.length + ready.length;
}

class KitchenBoardOrder {
  const KitchenBoardOrder({
    required this.id,
    required this.kitchenTicketId,
    required this.status,
    required this.orderNumber,
    required this.kotRound,
    required this.kitchenPriority,
    required this.items,
    this.token,
    this.type,
    this.source,
    this.tableName,
    this.customerName,
    this.customerAddress,
    this.notes,
    this.kitchenName,
    this.createdAt,
    this.preparingStartedAt,
  });

  final int id;
  final int kitchenTicketId;
  final String status;
  final String orderNumber;
  final int kotRound;
  final int kitchenPriority;
  final List<KitchenBoardItem> items;
  final String? token;
  final String? type;
  final String? source;
  final String? tableName;
  final String? customerName;
  final String? customerAddress;
  final String? notes;
  final String? kitchenName;
  final DateTime? createdAt;
  final DateTime? preparingStartedAt;

  bool matches(KitchenBoardOrder other) {
    if (other.kitchenTicketId > 0 && kitchenTicketId > 0) {
      return kitchenTicketId == other.kitchenTicketId;
    }
    return id == other.id;
  }

  KitchenBoardOrder copyWith({
    String? status,
    DateTime? preparingStartedAt,
    List<KitchenBoardItem>? items,
  }) {
    return KitchenBoardOrder(
      id: id,
      kitchenTicketId: kitchenTicketId,
      status: status ?? this.status,
      orderNumber: orderNumber,
      kotRound: kotRound,
      kitchenPriority: kitchenPriority,
      items: items ?? this.items,
      token: token,
      type: type,
      source: source,
      tableName: tableName,
      customerName: customerName,
      customerAddress: customerAddress,
      notes: notes,
      kitchenName: kitchenName,
      createdAt: createdAt,
      preparingStartedAt: preparingStartedAt ?? this.preparingStartedAt,
    );
  }

  factory KitchenBoardOrder.fromJson(Map<String, dynamic> json) {
    final nestedOrder = json['order'] is Map
        ? Map<String, dynamic>.from(json['order'] as Map)
        : const <String, dynamic>{};
    final itemsRaw = json['order_items'] ??
        json['orderItems'] ??
        nestedOrder['order_items'] ??
        nestedOrder['orderItems'];
    return KitchenBoardOrder(
      id: parseJsonInt(json['id']),
      kitchenTicketId: parseJsonInt(json['kitchen_ticket_id']),
      status: json['status']?.toString() ?? 'pending',
      orderNumber: json['order_number']?.toString() ?? '',
      kotRound: parseJsonInt(json['kot_round'], fallback: 1),
      kitchenPriority: parseJsonInt(json['kitchen_priority']),
      token: json['token']?.toString(),
      type: _firstText([
        json['type'],
        json['order_type'],
        json['orderType'],
        nestedOrder['type'],
        nestedOrder['order_type'],
        nestedOrder['orderType'],
      ]),
      source: _firstText([
        json['source'],
        json['order_source'],
        json['orderSource'],
        json['channel'],
        nestedOrder['source'],
        nestedOrder['order_source'],
        nestedOrder['orderSource'],
        nestedOrder['channel'],
      ]),
      tableName: json['table_name']?.toString(),
      customerName: json['customer_name']?.toString(),
      customerAddress: json['customer_address']?.toString(),
      notes: json['notes']?.toString(),
      kitchenName: json['kitchen_name']?.toString(),
      createdAt: _parseDate(json['created_at']),
      preparingStartedAt: _parseDate(json['preparing_started_at']),
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => KitchenBoardItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class KitchenBoardItem {
  const KitchenBoardItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.variantName,
    this.notes,
    this.stationName,
    this.kitchenStatus,
    this.modifiers = const [],
  });

  final int id;
  final String name;
  final int quantity;
  final String? variantName;
  final String? notes;
  final String? stationName;
  final String? kitchenStatus;
  final List<String> modifiers;

  bool get isReady => kitchenStatus == 'ready';

  bool get isCooking => kitchenStatus == 'preparing';

  bool get isDelivered => kitchenStatus == 'delivered';

  bool get isLocked => kitchenStatus == 'cancelled';

  KitchenBoardItem copyWith({String? kitchenStatus}) {
    return KitchenBoardItem(
      id: id,
      name: name,
      quantity: quantity,
      variantName: variantName,
      notes: notes,
      stationName: stationName,
      kitchenStatus: kitchenStatus ?? this.kitchenStatus,
      modifiers: modifiers,
    );
  }

  factory KitchenBoardItem.fromJson(Map<String, dynamic> json) {
    final mods = json['modifiers'];
    return KitchenBoardItem(
      id: parseJsonInt(json['id']),
      name: json['menu_item_name']?.toString() ?? '',
      quantity: parseJsonInt(json['quantity'], fallback: 1),
      variantName: json['variant_name']?.toString(),
      notes: json['notes']?.toString(),
      stationName: json['kitchen_counter_name']?.toString(),
      kitchenStatus: json['kitchen_status']?.toString(),
      modifiers: mods is List
          ? mods
              .whereType<Map>()
              .map((m) {
                final option = m['option_name']?.toString().trim() ?? '';
                final modifier = m['modifier_name']?.toString().trim() ?? '';
                if (option.isEmpty) return modifier;
                if (modifier.isEmpty) return option;
                return '$modifier: $option';
              })
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

String? _firstText(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
