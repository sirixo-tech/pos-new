import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../providers/pos_controller.dart';
import '../../services/pos_api.dart';
import '../../theme/pos_theme.dart';
import '../../utils/format.dart';
import '../../utils/json_parse.dart';
import '../../utils/tax_calculator.dart';
import '../../widgets/pos_ui.dart';

enum _BillRequestMode { full, items, equal }

Future<void> showBillPreviewSheet(
  BuildContext context, {
  required int tableId,
  required String tableName,
  Map<String, dynamic>? order,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => _BillPreviewDialog(
      tableId: tableId,
      tableName: tableName,
      order: order,
    ),
  );
}

class _BillPreviewDialog extends StatefulWidget {
  const _BillPreviewDialog({
    required this.tableId,
    required this.tableName,
    required this.order,
  });

  final int tableId;
  final String tableName;
  final Map<String, dynamic>? order;

  @override
  State<_BillPreviewDialog> createState() => _BillPreviewDialogState();
}

class _BillPreviewDialogState extends State<_BillPreviewDialog> {
  bool _busy = false;
  _BillRequestMode _mode = _BillRequestMode.full;
  final Set<int> _selectedItemIds = {};
  int _parts = 2;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _requestBill() async {
    final pos = context.read<PosController>();
    final l10n = context.l10n;

    if (_mode == _BillRequestMode.items && _selectedItemIds.isEmpty) {
      showPosSnackBar(
        context,
        l10n.waiterBillSplitSelectItemsRequired,
        error: true,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await pos.requestBillForTable(
        widget.tableId,
        mode: switch (_mode) {
          _BillRequestMode.full => 'full',
          _BillRequestMode.items => 'items',
          _BillRequestMode.equal => 'equal',
        },
        orderItemIds: _mode == _BillRequestMode.items
            ? _selectedItemIds.toList()
            : null,
        parts: _mode == _BillRequestMode.equal ? _parts : null,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      showPosSnackBar(context, l10n.waiterBillRequestedToast);
      Navigator.pop(context);
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearBill() async {
    final pos = context.read<PosController>();
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await pos.clearBillRequest(widget.tableId);
      if (!mounted) return;
      showPosSnackBar(context, l10n.waiterTableActionClearBillDone);
      Navigator.pop(context);
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final currency = pos.currency;
    final order = widget.order;
    final billRequested = order?['bill_requested'] == true ||
        pos.billRequestedTableIds.contains(widget.tableId);
    final billRequest = order?['bill_request'] is Map
        ? Map<String, dynamic>.from(order!['bill_request'] as Map)
        : null;

    final subtotalInclusive = parseJsonDouble(order?['subtotal']);
    final total = parseJsonDouble(order?['total']);
    final amountDue = order?['amount_due'] != null
        ? parseJsonDouble(order!['amount_due'])
        : total;
    final includedRate = includedTaxRateSumFromMaps(
      (order?['tax_breakdown'] as List?) ?? const [],
    );
    final subtotal = exclusiveAmount(subtotalInclusive, includedRate);
    final discountInclusive = (subtotalInclusive > 0 && total < subtotalInclusive)
        ? (subtotalInclusive - total).clamp(0.0, double.infinity)
        : 0.0;
    final discount = exclusiveAmount(discountInclusive, includedRate);
    final tax = parseJsonDouble(order?['tax']);
    final items = (order?['items'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final orderLabel = order?['order_number']?.toString() ??
        (order?['token'] != null
            ? l10n.waiterOrdersToken('${order!['token']}')
            : l10n.waiterBillNoTicket);

    final selectedTotal = items
        .where((i) => _selectedItemIds.contains(parseJsonIntOrNull(i['id'])))
        .fold<double>(0, (sum, i) => sum + parseJsonDouble(i['line_total']));
    final equalEach = _parts > 0 ? (amountDue > 0 ? amountDue : total) / _parts : 0.0;

    return PosDialogShell(
      title: l10n.waiterBillTitle(widget.tableName),
      subtitle: orderLabel,
      icon: Icons.receipt_long_rounded,
      headerColor:
          billRequested ? const Color(0xFFD97706) : PosTheme.accent,
      maxWidth: 440,
      onClose: _busy ? null : () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (billRequested) ...[
            Builder(
              builder: (context) {
                final soft = posAccentSoft(const Color(0xFFD97706));
                return Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: soft.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: soft.fg.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.request_quote_outlined,
                    size: 18,
                    color: soft.fg,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      billRequest?['is_split'] == true
                          ? _splitHint(l10n, billRequest!, currency)
                          : l10n.waiterBillAlreadyRequestedHint,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: soft.fg,
                      ),
                    ),
                  ),
                ],
              ),
            );
              },
            ),
            const SizedBox(height: 14),
          ] else if (items.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ModeChip(
                  label: l10n.waiterBillModeFull,
                  selected: _mode == _BillRequestMode.full,
                  onTap: () => setState(() => _mode = _BillRequestMode.full),
                ),
                _ModeChip(
                  label: l10n.waiterBillModeSplitItems,
                  selected: _mode == _BillRequestMode.items,
                  onTap: () => setState(() => _mode = _BillRequestMode.items),
                ),
                _ModeChip(
                  label: l10n.waiterBillModeSplitEqual,
                  selected: _mode == _BillRequestMode.equal,
                  onTap: () => setState(() => _mode = _BillRequestMode.equal),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (items.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final id = parseJsonIntOrNull(item['id']);
                  final qty = parseJsonInt(item['quantity'], fallback: 1);
                  final name = item['name']?.toString() ?? l10n.cartTable;
                  final lineTotal = parseJsonDouble(item['line_total']);
                  final selectable =
                      !billRequested && _mode == _BillRequestMode.items && id != null;
                  final selected = id != null && _selectedItemIds.contains(id);

                  return InkWell(
                    onTap: !selectable
                        ? null
                        : () {
                            setState(() {
                              if (selected) {
                                _selectedItemIds.remove(id);
                              } else {
                                _selectedItemIds.add(id);
                              }
                            });
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          if (selectable) ...[
                            Icon(
                              selected
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 22,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : PosTheme.inkMuted,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '$qty×',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(name)),
                          Text(
                            formatMoney(lineTotal, currency),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Text(
              l10n.waiterBillEmptyHint,
              style: TextStyle(color: PosTheme.inkMuted),
            ),
          if (!billRequested && _mode == _BillRequestMode.items) ...[
            const SizedBox(height: 10),
            Text(
              l10n.waiterBillSplitSelected(
                _selectedItemIds.length,
                formatMoney(selectedTotal, currency),
              ),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          if (!billRequested && _mode == _BillRequestMode.equal) ...[
            const SizedBox(height: 12),
            Text(
              l10n.waiterBillSplitParts,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _parts <= 2
                      ? null
                      : () => setState(() => _parts -= 1),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$_parts',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _parts >= 20
                      ? null
                      : () => setState(() => _parts += 1),
                  icon: const Icon(Icons.add_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.waiterBillSplitEqualPreview(
                      _parts,
                      formatMoney(equalEach, currency),
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!billRequested) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l10n.waiterBillSplitNote,
                hintText: l10n.waiterBillSplitNoteHint,
                filled: true,
                fillColor: PosTheme.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _TotalRow(
            label: l10n.commonSubtotal,
            value: formatMoney(subtotal, currency),
          ),
          if (discount > 0)
            _TotalRow(
              label: l10n.waiterBillDiscount,
              value: '- ${formatMoney(discount.toDouble(), currency)}',
            ),
          if (tax > 0)
            _TotalRow(
              label: l10n.waiterBillTax,
              value: formatMoney(tax, currency),
            ),
          const Divider(height: 20),
          _TotalRow(
            label: l10n.commonTotal,
            value: formatMoney(amountDue > 0 ? amountDue : total, currency),
            emphasize: true,
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (billRequested) ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(l10n.commonDone),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _clearBill,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo_rounded, size: 18),
              label: Text(l10n.waiterTableActionClearBill),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _requestBill,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _mode == _BillRequestMode.full
                          ? Icons.request_quote_rounded
                          : Icons.call_split_rounded,
                      size: 20,
                    ),
              label: Text(
                _mode == _BillRequestMode.full
                    ? l10n.waiterRequestBill
                    : l10n.waiterBillRequestSplit,
              ),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(l10n.commonClose),
            ),
          ],
        ],
      ),
    );
  }

  String _splitHint(
    AppLocalizations l10n,
    Map<String, dynamic> billRequest,
    String currency,
  ) {
    final mode = billRequest['mode']?.toString();
    final note = billRequest['note']?.toString();
    final base = switch (mode) {
      'equal' => l10n.registerSplitBillEqualHint(
          parseJsonInt(billRequest['parts'], fallback: 2),
        ),
      'items' => l10n.registerSplitBillItemsHint,
      _ => l10n.waiterBillAlreadyRequestedHint,
    };
    if (note != null && note.isNotEmpty) {
      return '$base · $note';
    }
    return base;
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    return Material(
      color: selected ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: selected ? soft.fg : PosTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
