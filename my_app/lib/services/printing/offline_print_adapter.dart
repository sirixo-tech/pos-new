import '../../models/pos_models.dart';
import '../../models/receipt_print_models.dart';
import '../../utils/order_charges_calculator.dart';
import '../offline/pending_order.dart';

/// Builds venue + order DTOs for local template rendering from POS bootstrap.
class OfflinePrintAdapter {
  OfflinePrintAdapter._();

  static PrintVenueContext venueFromBootstrap(PosBootstrap bootstrap) {
    final restaurant = bootstrap.restaurant;
    return PrintVenueContext(
      restaurantName: restaurant.name,
      currencyCode: restaurant.defaultCurrency,
      branchName: bootstrap.branch.name,
      taxId: restaurant.taxId,
      logoUrl: restaurant.logoUrl,
      printLogoUrl: restaurant.printLogoUrl,
      branchAddress: bootstrap.branch.address,
    );
  }

  static OfflinePrintOrder orderFromPending({
    required PosBootstrap bootstrap,
    required PendingOrder order,
  }) {
    final lines = _resolveItems(bootstrap, order);
    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.total);
    final orderType = order.orderData['type'] as String? ?? 'dine_in';
    final totals = computeOrderTotalsPreview(
      subtotal: subtotal,
      cartLines: _cartLinesForTotals(bootstrap, order),
      orderType: orderType,
      orderTypeCharges: bootstrap.restaurant.orderTypeCharges,
      surchargeSettings: bootstrap.restaurant.orderTypeSurchargeSettings,
      serviceCharge: bootstrap.restaurant.serviceCharge,
      taxSettings: bootstrap.restaurant.taxSettings,
    );

    final payment =
        order.orderData['pos_register_payment'] as Map<String, dynamic>?;
    final paymentMethod = payment?['method'] as String?;
    final hasPayment = payment != null;

