import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../screens/admin/admin_orders_screen.dart';

/// Opens the Manage → Orders detail modal from register / waiter flows.
class PosOrderDetailSheet {
  PosOrderDetailSheet._();

  static Future<Map<String, dynamic>?> open(
    BuildContext context, {
    Map<String, dynamic>? order,
    int? orderId,
    ValueChanged<Map<String, dynamic>>? onOrderChanged,
    bool readOnly = false,
  }) async {
    assert(
      order != null || orderId != null,
      'PosOrderDetailSheet.open requires order or orderId',
    );

    final id = orderId ??
        (order?['id'] is num
            ? (order!['id'] as num).toInt()
            : int.tryParse('${order?['id'] ?? ''}'));
    if (id == null) return null;

    AdminOrderSummary? summary;
    if (order != null) {
      try {
        summary = AdminOrderSummary.fromJson(Map<String, dynamic>.from(order));
      } catch (_) {
        summary = AdminOrderSummary.placeholder(
          id: id,
          orderNumber: order['order_number']?.toString(),
          status: order['status']?.toString(),
          paymentStatus: order['payment_status']?.toString(),
          total: (order['total'] as num?)?.toDouble(),
          token: order['token']?.toString(),
          customerName: order['customer_name']?.toString(),
          tableName: order['table_name']?.toString() ??
              (order['table'] is Map
                  ? (order['table'] as Map)['name']?.toString()
                  : null),
          type: order['type']?.toString(),
          source: order['source']?.toString(),
        );
      }
    }

    final result = await AdminOrderDetailSheet.open(
      context,
      orderId: id,
      summary: summary,
      order: order,
      readOnly: readOnly,
    );
    if (result != null) {
      onOrderChanged?.call(result);
    }
    return result;
  }
}
