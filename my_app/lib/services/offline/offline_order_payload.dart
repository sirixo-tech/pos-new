import '../../models/pos_models.dart';

/// Builds the JSON map stored in `pending_orders.order_data` (before UUID key).
Map<String, dynamic> buildOfflineOrderPayload({
  required List<CartLine> cart,
  required String orderType,
  required Map<String, dynamic> payment,
  int? posTerminalId,
  int? tableId,
  int? customerId,
  String? customerName,
  String? notes,
  Map<String, dynamic>? discount,
}) {
  return {
    'items': cart.map((line) => line.toOrderJson()).toList(),
    'cart_snapshot': cart
        .map(
          (line) => {
            'menu_item_id': line.menuItem.id,
            'name': line.displayName,
            'quantity': line.quantity,
            'unit_price': line.unitPrice,
            'line_total': line.lineTotal,
            if (line.notes != null && line.notes!.isNotEmpty) 'notes': line.notes,
            if (line.selectedModifiers.isNotEmpty)
              'modifiers': line.selectedModifiers
                  .map(
                    (option) => {
                      'modifier_option_id': option.id,
                      'name': option.name,
                      'price_adjustment': option.priceAdjustment,
                    },
                  )
                  .toList(),
          },
        )
        .toList(),
    'type': orderType,
    if (posTerminalId != null) 'pos_terminal_id': posTerminalId,
    if (tableId != null) 'table_id': tableId,
    if (customerId != null) 'customer_id': customerId,
    if (customerName != null && customerName.isNotEmpty)
      'customer_name': customerName,
    if (notes != null && notes.isNotEmpty) 'notes': notes,
    if (discount != null) 'discount': discount,
    'pos_register_payment': payment,
  };
}

/// Resume-cart rows matching server `fetchOrderForResume` cart shape.
List<Map<String, dynamic>> cartRowsForHeldResume(List<CartLine> cart) {
  return cart
      .map(
        (line) => {
          'menu_item_id': line.menuItem.id,
          'menu_item_name': line.menuItem.name,
          if (line.variant != null) 'variant_id': line.variant!.id,
          'unit_price': line.unitPrice,
          'quantity': line.quantity,
          if (line.notes != null && line.notes!.isNotEmpty) 'notes': line.notes,
          if (line.selectedModifiers.isNotEmpty)
            'modifiers': line.selectedModifiers
                .map(
                  (option) => {
                    'modifier_option_id': option.id,
                    'option_name': option.name,
                    'price_adjustment': option.priceAdjustment,
                  },
                )
                .toList(),
        },
      )
      .toList();
}
