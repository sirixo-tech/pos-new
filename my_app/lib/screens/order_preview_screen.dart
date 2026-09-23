import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../widgets/pos_ui.dart';

enum OrderPreviewResult {
  sentToKitchen,
  printBill,
  saveOrder,
  cancelOrder,
  editOrder,
}

class OrderPreviewItem {
  const OrderPreviewItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.notes,
    this.modifiers = const [],
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final String? notes;
  final List<String> modifiers;

  double get lineTotal => unitPrice * quantity;
}

class OrderPreviewData {
  const OrderPreviewData({
    required this.currency,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.items,
    this.orderNumber,
    this.tableName,
    this.customerName,
    this.tokenNumber,
    this.orderType,
    this.notes,
  });

  final String currency;
  final double subtotal;
  final double discount;
  final double total;
  final List<OrderPreviewItem> items;
  final String? orderNumber;
  final String? tableName;
  final String? customerName;
  final String? tokenNumber;
  final String? orderType;
  final String? notes;

  factory OrderPreviewData.fromController(PosController pos) {
    String? tableName;
    final tableId = pos.tableId;
    if (tableId != null) {
      for (final table in pos.waiterTables) {
        if (table['id'] == tableId || '${table['id']}' == '$tableId') {
          tableName = table['name']?.toString();
          break;
        }
      }
      tableName ??= 'Table $tableId';
    }
    return OrderPreviewData(
      currency: pos.currency,
      subtotal: pos.cartSubtotal,
      discount: pos.discountAmount,
      total: pos.cartTotal,
      orderNumber: pos.parkedOrderLabel,
      tableName: tableName,
      customerName: pos.customerName,
      orderType: pos.orderType,
      notes: pos.orderNotes,
      items: pos.cart
          .map(
            (line) => OrderPreviewItem(
              name: line.displayName,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
              notes: line.notes,
              modifiers: line.selectedModifiers.map((m) => m.name).toList(),
            ),
          )
          .toList(),
    );
  }
}

class OrderPreviewScreen extends StatelessWidget {
  const OrderPreviewScreen({
    super.key,
    required this.data,
    this.forWaiter = false,
  });

  final OrderPreviewData data;
  final bool forWaiter;

  static Future<OrderPreviewResult?> open(
    BuildContext context, {
    required OrderPreviewData data,
    bool forWaiter = false,
  }) {
    return Navigator.of(context).push<OrderPreviewResult>(
      MaterialPageRoute(
        builder: (_) => OrderPreviewScreen(data: data, forWaiter: forWaiter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    String money(double value) => formatMoney(value, data.currency);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        title: const Text('Review order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              Navigator.pop(context, OrderPreviewResult.editOrder),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 720 : double.infinity),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _MetaCard(data: data, soft: soft),
                    const SizedBox(height: 12),
                    for (final item in data.items)
                      _ItemTile(item: item, money: money, accent: accent),
                    const SizedBox(height: 12),
                    _TotalsCard(data: data, money: money, l10n: l10n),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: BoxDecoration(
                    color: PosTheme.surface,
                    border: Border(
                      top: BorderSide(color: PosTheme.border),
                    ),
                    boxShadow: PosTheme.cardShadow(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PosPrimaryButton(
                        label: forWaiter
                            ? l10n.waiterSendToKitchen
                            : l10n.cartPay,
                        icon: forWaiter
                            ? Icons.soup_kitchen_outlined
                            : Icons.payments_rounded,
                        color: forWaiter ? accent : PosTheme.payAccent,
                        onPressed: () => Navigator.pop(
                          context,
                          forWaiter
                              ? OrderPreviewResult.sentToKitchen
                              : OrderPreviewResult.printBill,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (!forWaiter)
                            Expanded(
                              child: _GhostAction(
                                icon: Icons.soup_kitchen_outlined,
                                label: l10n.waiterSendToKitchen,
                                onTap: () => Navigator.pop(
                                  context,
                                  OrderPreviewResult.sentToKitchen,
                                ),
                              ),
                            ),
                          if (!forWaiter) const SizedBox(width: 8),
                          Expanded(
                            child: _HoldAction(
                              label: l10n.cartHold,
                              onTap: () => Navigator.pop(
                                context,
                                OrderPreviewResult.saveOrder,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () async {
                          final ok = await showPosConfirmDialog(
                            context,
                            title: l10n.cartClearTitle,
                            message: l10n.cartClearMessage,
                            confirmLabel: l10n.cartClear,
                            destructive: true,
                          );
                          if (!context.mounted) return;
                          if (ok) {
                            Navigator.pop(
                              context,
                              OrderPreviewResult.cancelOrder,
                            );
                          }
                        },
                        child: Text(
                          l10n.cartClear,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldAction extends StatelessWidget {
  const _HoldAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(PosTheme.holdAmberDark);
    return Material(
      color: soft.bg,
      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusMd),
            border: Border.all(
              color: soft.fg.withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pause_rounded, size: 18, color: soft.fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: soft.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: PosTheme.ink,
        side: BorderSide(color: PosTheme.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.data,
    required this.soft,
  });

  final OrderPreviewData data;
  final ({Color bg, Color fg}) soft;

  @override
  Widget build(BuildContext context) {
    final bits = <String>[
      if ((data.orderNumber ?? '').isNotEmpty) data.orderNumber!,
      if ((data.tableName ?? '').isNotEmpty) data.tableName!,
      if ((data.customerName ?? '').isNotEmpty) data.customerName!,
      if ((data.orderType ?? '').isNotEmpty)
        data.orderType!.replaceAll('_', ' '),
    ];
    return PosSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: soft.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded, color: soft.fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bits.isEmpty ? 'Current ticket' : bits.join(' · '),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                    color: PosTheme.ink,
                  ),
                ),
                if ((data.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    data.notes!.trim(),
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.money,
    required this.accent,
  });

  final OrderPreviewItem item;
  final String Function(double) money;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PosSurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: soft.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.quantity}×',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: soft.fg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: PosTheme.ink,
                    ),
                  ),
                  if (item.modifiers.isNotEmpty)
                    Text(
                      item.modifiers.join(', '),
                      style: TextStyle(
                        color: PosTheme.inkMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if ((item.notes ?? '').trim().isNotEmpty)
                    Text(
                      item.notes!.trim(),
                      style: TextStyle(
                        color: PosTheme.inkMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              money(item.lineTotal),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: PosTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.data,
    required this.money,
    required this.l10n,
  });

  final OrderPreviewData data;
  final String Function(double) money;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PosSurfaceCard(
      padding: const EdgeInsets.all(16),
      accentBorder: true,
      child: Column(
        children: [
          _row(l10n.commonSubtotal, money(data.subtotal)),
          if (data.discount > 0.001)
            _row(l10n.discountLabel, '-${money(data.discount)}'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: PosTheme.border),
          ),
          _row(l10n.commonTotal, money(data.total), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                fontSize: bold ? 16 : 14,
                color: bold ? PosTheme.ink : PosTheme.inkMuted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14.5,
              color: PosTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}
