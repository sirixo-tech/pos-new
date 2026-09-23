enum WaiterAlertType {
  kitchenReady,
  billRequested,
  newOrder,
  marketplaceOrder;

  static WaiterAlertType fromStorage(String? raw) {
    return switch (raw) {
      'billRequested' || 'bill' => WaiterAlertType.billRequested,
      'marketplaceOrder' || 'marketplace' => WaiterAlertType.marketplaceOrder,
      'newOrder' || 'order' => WaiterAlertType.newOrder,
      _ => WaiterAlertType.kitchenReady,
    };
  }

  String get storageValue => switch (this) {
        WaiterAlertType.kitchenReady => 'kitchenReady',
        WaiterAlertType.billRequested => 'billRequested',
        WaiterAlertType.newOrder => 'newOrder',
        WaiterAlertType.marketplaceOrder => 'marketplaceOrder',
      };

  bool get isNewOrderCue =>
      this == WaiterAlertType.newOrder || this == WaiterAlertType.marketplaceOrder;

  bool get isPriority => this == WaiterAlertType.marketplaceOrder;
}

/// Local captain/waiter notification (kitchen ready, bill request, etc.).
class WaiterAlert {
  const WaiterAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.at,
    this.isRead = false,
    this.tableId,
    this.orderId,
    this.tableName,
    this.orderNumber,
    this.source,
    this.externalId,
    this.orderType,
    this.total,
    this.token,
  });

  final String id;
  final WaiterAlertType type;
  final String title;
  final String body;
  final DateTime at;
  final bool isRead;
  final int? tableId;
  final int? orderId;
  final String? tableName;
  final String? orderNumber;
  final String? source;
  final String? externalId;
  final String? orderType;
  final double? total;
  final String? token;

  bool get isPriority => type.isPriority;

  WaiterAlert copyWith({
    String? id,
    WaiterAlertType? type,
    String? title,
    String? body,
    DateTime? at,
    bool? isRead,
    int? tableId,
    int? orderId,
    String? tableName,
    String? orderNumber,
    String? source,
    String? externalId,
    String? orderType,
    double? total,
    String? token,
  }) {
    return WaiterAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      at: at ?? this.at,
      isRead: isRead ?? this.isRead,
      tableId: tableId ?? this.tableId,
      orderId: orderId ?? this.orderId,
      tableName: tableName ?? this.tableName,
      orderNumber: orderNumber ?? this.orderNumber,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      orderType: orderType ?? this.orderType,
      total: total ?? this.total,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.storageValue,
        'title': title,
        'body': body,
        'at': at.toIso8601String(),
        'isRead': isRead,
        'tableId': tableId,
        'orderId': orderId,
        'tableName': tableName,
        'orderNumber': orderNumber,
        'source': source,
        'externalId': externalId,
        'orderType': orderType,
        'total': total,
        'token': token,
      };

  factory WaiterAlert.fromJson(Map<String, dynamic> json) {
    return WaiterAlert(
      id: '${json['id'] ?? ''}',
      type: WaiterAlertType.fromStorage(json['type']?.toString()),
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? json['message'] ?? ''}',
      at: DateTime.tryParse('${json['at'] ?? ''}') ?? DateTime.now(),
      isRead: json['isRead'] == true,
      tableId: _asInt(json['tableId']),
      orderId: _asInt(json['orderId']),
      tableName: json['tableName']?.toString(),
      orderNumber: json['orderNumber']?.toString(),
      source: json['source']?.toString(),
      externalId:
          json['externalId']?.toString() ?? json['external_id']?.toString(),
      orderType: json['orderType']?.toString() ?? json['order_type']?.toString(),
      total: _asDouble(json['total']),
      token: json['token']?.toString(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('$value');
  }
}
