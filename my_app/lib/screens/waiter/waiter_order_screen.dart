import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/pos_models.dart';
import '../../providers/pos_controller.dart';
import '../../screens/order_preview_screen.dart';
import '../../services/pos_api.dart';
import '../../theme/pos_theme.dart';
import '../../utils/json_parse.dart';
import '../../utils/outside_schedule.dart';
import '../../widgets/modifier_sheet.dart';
import '../../widgets/pos_appearance_picker.dart';
import '../../widgets/pos_register_workspace.dart';
import '../../widgets/pos_ui.dart';
import 'kot_sent_dialog.dart';

class WaiterOrderScreen extends StatefulWidget {
  const WaiterOrderScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<WaiterOrderScreen> createState() => _WaiterOrderScreenState();
}

class _WaiterOrderScreenState extends State<WaiterOrderScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  void _close() {
    final pos = context.read<PosController>();
    if (pos.searchQuery.isNotEmpty) {
      pos.setSearchQuery('');
    }
    widget.onClose();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _tapItem(MenuItem item) async {
    final pos = context.read<PosController>();
    final existing = pos.simpleCartLineFor(item);
    if (existing == null) {
      final ok = await confirmOutsideScheduleIfNeeded(context, item);
      if (!ok || !mounted) return;
    }

    if (item.hasOptions) {
      await ModifierSheet.show(context, item);
      return;
    }

    if (existing != null) {
      pos.incrementSimpleCartLine(existing);
    } else {
      pos.addToCart(CartLine(menuItem: item, quantity: 1));
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _sendKot() async {
    final pos = context.read<PosController>();
    final l10n = context.l10n;
    if (pos.cart.isEmpty || pos.submitting) return;
    if (pos.orderType == 'dine_in' && pos.tableId == null) {
      showPosSnackBar(context, l10n.cartSelectTable, error: true);
      return;
    }

    final tableLabel = _tableLabel(pos, l10n);
    final preview = await OrderPreviewScreen.open(
      context,
      data: OrderPreviewData.fromController(pos),
      forWaiter: true,
    );
    if (!mounted) return;
    switch (preview) {
      case null:
      case OrderPreviewResult.editOrder:
        return;
      case OrderPreviewResult.cancelOrder:
        pos.clearCart();
        return;
      case OrderPreviewResult.saveOrder:
        try {
          final order = await pos.parkCurrentTicket();
          if (!mounted) return;
          showPosSnackBar(context, l10n.cartHeldSnack(order.orderNumber));
          _close();
        } on PosApiException catch (e) {
          if (mounted) showPosErrorSnackBar(context, e);
        }
        return;
      case OrderPreviewResult.printBill:
      case OrderPreviewResult.sentToKitchen:
        break;
    }

    try {
      final order = await pos.sendWaiterKot();
      if (!mounted) return;
      unawaited(pos.refreshWaiterFloor());
      await showKotSentDialog(
        context,
        orderNumber: order.orderNumber,
        token: order.token,
        tableName: tableLabel,
      );
      if (!mounted) return;
      _close();
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final pos = context.watch<PosController>();
    final tableLabel = _tableLabel(pos, l10n);
    final itemCount = pos.cartItemCount;
    final sentCount = pos.waiterSentItemCount;
    final hasSent = pos.hasWaiterSentItems;

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      body: Column(
        children: [
          Material(
            color: PosTheme.surface,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: l10n.commonClose,
                          onPressed: _close,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: soft.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            Icons.table_restaurant_rounded,
                            color: soft.fg,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tableLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                [
                                  if (pos.waiterGuestCount != null)
                                    l10n.waiterGuestsCount(
                                      pos.waiterGuestCount!,
                                    ),
                                  if (pos.hasParkedTicket)
                                    pos.parkedOrderLabel ??
                                        l10n.ordersHeldTab,
                                  if (hasSent)
                                    l10n.waiterAlreadySent(sentCount)
                                  else
                                    l10n.waiterOrderTitle,
                                ].whereType<String>().join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PosTheme.inkMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (itemCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+$itemCount',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                        PosAppBarThemeButton(accent: accent),
                      ],
                    ),
                  ),
                  if (hasSent)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: PosTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PosTheme.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: PosTheme.inkMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${l10n.waiterAlreadySent(sentCount)}\n${l10n.waiterNewItemsHint}',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: PosTheme.inkMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Divider(height: 1, color: PosTheme.border),
                ],
              ),
            ),
          ),
          Expanded(
            child: PosRegisterWorkspace(
              searchController: _searchController,
              searchFocus: _searchFocus,
              onItemTap: _tapItem,
              onPay: _sendKot,
              primaryLabel: l10n.waiterSendToKitchen,
              primaryIcon: Icons.soup_kitchen_outlined,
              primaryColor: const Color(0xFF10B981),
              lockServiceContext: true,
            ),
          ),
        ],
      ),
    );
  }

  String _tableLabel(PosController pos, AppLocalizations l10n) {
    final id = pos.tableId;
    if (id == null) return l10n.waiterOrderTitle;
    for (final t in pos.waiterTables) {
      if (parseJsonIntOrNull(t['id']) == id) {
        return t['name']?.toString() ?? l10n.cartTableNamed('$id');
      }
    }
    return l10n.cartTableNamed('$id');
  }
}