    return OfflinePrintOrder(
      // Local IDs are for syncing, not customer-facing bill numbers.
      orderNumber: order.serverOrderNumber ?? '',
      token: order.offlineToken,
      orderType: orderType,
      createdAt: order.createdAt,
      customerName: (order.orderData['customer_name'] as String?)?.trim(),
      notes: (order.orderData['notes'] as String?)?.trim(),
      tableName: _tableName(order),
      paymentStatus: hasPayment ? 'paid' : 'pending',
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      total: totals.total,
      taxBreakdown: [
        for (final tax in totals.taxComputation.breakdown)
          if (tax.amount > 0)
            OfflinePrintTaxLine(
              name: tax.name,
              rate: tax.rate,
              amount: tax.amount,
              included: tax.included,
            ),
      ],
      extraCharges: [
        for (final extra in totals.extraChargeLines)
          if (extra.amount > 0)
            OfflinePrintExtraCharge(label: extra.label, amount: extra.amount),
      ],
      serviceCharge: totals.serviceChargeAmount,
      serviceChargeLabel: bootstrap.restaurant.serviceCharge.label,
      items: [
        for (final item in lines)
          OfflinePrintItem(
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            total: item.total,
            variantName: item.variantName,
            modifiers: [
              for (final mod in item.modifiers)
                OfflinePrintModifier(
                  optionName: mod.optionName,
                  priceAdjustment: mod.priceAdjustment,
                ),
            ],
            kitchenId: item.kitchenId,
            kitchenName: item.kitchenName,
            kitchenCounterName: item.kitchenCounterName,
            notes: item.notes,
          ),
      ],
      isOffline: !order.isSynced,
    );
  }

  static String? _tableName(PendingOrder order) {
    final name = order.orderData['table_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final tableId = order.orderData['table_id'];
    if (tableId == null) return null;
    return 'Table $tableId';
  }

  static List<OfflinePrintItem> _resolveItems(
    PosBootstrap bootstrap,
    PendingOrder order,
  ) {
    final snapshot = order.orderData['cart_snapshot'];
    if (snapshot is List && snapshot.isNotEmpty) {
      return snapshot.whereType<Map>().map((raw) {
        final map = Map<String, dynamic>.from(raw);
        final qty = (map['quantity'] as num?)?.toInt() ?? 1;
        final unitPrice = _asDouble(map['unit_price']);
        final lineTotal = _asDouble(map['line_total'] ?? unitPrice * qty);
        final modifiers = (map['modifiers'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((mod) {
              final modMap = Map<String, dynamic>.from(mod);
              return OfflinePrintModifier(
                optionName:
                    modMap['name'] as String? ??
                    modMap['option_name'] as String? ??
                    'Option',
                priceAdjustment: _asDouble(modMap['price_adjustment']),
              );
            })
            .toList();

        return OfflinePrintItem(
          name: (map['name'] as String?)?.trim().isNotEmpty == true
              ? map['name'] as String
              : 'Item',
          variantName: map['variant_name'] as String?,
          quantity: qty,
          unitPrice: unitPrice,
          total: lineTotal,
          modifiers: modifiers,
          kitchenId: (map['kitchen_id'] as num?)?.toInt(),
          kitchenName: map['kitchen_name'] as String?,
          kitchenCounterName: map['kitchen_counter_name'] as String?,
          notes: map['notes'] as String?,
        );
      }).toList();
    }

    // Fallback: resolve from menu catalog when cart_snapshot is missing.
    final catalog = _MenuCatalog.fromBootstrap(bootstrap);
    final items = order.orderData['items'] as List<dynamic>? ?? [];
    return items.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final menuItemId = (map['menu_item_id'] as num?)?.toInt();
      final menuItem = menuItemId != null ? catalog.findItem(menuItemId) : null;
      final variantId = (map['variant_id'] as num?)?.toInt();
      final variant = variantId != null && menuItem != null
          ? catalog.findVariant(menuItem, variantId)
          : null;
      final qty = (map['quantity'] as num?)?.toInt() ?? 1;

      var unitPrice = menuItem?.baseUnitPrice(variant) ?? 0;
      final modifiers = <OfflinePrintModifier>[];
      for (final mod in map['modifiers'] as List<dynamic>? ?? []) {
        if (mod is! Map) continue;
        final modMap = Map<String, dynamic>.from(mod);
        final optionId = (modMap['modifier_option_id'] as num?)?.toInt();
        final option = optionId != null && menuItem != null
            ? catalog.findModifierOption(menuItem, optionId)
            : null;
        if (option != null) {
          unitPrice += option.priceAdjustment;
          modifiers.add(
            OfflinePrintModifier(
              optionName: option.name,
              priceAdjustment: option.priceAdjustment,
            ),
          );
        }
      }

      final name = variant != null && menuItem != null
          ? '${menuItem.name} (${variant.name})'
          : menuItem?.name ??
                (menuItemId != null ? 'Item #$menuItemId' : 'Item');

      return OfflinePrintItem(
        name: name,
        quantity: qty,
        unitPrice: unitPrice,
        total: unitPrice * qty,
        modifiers: modifiers,
        notes: map['notes'] as String?,
      );
    }).toList();
  }

  static List<Map<String, dynamic>> _cartLinesForTotals(
    PosBootstrap bootstrap,
    PendingOrder order,
  ) {
    final catalog = _MenuCatalog.fromBootstrap(bootstrap);
    final snapshot = order.orderData['cart_snapshot'];
    if (snapshot is List && snapshot.isNotEmpty) {
      return snapshot.whereType<Map>().map((raw) {
        final map = Map<String, dynamic>.from(raw);
        final menuItemId = (map['menu_item_id'] as num?)?.toInt() ?? 0;
        return {
          'menu_item_id': menuItemId,
          'quantity': map['quantity'] ?? 1,
          'order_type_surcharges':
              catalog.findItem(menuItemId)?.orderTypeSurcharges ??
              const <String, dynamic>{},
        };
      }).toList();
    }

    return (order.orderData['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((raw) {
          final map = Map<String, dynamic>.from(raw);
          final menuItemId = (map['menu_item_id'] as num?)?.toInt() ?? 0;
          return {
            'menu_item_id': menuItemId,
            'quantity': map['quantity'] ?? 1,
            'order_type_surcharges':
                catalog.findItem(menuItemId)?.orderTypeSurcharges ??
                const <String, dynamic>{},
          };
        })
        .toList();
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class _MenuCatalog {
  _MenuCatalog(this._items);

  final Map<int, MenuItem> _items;

  factory _MenuCatalog.fromBootstrap(PosBootstrap bootstrap) {
    final items = <int, MenuItem>{};
    for (final category in bootstrap.categories) {
      for (final item in category.items) {
        items[item.id] = item;
      }
    }
    for (final item in bootstrap.popularItems) {
      items[item.id] = item;
    }
    return _MenuCatalog(items);
  }

  MenuItem? findItem(int id) => _items[id];

  MenuVariant? findVariant(MenuItem item, int variantId) {
    for (final variant in item.variants) {
      if (variant.id == variantId) return variant;
    }
    return null;
  }

  ModifierOption? findModifierOption(MenuItem item, int optionId) {
    for (final modifier in item.modifiers) {
      for (final option in modifier.options) {
        if (option.id == optionId) return option;
      }
    }
    return null;
  }
}
