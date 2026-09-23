/// Branch feeds can announce a POS order before its QR payment completes.
bool canAutomaticallyFulfillOrder(
  Map<String, dynamic> raw, {
  String source = '',
}) {
  final nested = raw['order'];
  final order = nested is Map ? Map<String, dynamic>.from(nested) : raw;
  final status =
      '${order['status'] ?? order['order_status'] ?? ''}'.toLowerCase();
  if (const ['cancelled', 'canceled', 'failed', 'expired', 'void']
      .contains(status)) {
    return false;
  }

  final payment = '${order['payment_status'] ?? raw['payment_status'] ?? ''}'
      .toLowerCase()
      .trim();
  final origin =
      '${order['source'] ?? order['order_source'] ?? source}'.toLowerCase();
  if (origin == 'pos') {
    return const [
      'paid',
      'success',
      'successful',
      'completed',
      'captured',
      'settled',
    ].contains(payment);
  }
  return !const ['failed', 'failure', 'cancelled', 'canceled', 'expired']
      .contains(payment);
}
