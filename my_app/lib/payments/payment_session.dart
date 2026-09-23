enum PaymentSessionStatus {
  creating,
  waitingForDisplay,
  displayingQr,
  waitingPayment,
  paid,
  cancelled,
  expired,
  failed;

  bool get isTerminal =>
      this == paid || this == cancelled || this == expired || this == failed;
}

class PaymentSession {
  const PaymentSession({
    required this.paymentSessionId,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.qrData,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.orderSnapshot,
    this.transactionId,
    this.successHandled = false,
    this.receiptPrinted = false,
    this.heldForNewOrder = false,
  });

  final String paymentSessionId;
  final int orderId;
  final String orderNumber;
  final String? transactionId;
  final double amount;
  final String qrData;
  final DateTime createdAt;
  final DateTime expiresAt;
  final PaymentSessionStatus status;
  final Map<String, dynamic> orderSnapshot;
  final bool successHandled;
  final bool receiptPrinted;

  /// Cashier left this QR to take another sale. The customer display is clear
  /// until they reopen it from the search-bar shortcut.
  final bool heldForNewOrder;

  bool canReuseQrFor(int requestedOrderId, double requestedAmount) =>
      orderId == requestedOrderId &&
      !status.isTerminal &&
      DateTime.now().isBefore(expiresAt) &&
      qrData.trim().isNotEmpty &&
      (amount - requestedAmount).abs() < 0.005;

  PaymentSession copyWith({
    PaymentSessionStatus? status,
    bool? successHandled,
    bool? receiptPrinted,
    bool? heldForNewOrder,
  }) {
    return PaymentSession(
      paymentSessionId: paymentSessionId,
      orderId: orderId,
      orderNumber: orderNumber,
      transactionId: transactionId,
      amount: amount,
      qrData: qrData,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      orderSnapshot: orderSnapshot,
      successHandled: successHandled ?? this.successHandled,
      receiptPrinted: receiptPrinted ?? this.receiptPrinted,
      heldForNewOrder: heldForNewOrder ?? this.heldForNewOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'paymentSessionId': paymentSessionId,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'transactionId': transactionId,
        'amount': amount,
        'qrData': qrData,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'status': status.name,
        'orderSnapshot': orderSnapshot,
        'successHandled': successHandled,
        'receiptPrinted': receiptPrinted,
        'heldForNewOrder': heldForNewOrder,
      };

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      paymentSessionId: json['paymentSessionId'].toString(),
      orderId: (json['orderId'] as num).toInt(),
      orderNumber: json['orderNumber'].toString(),
      transactionId: json['transactionId']?.toString(),
      amount: (json['amount'] as num).toDouble(),
      qrData: json['qrData'].toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      expiresAt: DateTime.parse(json['expiresAt'].toString()),
      status: PaymentSessionStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => PaymentSessionStatus.failed,
      ),
      orderSnapshot: Map<String, dynamic>.from(
        json['orderSnapshot'] as Map? ?? const {},
      ),
      successHandled: json['successHandled'] == true,
      receiptPrinted: json['receiptPrinted'] == true,
      heldForNewOrder: json['heldForNewOrder'] == true,
    );
  }
}
