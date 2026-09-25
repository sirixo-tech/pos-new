import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../services/pos_api.dart';
import '../services/printing/pos_receipt_printer.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/marketplace_platform_ui.dart';
import '../utils/order_cancel_reasons.dart';
import '../utils/pos_user_facing_error.dart';
import '../widgets/cash_register_sheet.dart';
import '../widgets/collect_payment_sheet.dart';
import '../widgets/pos_overlay.dart';
import '../widgets/pos_payment_qr_sheet.dart';
import '../widgets/pos_ui.dart';
import '../widgets/pos_order_detail_sheet.dart';
import 'kitchen/kitchen_theme.dart';

/// In-POS orders browser: held tickets + branch activity.
class PosOrdersSheet extends StatefulWidget {
  const PosOrdersSheet({
    super.key,
    this.initialTab = 'held',
    this.initialFilter = 'today',
    this.asSidePanel = false,
    this.deliveryOnly = false,
  });

  /// `held`, `orders`, or `cancelled`
  final String initialTab;

  /// Recent-orders filter: today / unpaid / floor / all / marketplace provider
  final String initialFilter;

  /// Wide desktop presentation (no drag handle / full-height panel).
  final bool asSidePanel;

  /// Restrict the Orders tab to marketplace / delivery tickets.
  final bool deliveryOnly;

  static Future<void> open(
    BuildContext context, {
    String initialTab = 'held',
    String initialFilter = 'today',
    bool deliveryOnly = false,
  }) {
    final side = preferPosSidePanel(context);
    return showPosOverlay<void>(
      context: context,
      sidePanelWidth: 520,
      builder: (_) => PosOrdersSheet(
        initialTab: initialTab,
        initialFilter: initialFilter,
        asSidePanel: side,
        deliveryOnly: deliveryOnly,
      ),
    );
  }

  @override
  State<PosOrdersSheet> createState() => _PosOrdersSheetState();
}

class _PosOrdersSheetState extends State<PosOrdersSheet> {
  late String _tab;
  late String _filter;
  String? _statusFilter;
  String? _sourceFilter;
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  int _page = 1;
  List<Map<String, dynamic>> _orders = const [];
  Map<String, dynamic> _meta = const {
    'current_page': 1,
    'last_page': 1,
    'total': 0,
    'from': 0,
    'to': 0,
  };
  Object? _resumingKey;
  int _heldCount = 0;

  bool get _isHeldTab => _tab == 'held';
  bool get _isCancelledTab => _tab == 'cancelled';

  static const _coreFilters = {'today', 'unpaid', 'floor', 'all'};

  bool _isAllowedFilter(String filter) {
    if (_coreFilters.contains(filter)) return true;
    return context.read<PosController>().bootstrap?.marketplaceEnabled(filter) ??
        false;
  }

  bool _isMarketplaceDeliveryOrder(Map<String, dynamic> order) {
    final source = '${order['source'] ?? order['channel'] ?? ''}'
        .trim()
        .toLowerCase();
    final type = '${order['order_type'] ?? order['type'] ?? ''}'
        .trim()
        .toLowerCase();
    if (type == 'delivery') return true;
    if (source == 'delivery' || source == 'swiggy' || source == 'zomato') {
      return true;
    }
    final platforms = context.read<PosController>().bootstrap?.marketplacePlatforms ??
        const <MarketplacePlatformInfo>[];
    return platforms.any((platform) => platform.provider.toLowerCase() == source);
  }

  @override
  void initState() {
    super.initState();
    if (widget.deliveryOnly) {
      _tab = 'orders';
      _filter = 'today';
    } else if (widget.initialTab == 'orders' || widget.initialTab == 'cancelled') {
      _tab = widget.initialTab;
    } else {
      _tab = 'held';
    }
    if (_coreFilters.contains(widget.initialFilter)) {
      _filter = widget.initialFilter;
    } else if (_isAllowedFilter(widget.initialFilter)) {
      _filter = 'today';
      _sourceFilter = widget.initialFilter;
    } else if (!widget.deliveryOnly) {
      _filter = 'today';
    }
    if (_isCancelledTab) {
      _statusFilter = 'cancelled';
    }
    _heldCount = context.read<PosController>().heldOrderCount;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;
    final nextPage = page ?? _page;

    setState(() {
      _loading = true;
      _error = null;
      _page = nextPage;
    });

    try {
      if (_isHeldTab) {
        final pos = context.read<PosController>();
        final orders = await pos.fetchHeldOrders();
        if (!mounted) return;
        setState(() {
          _orders = orders;
          _heldCount = orders.length;
          _meta = const {
            'current_page': 1,
            'last_page': 1,
            'total': 0,
            'from': 0,
            'to': 0,
          };
          _loading = false;
        });
        return;
      }

      final data = await PosApi().fetchRecentOrders(
        session,
        filter: _filter,
        query: _search.text,
        status: _isCancelledTab ? 'cancelled' : _statusFilter,
        source: widget.deliveryOnly ? null : _sourceFilter,
        page: nextPage,
      );
      if (!mounted) return;
      var orders = (data['orders'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [];
      if (widget.deliveryOnly) {
        orders = orders.where(_isMarketplaceDeliveryOrder).toList();
      }
      orders = orders.where((order) {
        final status = '${order['status'] ?? ''}'.toLowerCase();
        final hasIdentity = order['id'] != null ||
            '${order['order_number'] ?? ''}'.trim().isNotEmpty;
        if (!hasIdentity) return false;
        if (_isCancelledTab) return status == 'cancelled';
        return status != 'cancelled';
      }).toList();
      setState(() {
        _orders = orders;
        _meta = Map<String, dynamic>.from(
          data['meta'] as Map? ??
              const {
                'current_page': 1,
                'last_page': 1,
                'total': 0,
                'from': 0,
                'to': 0,
              },
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = posUserFacingError(e);
        _loading = false;
      });
    }
  }

  Future<void> _resume(Map<String, dynamic> order) async {
    final localUuid = order['local_uuid'] as String?;
    final isLocal = order['is_local'] == true ||
        (localUuid != null && localUuid.isNotEmpty);
    final id = order['id'];
    final orderId = (id is int || id is num) ? (id as num).toInt() : null;
    if (!isLocal && orderId == null) return;

    final pos = context.read<PosController>();
    final l10n = context.l10n;
    if (pos.cart.isNotEmpty || pos.hasParkedTicket) {
      final ok = await showPosConfirmDialog(
        context,
        title: l10n.cartReplaceTitle,
        message: l10n.cartReplaceMessage,
        confirmLabel: l10n.cartResume,
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final key = isLocal ? 'local:$localUuid' : 'server:$orderId';
    setState(() => _resumingKey = key);
    try {
      await pos.resumeHeldOrder(
        orderId: isLocal ? null : orderId,
        localUuid: isLocal ? localUuid : null,
      );
      if (!mounted) return;
      final label = pos.parkedOrderLabel ?? context.l10n.ordersHeldTicket;
      Navigator.of(context).maybePop();
      showPosSnackBar(context, context.l10n.ordersLoaded(label));
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _resumingKey = null);
    }
  }

  String _money(dynamic value, String currency) {
    final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return formatMoney(n, currency);
  }

  Future<void> _openOrderDetails(Map<String, dynamic> order) async {
    final id = order['id'];
    final orderId = (id is num) ? id.toInt() : null;
    final updated = await PosOrderDetailSheet.open(
      context,
      order: order,
      orderId: orderId,
      onOrderChanged: (fresh) {
        if (!mounted) return;
        setState(() {
          _orders = [
            for (final o in _orders)
              if (o['id'] == fresh['id']) fresh else o,
          ];
        });
      },
    );
    if (!mounted || updated == null) return;
    setState(() {
      _orders = [
        for (final o in _orders)
          if (o['id'] == updated['id']) updated else o,
      ];
    });
  }

  String? _nextAdvance(Map<String, dynamic> order) {
    const flow = {
      'pending': 'confirmed',
      'confirmed': 'preparing',
      'preparing': 'ready',
      'ready': 'delivered',
    };
    final status = '${order['status'] ?? ''}';
    final next = flow[status];
    final allowed =
        (order['next_statuses'] as List?)?.map((e) => '$e').toList() ?? [];
    if (next != null && allowed.contains(next)) return next;
    return null;
  }

  String _advanceLabel(String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'confirmed':
        return l10n.ordersAdvanceAccept;
      case 'preparing':
        return l10n.ordersAdvanceKitchen;
      case 'ready':
        return l10n.ordersAdvanceReady;
      case 'delivered':
        return l10n.ordersAdvanceDone;
      default:
        return status;
    }
  }

  Future<void> _setStatus(
    Map<String, dynamic> order,
    String status, {
    bool refund = false,
    String? cancelReason,
    String? cancelNote,
  }) async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;
    final id = order['id'];
    if (id is! int && id is! num) return;

    try {
      final data = await PosApi().updateOrderStatus(
        session,
        orderId: (id as num).toInt(),
        status: status,
        refund: refund,
        cancelReason: cancelReason,
        cancelNote: cancelNote,
      );
      final updated = data['order'];
      if (!mounted || updated is! Map) return;
      setState(() {
        _orders = [
          for (final o in _orders)
            if (o['id'] == updated['id'])
              Map<String, dynamic>.from(updated)
            else
              o,
        ];
      });
      if (mounted) {
        final l10n = context.l10n;
        final message = status == 'cancelled'
            ? (refund ? l10n.ordersCancelledRefunded : l10n.ordersCancelled)
            : l10n.ordersUpdated;
        showPosSnackBar(context, message);
      }
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _confirmCancel(Map<String, dynamic> order) async {
    final paymentStatus = '${order['payment_status'] ?? ''}';
    final canRefund =
        paymentStatus == 'paid' || paymentStatus == 'partial';
    final currency = context.read<PosController>().currency;
    final amount = order['total'];
    final amountLabel = canRefund ? _money(amount, currency) : null;

    final result = await showPosCancelOrderDialog(
      context,
      canRefund: canRefund,
      amountLabel: amountLabel,
    );
    if (!mounted || result == null) return;

    await _setStatus(
      order,
      'cancelled',
      refund: result.choice == PosCancelOrderChoice.cancelAndRefund,
      cancelReason: result.cancelReason,
      cancelNote: result.cancelNote,
    );
  }

  Future<void> _confirmClearHeld(Map<String, dynamic> order) async {
    final ok = await showPosConfirmDialog(
      context,
      title: context.posText(
        'ordersClearHeldTitle',
        'Clear this held ticket?',
      ),
      message: context.posText(
        'ordersClearHeldDescription',
        'This removes the parked draft from the held list. It won’t be sent to the kitchen.',
      ),
      confirmLabel: context.posText(
        'ordersClearHeldConfirm',
        'Clear held ticket',
      ),
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!mounted || !ok) return;

    final localUuid = order['local_uuid'] as String?;
    final isLocal = order['is_local'] == true ||
        (localUuid != null && localUuid.isNotEmpty);
    final id = order['id'];
    final orderId = (id is int || id is num) ? (id as num).toInt() : null;

    try {
      await context.read<PosController>().discardHeldOrder(
            orderId: isLocal ? null : orderId,
            localUuid: isLocal ? localUuid : null,
          );
      if (!mounted) return;
      setState(() {
        _orders = [
          for (final o in _orders)
            if (isLocal
                ? o['local_uuid'] != localUuid
                : o['id'] != orderId)
              o,
        ];
        _heldCount = _orders.length;
      });
      showPosSnackBar(
        context,
        context.posText('ordersClearHeldDone', 'Held ticket cleared'),
      );
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _printOrder(Map<String, dynamic> order) async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;

    final orderNumber = '${order['order_number'] ?? ''}'.trim();
    if (orderNumber.isEmpty) {
      showPosSnackBar(context, context.l10n.ordersNumberMissing, error: true);
      return;
    }

    if (!PosReceiptPrinter.isSupported) {
      showPosSnackBar(
        context,
        PosReceiptPrinter.unsupportedMessage,
        error: true,
      );
      return;
    }

    try {
      await PosReceiptPrinter.printOrderByNumber(
        session: session,
        orderNumber: orderNumber,
      );
      if (!mounted) return;
      showPosSnackBar(context, context.l10n.printPrinted(orderNumber));
    } on PosApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        showPosSnackBar(
          context,
          context.l10n.printOrderNotFound(orderNumber),
          error: true,
        );
      } else {
        showPosErrorSnackBar(context, e);
      }
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _printKot(Map<String, dynamic> order) async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;

    final orderNumber = '${order['order_number'] ?? ''}'.trim();
    if (orderNumber.isEmpty) {
      showPosSnackBar(context, context.l10n.ordersNumberMissing, error: true);
      return;
    }

    if (!PosReceiptPrinter.isSupported) {
      showPosSnackBar(
        context,
        PosReceiptPrinter.unsupportedMessage,
        error: true,
      );
      return;
    }

    try {
      await PosReceiptPrinter.printKotByOrderNumber(
        session: session,
        orderNumber: orderNumber,
      );
      if (!mounted) return;
      showPosSnackBar(context, context.l10n.printKotPrinted(orderNumber));
    } on PosApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        showPosSnackBar(
          context,
          context.l10n.printOrderNotFound(orderNumber),
          error: true,
        );
      } else {
        showPosErrorSnackBar(context, e);
      }
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  String _orderLabel(Map<String, dynamic> order) {
    if (order['token'] != null) {
      return context.l10n.ordersTokenLabel('${order['token']}');
    }
    final number = '${order['order_number'] ?? ''}'.trim();
    if (number.isNotEmpty) return number;
    return '#${order['id']}';
  }

  String? _orderDetail(Map<String, dynamic> order) {
    final l10n = context.l10n;
    final itemCountRaw = order['item_count'];
    String? itemCountLabel;
    if (itemCountRaw != null) {
      final count = itemCountRaw is num
          ? itemCountRaw.toInt()
          : int.tryParse('$itemCountRaw') ?? 0;
      itemCountLabel = count == 1
          ? l10n.ordersItemCount(count)
          : l10n.ordersItemCountPlural(count);
    }
    final parts = <String>[
      if (order['table_name'] != null &&
          '${order['table_name']}'.trim().isNotEmpty)
        '${order['table_name']}'.trim(),
      if (order['customer_name'] != null &&
          '${order['customer_name']}'.trim().isNotEmpty)
        '${order['customer_name']}'.trim(),
      ?itemCountLabel,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Future<void> _collectPayment(Map<String, dynamic> order) async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;

    final localUuid = order['local_uuid'] as String?;
    final isLocal = order['is_local'] == true ||
        (localUuid != null && localUuid.isNotEmpty);
    final id = order['id'];
    final orderId = (id is int || id is num) ? (id as num).toInt() : null;
    if (!isLocal && orderId == null) return;

    final label = _orderLabel(order);
    final detail = _orderDetail(order);

    final due = (order['amount_due'] is num)
        ? (order['amount_due'] as num).toDouble()
        : double.tryParse('${order['amount_due'] ?? order['total']}') ?? 0;

    // Server-held tickets still need network; local held can settle offline.
    if (!isLocal && pos.isOffline) {
      if (!mounted) return;
      showPosSnackBar(
        context,
        context.l10n.offlineHeldPayBlocked,
        error: true,
      );
      return;
    }

    // Server tickets: unified Full amount / Split payments sheet.
    if (!isLocal) {
      final result = await CollectPaymentSheet.open(
        context,
        order: order,
        currency: pos.currency,
        tipSettings: pos.bootstrap?.restaurant.tips ?? const TipSettings(),
        paymentGateways: pos.bootstrap?.paymentGateways ?? const [],
        orderLabel: label,
        orderDetail: detail,
      );
      if (!mounted) return;

      if (result == true) {
        await _load();
        await pos.refreshHeldOrderCount();
        if (!mounted) return;
        showPosSnackBar(
          context,
          context.l10n.ordersPaymentRecorded(label),
        );
        return;
      }

      if (result is! PaymentSubmission) {
        await _load();
        await pos.refreshHeldOrderCount();
        return;
      }

      final payment = result;
      final isQrPayment =
          payment.method == 'phonepe' || payment.method == 'paytm';
      final paymentPayload = {
        'method': payment.method,
        if (payment.cashTendered != null) 'cash_tendered': payment.cashTendered,
        if (payment.tip != null && payment.tip! > 0) 'tip': payment.tip,
      };

      try {
        final data = await PosApi().payOrder(
          session,
          orderId: orderId!,
          payment: paymentPayload,
        );
        if (!mounted) return;

        final orderJson = data['order'] as Map<String, dynamic>?;
        if (orderJson == null) {
          throw PosApiException('Pay response missing order payload.');
        }
        final paymentBody = data['payment'];
        final placed = PlacedPosOrder.fromJson({
          ...orderJson,
          if (paymentBody is Map<String, dynamic>) 'payment': paymentBody,
        });
        pos.registerSelfPlacedOrder(placed.id);

        if (isQrPayment && placed.id > 0 && pos.serverUrl != null) {
          final qrClose = await PosPaymentQrSheet.show(
            context,
            order: placed,
            session: session,
            serverUrl: pos.serverUrl!,
            currency: pos.currency,
            initialPayment: placed.payment,
            timeoutSeconds: pos.bootstrap?.paymentQrTimeoutSeconds ?? 300,
          );
          if (!mounted) return;
          if (qrClose != null && qrClose.held) {
            showPosSnackBar(
              context,
              context.posText(
                'qrHoldPendingSnack',
                'Payment pending. Customer QR is cleared — reopen it beside Scan.',
              ),
            );
            await _load();
            return;
          }
          final paidOrder = qrClose?.order;
          if (paidOrder == null) {
            showPosSnackBar(
              context,
              context.l10n.ordersPaymentNotCompleted(label),
              error: true,
            );
            await _load();
            return;
          }
          showPosSnackBar(
            context,
            context.l10n.ordersPaymentReceived(paidOrder.orderNumber),
          );
          await _load();
          await pos.refreshHeldOrderCount();
          return;
        }

        showPosSnackBar(
          context,
          context.l10n.ordersPaymentRecorded(label),
        );
        await _load();
        await pos.refreshHeldOrderCount();
      } on PosApiException catch (e) {
        if (!mounted) return;
        showPosErrorSnackBar(context, e);
      } catch (e) {
        if (!mounted) return;
        showPosErrorSnackBar(context, e);
      }
      return;
    }

    final payment = await CashRegisterSheet.show(
      context,
      total: due,
      currency: pos.currency,
      tipSettings: pos.bootstrap?.restaurant.tips ?? const TipSettings(),
      paymentGateways: pos.bootstrap?.paymentGateways ?? const [],
      orderLabel: label,
      orderDetail: detail,
      offlineMode: pos.isOffline,
    );
    if (payment == null || !mounted) return;

    final isQrPayment = payment.method == 'phonepe' || payment.method == 'paytm';
    final paymentPayload = {
      'method': payment.method,
      if (payment.cashTendered != null) 'cash_tendered': payment.cashTendered,
      if (payment.tip != null && payment.tip! > 0) 'tip': payment.tip,
    };

    try {
      if (isLocal) {
        final placed = await pos.settleLocalHeldOrder(
          localUuid: localUuid!,
          payment: paymentPayload,
        );
        if (!mounted) return;
        showPosSnackBar(
          context,
          placed.id == 0
              ? context.l10n.orderSavedOffline(placed.orderNumber)
              : context.l10n.ordersPaymentRecorded(label),
        );
        await _load();
        await pos.refreshHeldOrderCount();
        return;
      }

      final data = await PosApi().payOrder(
        session,
        orderId: orderId!,
        payment: paymentPayload,
      );
      if (!mounted) return;

      final orderJson = data['order'] as Map<String, dynamic>?;
      if (orderJson == null) {
        throw PosApiException('Pay response missing order payload.');
      }
      final paymentBody = data['payment'];
      final placed = PlacedPosOrder.fromJson({
        ...orderJson,
        if (paymentBody is Map<String, dynamic>) 'payment': paymentBody,
      });
      pos.registerSelfPlacedOrder(placed.id);

      if (isQrPayment && placed.id > 0 && pos.serverUrl != null) {
        final qrClose = await PosPaymentQrSheet.show(
          context,
          order: placed,
          session: session,
          serverUrl: pos.serverUrl!,
          currency: pos.currency,
          initialPayment: placed.payment,
          timeoutSeconds: pos.bootstrap?.paymentQrTimeoutSeconds ?? 300,
        );
        if (!mounted) return;
        if (qrClose != null && qrClose.held) {
          showPosSnackBar(
            context,
            context.posText(
              'qrHoldPendingSnack',
              'Payment pending. Customer QR is cleared — reopen it beside Scan.',
            ),
          );
          await _load();
          return;
        }
        final paidOrder = qrClose?.order;
        if (paidOrder == null) {
          showPosSnackBar(
            context,
            context.l10n.ordersPaymentNotCompleted(label),
            error: true,
          );
          await _load();
          return;
        }
        showPosSnackBar(
          context,
          context.l10n.ordersPaymentReceived(paidOrder.orderNumber),
        );
        await _load();
        await pos.refreshHeldOrderCount();
        return;
      }

      showPosSnackBar(context, context.l10n.ordersPaymentRecorded(label));
      await _load();
      await pos.refreshHeldOrderCount();
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Widget _buildBody(BuildContext context, {ScrollController? scrollController}) {
    final accent = Theme.of(context).colorScheme.primary;
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final currency = pos.currency;
    final parkedId = pos.parkedOrderId;
    final parkedLocalUuid = pos.parkedLocalUuid;

    return Column(
      children: [
        _SheetHeader(
          accent: accent,
          isHeld: _isHeldTab,
          isCancelled: _isCancelledTab,
          deliveryOnly: widget.deliveryOnly,
          heldCount: _heldCount,
          loading: _loading,
          onRefresh: _load,
          onClose: () => Navigator.of(context).maybePop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _SegmentedTabs(
            tabs: [
              if (!widget.deliveryOnly)
                _TabOpt(
                  id: 'held',
                  label: l10n.ordersHeldTab,
                  icon: Icons.pause_circle_outline_rounded,
                  badge: _heldCount > 0 ? _heldCount : null,
                  badgeColor: PosTheme.holdAmberDark,
                ),
              _TabOpt(
                id: 'orders',
                label: widget.deliveryOnly
                    ? context.posText('ordersDeliveryTab', 'Delivery')
                    : l10n.ordersOrdersTab,
                icon: widget.deliveryOnly
                    ? Icons.delivery_dining_rounded
                    : Icons.receipt_long_rounded,
              ),
              _TabOpt(
                id: 'cancelled',
                label: context.posText('ordersCancelledTab', 'Cancelled'),
                icon: Icons.cancel_outlined,
              ),
            ],
            selected: _tab,
            accent: accent,
            onChanged: (id) {
              if (_tab == id) return;
              setState(() {
                _tab = id;
                _page = 1;
                _statusFilter = id == 'cancelled' ? 'cancelled' : null;
              });
              _load(page: 1);
            },
          ),
        ),
        if (_isHeldTab)
          const _HeldHintBar()
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _FilterPills(
              selected: _filter,
              onChanged: (id) {
                if (id == null) return;
                setState(() {
                  _filter = id;
                  _page = 1;
                });
                _load(page: 1);
              },
              options: [
                (
                  id: 'today',
                  label: l10n.ordersFilterToday,
                  color: PosTheme.ink,
                ),
                (
                  id: 'unpaid',
                  label: l10n.ordersFilterUnpaid,
                  color: PosTheme.holdAmberDark,
                ),
                (
                  id: 'floor',
                  label: l10n.ordersFilterFloor,
                  color: Colors.lightBlue.shade700,
                ),
                (
                  id: 'all',
                  label: l10n.ordersFilterSevenDays,
                  color: Colors.indigo.shade600,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _OrdersSearchField(
              controller: _search,
              onSubmit: () => _load(page: 1),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorPane(
                      message: _error!,
                      onRetry: _load,
                    )
                  : _orders.isEmpty
                      ? PosEmptyState(
                          icon: _isHeldTab
                              ? Icons.pause_circle_outline_rounded
                              : Icons.receipt_long_outlined,
                          title: _isHeldTab
                              ? l10n.ordersNoHeldTitle
                              : () {
                                  final platforms = context
                                          .read<PosController>()
                                          .bootstrap
                                          ?.marketplacePlatforms ??
                                      const <MarketplacePlatformInfo>[];
                                  final match = platforms
                                      .where((p) => p.provider == _sourceFilter)
                                      .firstOrNull;
                                  if (match != null) {
                                    return marketplacePlatformDisplayLabel(
                                      l10n,
                                      match,
                                    );
                                  }
                                  return l10n.ordersNoOrdersTitle;
                                }(),
                          subtitle: _isHeldTab
                              ? l10n.ordersNoHeldSubtitle
                              : () {
                                  final platforms = context
                                          .read<PosController>()
                                          .bootstrap
                                          ?.marketplacePlatforms ??
                                      const <MarketplacePlatformInfo>[];
                                  final match = platforms
                                      .where((p) => p.provider == _sourceFilter)
                                      .firstOrNull;
                                  if (match != null) {
                                    return marketplaceEmptySubtitle(
                                      l10n,
                                      match,
                                      _sourceFilter ?? _filter,
                                    );
                                  }
                                  return l10n.ordersNoOrdersSubtitle;
                                }(),
                          accent: _isHeldTab
                              ? PosTheme.holdAmberDark
                              : (context
                                          .read<PosController>()
                                          .bootstrap
                                          ?.marketplaceEnabled(
                                            _sourceFilter ?? '',
                                          ) ??
                                      false)
                                  ? marketplaceBrandColor(_sourceFilter!)
                                  : accent,
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: _orders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final paymentDraft = order['is_payment_draft'] == true;
                            final id = (order['id'] is num)
                                ? (order['id'] as num).toInt()
                                : null;
                            final localUuid = order['local_uuid'] as String?;
                            final rowKey = localUuid != null &&
                                    localUuid.isNotEmpty
                                ? 'local:$localUuid'
                                : (id != null ? 'server:$id' : null);
                            final isActive = localUuid != null &&
                                    localUuid.isNotEmpty
                                ? localUuid == parkedLocalUuid
                                : id != null && id == parkedId;
                            return _OrderCard(
                              order: order,
                              heldStyle: _isHeldTab,
                              active: isActive,
                              money: (v) => _money(v, currency),
                              onResume: _isHeldTab && !paymentDraft
                                  ? () => _resume(order)
                                  : null,
                              resuming: rowKey != null &&
                                  rowKey == _resumingKey,
                              nextAdvance: (_isHeldTab || _isCancelledTab)
                                  ? null
                                  : _nextAdvance(order),
                              advanceLabel: _advanceLabel,
                              onAdvance: (status) =>
                                  _setStatus(order, status),
                              onCancel: () => _confirmCancel(order),
                              onClearHeld: _isHeldTab && !paymentDraft
                                  ? () => _confirmClearHeld(order)
                                  : null,
                              onCollect: () => _collectPayment(order),
                              onPrint: () => _printOrder(order),
                              onPrintKot: () => _printKot(order),
                              onViewDetails: () => _openOrderDetails(order),
                            );
                          },
                        ),
        ),
        if (!_isHeldTab &&
            (_meta['last_page'] as num?)?.toInt() != null &&
            ((_meta['last_page'] as num).toInt() > 1))
          _PaginationBar(
            from: _meta['from'] ?? 0,
            to: _meta['to'] ?? 0,
            total: _meta['total'] ?? 0,
            page: _page,
            lastPage: (_meta['last_page'] as num).toInt(),
            loading: _loading,
            onPrev: () => _load(page: _page - 1),
            onNext: () => _load(page: _page + 1),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSidePanel) {
      return PosSidePanelShell(
        child: _buildBody(context),
      );
    }

    return DraggableScrollableSheet(
      // Near-fullscreen on phones; thin top gap keeps it reading as a sheet.
      initialChildSize: kPosMobileSheetInitialSize,
      minChildSize: kPosMobileSheetMinSize,
      maxChildSize: kPosMobileSheetMaxSize,
      builder: (context, scrollController) {
        return PosBottomSheetShell(
          child: _buildBody(context, scrollController: scrollController),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.accent,
    required this.isHeld,
    required this.isCancelled,
    required this.deliveryOnly,
    required this.heldCount,
    required this.loading,
    required this.onRefresh,
    required this.onClose,
  });

  final Color accent;
  final bool isHeld;
  final bool isCancelled;
  final bool deliveryOnly;
  final int heldCount;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final headerAccent = isHeld
        ? PosTheme.holdAmberDark
        : isCancelled
            ? const Color(0xFFBE123C)
            : accent;
    final soft = posAccentSoft(headerAccent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: soft.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isHeld
                  ? Icons.pause_circle_rounded
                  : isCancelled
                      ? Icons.cancel_outlined
                      : deliveryOnly
                          ? Icons.delivery_dining_rounded
                          : Icons.receipt_long_rounded,
              color: soft.fg,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deliveryOnly
                      ? context.posText('ordersDeliveryTitle', 'Delivery orders')
                      : context.l10n.ordersTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  isHeld
                      ? (heldCount > 0
                          ? (heldCount == 1
                              ? context.l10n.ordersHeldCountSubtitle(heldCount)
                              : context.l10n
                                  .ordersHeldCountSubtitlePlural(heldCount))
                          : context.l10n.ordersHeldSubtitle)
                      : isCancelled
                          ? context.posText(
                              'ordersCancelledSubtitle',
                              'Cancelled tickets',
                            )
                          : deliveryOnly
                              ? context.posText(
                                  'ordersDeliverySubtitle',
                                  'Swiggy, Zomato and other delivery tickets',
                                )
                              : context.l10n.ordersBranchActivity,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: PosTheme.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: context.l10n.commonClose,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _TabOpt {
  const _TabOpt({
    required this.id,
    required this.label,
    this.icon,
    this.badge,
    this.badgeColor,
  });

  final String id;
  final String label;
  final IconData? icon;
  final int? badge;
  final Color? badgeColor;
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.tabs,
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  final List<_TabOpt> tabs;
  final String selected;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Material(
                color: selected == tab.id ? PosTheme.surface : Colors.transparent,
                elevation: selected == tab.id ? 1.5 : 0,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onChanged(tab.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (tab.icon != null) ...[
                          Icon(
                            tab.icon,
                            size: 16,
                            color: selected == tab.id
                                ? accent
                                : PosTheme.inkMuted,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected == tab.id
                                ? PosTheme.ink
                                : PosTheme.inkMuted,
                          ),
                        ),
                        if (tab.badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: tab.badgeColor ?? accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${tab.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<({String? id, String label, Color color})> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _FilterPill(
              label: options[i].label,
              color: options[i].color,
              selected: selected == options[i].id,
              onTap: () => onChanged(options[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = posTintedChip(color, selected: selected);
    final bg = tone.bg;
    final border = tone.border;
    final fg = tone.fg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeldHintBar extends StatelessWidget {
  const _HeldHintBar();

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(PosTheme.holdAmberDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: soft.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: soft.fg.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: soft.fg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.ordersHeldHint,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: soft.fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersSearchField extends StatelessWidget {
  const _OrdersSearchField({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: context.l10n.ordersSearchHint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: context.l10n.commonSearch,
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: onSubmit,
        ),
        filled: true,
        fillColor: PosTheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: PosTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: PosTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        isDense: true,
      ),
      onSubmitted: (_) => onSubmit(),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              l10n.ordersCouldNotLoad,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.commonTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.from,
    required this.to,
    required this.total,
    required this.page,
    required this.lastPage,
    required this.loading,
    required this.onPrev,
    required this.onNext,
  });

  final Object from;
  final Object to;
  final Object total;
  final int page;
  final int lastPage;
  final bool loading;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(top: BorderSide(color: PosTheme.border)),
      ),
      child: Row(
        children: [
          Text(
            '$from–$to of $total',
            style: TextStyle(
              fontSize: 12,
              color: PosTheme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: loading || page <= 1 ? null : onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PosTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$page / $lastPage',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: loading || page >= lastPage ? null : onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _OrderHeaderBand extends StatelessWidget {
  const _OrderHeaderBand({
    required this.label,
    required this.color,
    required this.icon,
    required this.when,
    required this.total,
    this.onCart = false,
    this.onCartLabel,
    this.emphasized = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final String when;
  final String total;
  final bool onCart;
  final String? onCartLabel;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: PosTheme.isDark
              ? (emphasized ? 0.28 : 0.18)
              : (emphasized ? 0.16 : 0.09),
        ),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kitchenChipPlate(filled: emphasized, fill: color),
              borderRadius: BorderRadius.circular(8),
              border: emphasized
                  ? null
                  : Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: kitchenChipOnPlate(filled: emphasized, color: color),
                ),
                const SizedBox(width: 5),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: kitchenChipOnPlate(filled: emphasized, color: color),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          if (onCart && onCartLabel != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: posAccentSoft(PosTheme.holdAmberDark).bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: posAccentSoft(PosTheme.holdAmberDark)
                      .fg
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                onCartLabel!,
                style: TextStyle(
                  color: posAccentSoft(PosTheme.holdAmberDark).fg,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (when.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: kitchenChipPlate(filled: false).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PosTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: PosTheme.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          if (when.isNotEmpty) const SizedBox(width: 8),
          Text(
            total,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.heldStyle,
    required this.active,
    required this.money,
    this.onResume,
    this.resuming = false,
    this.nextAdvance,
    required this.advanceLabel,
    required this.onAdvance,
    required this.onCancel,
    this.onClearHeld,
    required this.onCollect,
    required this.onPrint,
    required this.onPrintKot,
    this.onViewDetails,
  });

  final Map<String, dynamic> order;
  final bool heldStyle;
  final bool active;
  final String Function(dynamic) money;
  final VoidCallback? onResume;
  final bool resuming;
  final String? nextAdvance;
  final String Function(String) advanceLabel;
  final ValueChanged<String> onAdvance;
  final VoidCallback onCancel;
  final VoidCallback? onClearHeld;
  final VoidCallback onCollect;
  final VoidCallback onPrint;
  final VoidCallback onPrintKot;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final paid = order['payment_status'] == 'paid';
    final orderNumber = '${order['order_number'] ?? '#${order['id']}'}';
    final token = order['token']?.toString().trim();
    final orderType = order['type']?.toString();
    final typeLabel = formatOrderType(orderType);
    final typeColor = kitchenOrderTypeColor(orderType);
    final typeIcon = kitchenOrderTypeIcon(orderType);
    final items =
        (order['items'] as List?)?.whereType<Map>().toList() ?? const [];
    final preview = items.take(3).toList();
    final more = items.length - preview.length;
    final when = _relativeTime(order['created_at'] as String?, l10n);
    final tableName = order['table_name']?.toString().trim();
    final itemCount = order['item_count'];
    String? itemCountLabel;
    if (itemCount != null) {
      final count = itemCount is num
          ? itemCount.toInt()
          : int.tryParse('$itemCount') ?? 0;
      itemCountLabel = count == 1
          ? l10n.ordersItemCount(count)
          : l10n.ordersItemCountPlural(count);
    }
    final customerName = order['customer_name']?.toString().trim();
    final notes = order['notes']?.toString().trim();
    final isCancelled =
        '${order['status'] ?? ''}'.toLowerCase() == 'cancelled';
    final cancelReasonCode =
        (order['cancel_reason'] as String?)?.trim() ?? '';
    final cancelReasonLabelRaw =
        (order['cancel_reason_label'] as String?)?.trim() ?? '';
    final cancelNote = (order['cancel_note'] as String?)?.trim() ?? '';

    final canCancelLive = !heldStyle &&
        !isCancelled &&
        ((order['next_statuses'] as List?)
                ?.map((e) => '$e')
                .contains('cancelled') ??
            false);
    final isLocalHeld = heldStyle &&
        (order['is_local'] == true ||
            ((order['local_uuid'] as String?)?.isNotEmpty ?? false));
    final canClearHeld = heldStyle &&
        onClearHeld != null &&
        (isLocalHeld ||
            ((order['next_statuses'] as List?)
                    ?.map((e) => '$e')
                    .contains('cancelled') ??
                false));
    final canCollect = !heldStyle &&
        !isCancelled &&
        order['can_collect_payment'] == true;
    final hasOrderNumber =
        '${order['order_number'] ?? ''}'.trim().isNotEmpty;
    final canPrint = hasOrderNumber;
    final canPrintKot = hasOrderNumber && !heldStyle && !isCancelled;
    final due = order['amount_due'] ?? order['total'];
    final status = '${order['status'] ?? ''}'.toLowerCase();
    final allowedNext = (order['next_statuses'] as List?)
            ?.map((e) => '$e')
            .toSet() ??
        <String>{};
    final canMarkReady = !heldStyle &&
        allowedNext.contains('ready') &&
        nextAdvance != 'ready' &&
        status != 'ready' &&
        status != 'delivered' &&
        status != 'cancelled';
    final canMarkDone = !heldStyle &&
        allowedNext.contains('delivered') &&
        nextAdvance != 'delivered' &&
        status != 'delivered' &&
        status != 'cancelled';
    final markReadyLabel =
        context.posText('kitchenActionMarkReady', 'Mark as Ready');
    final markDoneLabel = (orderType == 'dine_in' || orderType == 'delivery')
        ? context.posText('kitchenActionDone', 'Delivered')
        : context.posText('kitchenActionMarkDone', 'Done');
    final hasActions = onResume != null ||
        nextAdvance != null ||
        canCancelLive ||
        canClearHeld ||
        canCollect ||
        canPrint ||
        canPrintKot ||
        canMarkReady ||
        canMarkDone ||
        onViewDetails != null;

    final billRequested = order['bill_requested'] == true;
    final billRequest = order['bill_request'] is Map
        ? Map<String, dynamic>.from(order['bill_request'] as Map)
        : null;
    final isSplitBill = billRequest?['is_split'] == true;
    final statusRaw = '${order['status'] ?? ''}';
    final highlight = active || billRequested;
    final cardBg = _orderCardBackground(
      statusRaw,
      held: heldStyle,
      highlight: highlight,
    );
    final borderColor = _orderCardBorderColor(
      statusRaw,
      held: heldStyle,
      highlight: highlight,
    );
    final statusLabel = _orderStatusTitle(
      context,
      statusRaw,
      held: heldStyle,
    );
    final hasTable = tableName?.isNotEmpty == true;
    final hasToken = token?.isNotEmpty == true;
    final statusColor = heldStyle
        ? PosTheme.holdAmberDark
        : _orderStatusColor(statusRaw);
    final statusIcon = _orderStatusIcon(
      context,
      statusRaw,
      held: heldStyle,
    );
    final sourceRaw = order['source']?.toString();
    final paymentStatusRaw =
        '${order['payment_status'] ?? ''}'.trim().toLowerCase();
    final paymentDraft = order['is_payment_draft'] == true ||
        '${order['status'] ?? ''}'.toLowerCase() == 'draft';
    final paymentLabel = heldStyle && !paymentDraft
        ? null
        : billRequested
            ? (isSplitBill
                ? l10n.registerSplitBillBadge
                : l10n.waiterBillRequestedBadge)
            : switch (paymentStatusRaw) {
                'paid' => l10n.commonPaid,
                'pending' when paymentDraft => 'Payment pending',
                'failed' || 'failure' => 'Payment failed',
                'partial' => context.posText(
                    'payStatusPartial',
                    'Partially paid',
                  ),
                'refunded' => context.posText(
                    'payStatusRefunded',
                    'Refunded',
                  ),
                _ => context.posText('ordersUnpaid', 'Unpaid'),
              };
    final paymentMethodLabel = heldStyle && !paymentDraft
        ? ''
        : formatPaymentMethod(order['payment_method']?.toString());
    final notesTone = kitchenCalloutColors();
    final cancelTone = kitchenCalloutColors(danger: true);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _OrderHeaderBand(
              label: statusLabel,
              color: statusColor,
              icon: statusIcon,
              when: when,
              total: money(order['total']),
              onCart: active,
              onCartLabel: l10n.ordersOnCart,
              emphasized: statusRaw.toLowerCase() == 'ready',
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onViewDetails,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, 12, hasActions ? 0 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: PosTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: PosTheme.border.withValues(alpha: 0.85),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OrderPrimaryMark(
                              heldStyle: heldStyle,
                              table: null,
                              token: heldStyle
                                  ? null
                                  : (hasToken ? token : '-'),
                              fallback: '-',
                              color: heldStyle
                                  ? PosTheme.holdAmberDark
                                  : typeColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          orderNumber.startsWith('#')
                                              ? orderNumber
                                              : orderNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: PosTheme.ink,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'Copy order number',
                                        child: InkWell(
                                          onTap: () async {
                                            final raw = orderNumber
                                                    .startsWith('#')
                                                ? orderNumber.substring(1)
                                                : orderNumber;
                                            await Clipboard.setData(
                                              ClipboardData(text: raw),
                                            );
                                            if (!context.mounted) return;
                                            showPosSnackBar(
                                              context,
                                              'Copied $raw',
                                            );
                                          },
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 16,
                                              color: PosTheme.inkMuted,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (hasTable) ...[
                                        const SizedBox(width: 4),
                                        _Chip(
                                          text: tableName!,
                                          icon: Icons.table_bar_outlined,
                                          color: const Color(0xFF059669),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (typeLabel.isNotEmpty)
                                        _Chip(
                                          text: typeLabel,
                                          icon: typeIcon,
                                          color: typeColor,
                                        ),
                                      if (paymentLabel != null &&
                                          paymentLabel.isNotEmpty)
                                        _Chip(
                                          text: paymentLabel,
                                          icon: billRequested
                                              ? (isSplitBill
                                                  ? Icons.call_split_rounded
                                                  : Icons.request_quote_outlined)
                                              : (paid
                                                  ? Icons.check_rounded
                                                  : Icons.payments_outlined),
                                          color: billRequested
                                              ? const Color(0xFFD97706)
                                              : (paid
                                                  ? Colors.green.shade700
                                                  : PosTheme.holdAmberDark),
                                        ),
                                      if (paymentMethodLabel.isNotEmpty)
                                        _Chip(
                                          text: paymentMethodLabel,
                                          icon: Icons.account_balance_wallet_outlined,
                                          color: paid
                                              ? Colors.green.shade700
                                              : const Color(0xFF334155),
                                        ),
                                      if (itemCountLabel != null)
                                        _Chip(
                                          text: itemCountLabel,
                                          icon: Icons.restaurant_menu_outlined,
                                          color: PosTheme.inkMuted,
                                        ),
                                      if (sourceRaw != null &&
                                          sourceRaw.isNotEmpty)
                                        _Chip(
                                          text: kitchenChannelLabel(
                                            context,
                                            sourceRaw,
                                          ),
                                          icon: _orderChannelIcon(sourceRaw),
                                          color: kitchenChannelColor(sourceRaw),
                                        ),
                                    ],
                                  ),
                                  if (customerName != null &&
                                      customerName.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 14,
                                          color: PosTheme.inkMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            customerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: PosTheme.inkMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            color: PosTheme.surface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: PosTheme.border.withValues(alpha: 0.85),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < preview.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                _ItemRow(
                                  item: preview[i],
                                  money: money,
                                  accentColor: typeColor,
                                ),
                              ],
                              if (more > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.ordersMoreItems(more),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: PosTheme.inkMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notesTone.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: notesTone.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 15,
                          color: notesTone.fg,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: notesTone.fg,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isCancelled &&
                    (cancelReasonCode.isNotEmpty ||
                        cancelReasonLabelRaw.isNotEmpty ||
                        cancelNote.isNotEmpty)) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: cancelTone.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cancelTone.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cancelReasonCode.isNotEmpty ||
                            cancelReasonLabelRaw.isNotEmpty)
                          Text(
                            context.posText(
                              'cancelReasonBanner',
                              'Reason: {reason}',
                              {
                                'reason': cancelReasonLabelRaw.isNotEmpty
                                    ? cancelReasonLabelRaw
                                    : orderCancelReasonLabel(
                                        context,
                                        cancelReasonCode,
                                      ),
                              },
                            ),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: cancelTone.fg,
                            ),
                          ),
                        if (cancelNote.isNotEmpty) ...[
                          if (cancelReasonCode.isNotEmpty ||
                              cancelReasonLabelRaw.isNotEmpty)
                            const SizedBox(height: 3),
                          Text(
                            cancelNote,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: PosTheme.inkMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                    ],
                  ),
                ),
              ),
            ),
            if (hasActions)
              Padding(
                padding: const EdgeInsets.all(10),
                child: _OrderActionBar(
              accent: accent,
              onResume: onResume,
              resuming: resuming,
              active: active,
              canClearHeld: canClearHeld,
              onClearHeld: onClearHeld,
              canCollect: canCollect,
              onCollect: onCollect,
              collectLabel: l10n.ordersCollect(money(due)),
              nextAdvance: isCancelled ? null : nextAdvance,
              advanceLabel:
                  nextAdvance != null ? advanceLabel(nextAdvance!) : null,
              onAdvance: nextAdvance != null && !isCancelled
                  ? () => onAdvance(nextAdvance!)
                  : null,
              canPrint: canPrint,
              printAsPrimary: isCancelled && canPrint,
              onPrint: onPrint,
              canPrintKot: canPrintKot,
              onPrintKot: onPrintKot,
              canCancelLive: canCancelLive,
              onCancel: onCancel,
              onViewDetails: onViewDetails,
              resumeLabel: active
                  ? l10n.ordersAlreadyOnCart
                  : resuming
                      ? l10n.commonLoading
                      : l10n.ordersResumeTicket,
              clearHeldLabel:
                  context.posText('ordersClearHeld', 'Clear held'),
              printReceiptLabel: l10n.ordersPrintReceipt,
              printKotLabel: l10n.ordersPrintKot,
              cancelLabel: l10n.commonCancel,
              viewDetailsLabel: context.posText(
                'ordersViewDetails',
                'View order details',
              ),
              markReadyLabel: canMarkReady ? markReadyLabel : null,
              onMarkReady:
                  canMarkReady ? () => onAdvance('ready') : null,
              markDoneLabel: canMarkDone ? markDoneLabel : null,
              onMarkDone:
                  canMarkDone ? () => onAdvance('delivered') : null,
            ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderActionBar extends StatelessWidget {
  const _OrderActionBar({
    required this.accent,
    required this.resuming,
    required this.active,
    required this.canClearHeld,
    required this.canCollect,
    required this.onCollect,
    required this.collectLabel,
    required this.canPrint,
    this.printAsPrimary = false,
    required this.onPrint,
    required this.canPrintKot,
    required this.onPrintKot,
    required this.canCancelLive,
    required this.onCancel,
    required this.resumeLabel,
    required this.clearHeldLabel,
    required this.printReceiptLabel,
    required this.printKotLabel,
    required this.cancelLabel,
    this.onResume,
    this.onClearHeld,
    this.nextAdvance,
    this.advanceLabel,
    this.onAdvance,
    this.onViewDetails,
    this.viewDetailsLabel,
    this.markReadyLabel,
    this.onMarkReady,
    this.markDoneLabel,
    this.onMarkDone,
  });

  final Color accent;
  final VoidCallback? onResume;
  final bool resuming;
  final bool active;
  final bool canClearHeld;
  final VoidCallback? onClearHeld;
  final bool canCollect;
  final VoidCallback onCollect;
  final String collectLabel;
  final String? nextAdvance;
  final String? advanceLabel;
  final VoidCallback? onAdvance;
  final bool canPrint;
  final bool printAsPrimary;
  final VoidCallback onPrint;
  final bool canPrintKot;
  final VoidCallback onPrintKot;
  final bool canCancelLive;
  final VoidCallback onCancel;
  final VoidCallback? onViewDetails;
  final String resumeLabel;
  final String clearHeldLabel;
  final String printReceiptLabel;
  final String printKotLabel;
  final String cancelLabel;
  final String? viewDetailsLabel;
  final String? markReadyLabel;
  final VoidCallback? onMarkReady;
  final String? markDoneLabel;
  final VoidCallback? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final secondary = <Widget>[
      if (onViewDetails != null)
        _OrderIconAction(
          icon: Icons.visibility_outlined,
          tooltip: viewDetailsLabel ?? 'View order details',
          onTap: onViewDetails,
        ),
      if (canPrint && !printAsPrimary)
        _OrderIconAction(
          icon: Icons.print_rounded,
          tooltip: printReceiptLabel,
          onTap: onPrint,
        ),
      if (canPrintKot)
        _OrderIconAction(
          icon: Icons.restaurant_menu_rounded,
          tooltip: printKotLabel,
          onTap: onPrintKot,
        ),
      if (canCancelLive)
        _OrderIconAction(
          icon: Icons.close_rounded,
          tooltip: cancelLabel,
          onTap: onCancel,
          destructive: true,
        ),
    ];

    Widget? primary;
    if (onResume != null) {
      primary = FilledButton.icon(
        onPressed: resuming || active ? null : onResume,
        style: _orderPrimaryButtonStyle(
          backgroundColor: PosTheme.holdAmberDark,
        ),
        icon: resuming
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                active ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                size: 18,
              ),
        label: _orderActionLabel(resumeLabel),
      );
    } else if (printAsPrimary) {
      primary = OutlinedButton.icon(
        onPressed: onPrint,
        icon: const Icon(Icons.print_rounded, size: 18),
        label: _orderActionLabel(printReceiptLabel),
      );
    } else if (canCollect) {
      primary = FilledButton.icon(
        onPressed: onCollect,
        style: _orderPrimaryButtonStyle(
          backgroundColor: PosTheme.holdAmberDark,
        ),
        icon: const Icon(Icons.payments_rounded, size: 18),
        label: _orderActionLabel(collectLabel),
      );
    } else if (nextAdvance != null && onAdvance != null) {
      primary = FilledButton.icon(
        onPressed: onAdvance,
        style: _orderPrimaryButtonStyle(backgroundColor: accent),
        icon: const Icon(Icons.check_rounded, size: 18),
        label: _orderActionLabel(advanceLabel ?? nextAdvance!),
      );
    }

    final showAdvanceBesideCollect = canCollect &&
        nextAdvance != null &&
        onAdvance != null &&
        onResume == null;
    final showMarkReady = onMarkReady != null && markReadyLabel != null;
    final showMarkDone = onMarkDone != null && markDoneLabel != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: PosTheme.canvas.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showAdvanceBesideCollect) ...[
            Row(
              children: [
                ..._spacedIcons(secondary),
                if (secondary.isNotEmpty) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCollect,
                    style: _orderPrimaryButtonStyle(
                      backgroundColor: PosTheme.holdAmberDark,
                    ),
                    icon: const Icon(Icons.payments_rounded, size: 17),
                    label: _orderActionLabel(collectLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdvance,
                style: _orderPrimaryButtonStyle(backgroundColor: accent),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: _orderActionLabel(advanceLabel ?? nextAdvance!),
              ),
            ),
          ] else if (primary != null) ...[
            Row(
              children: [
                ..._spacedIcons(secondary),
                if (secondary.isNotEmpty) const SizedBox(width: 8),
                Expanded(child: primary),
              ],
            ),
          ] else if (secondary.isNotEmpty)
            Row(children: _spacedIcons(secondary)),
          if (showMarkReady || showMarkDone) ...[
            if (primary != null ||
                showAdvanceBesideCollect ||
                secondary.isNotEmpty)
              const SizedBox(height: 8),
            Row(
              children: [
                if (showMarkReady)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onMarkReady,
                      style: kitchenReadyOutlineStyle(compact: true),
                      child: Text(
                        markReadyLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (showMarkReady && showMarkDone) const SizedBox(width: 8),
                if (showMarkDone)
                  Expanded(
                    child: FilledButton(
                      onPressed: onMarkDone,
                      style: _orderPrimaryButtonStyle(
                        backgroundColor: Colors.lightBlue.shade700,
                      ),
                      child: _orderActionLabel(markDoneLabel!),
                    ),
                  ),
              ],
            ),
          ],
          if (canClearHeld && onClearHeld != null) ...[
            if (primary != null ||
                showAdvanceBesideCollect ||
                secondary.isNotEmpty ||
                showMarkReady ||
                showMarkDone)
              const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: resuming ? null : onClearHeld,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PosTheme.holdAmberDark,
                  side: BorderSide(
                    color: PosTheme.holdAmberDark.withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(clearHeldLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _spacedIcons(List<Widget> icons) {
    if (icons.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < icons.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 6));
      out.add(icons[i]);
    }
    return out;
  }
}

class _OrderIconAction extends StatelessWidget {
  const _OrderIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tone = destructive ? posStatusColors('cancelled') : null;
    final fg = destructive ? tone!.fg : PosTheme.ink;
    final bg = destructive
        ? tone!.bg.withValues(alpha: PosTheme.isDark ? 0.55 : 0.9)
        : PosTheme.surface;
    final border = destructive
        ? tone!.fg.withValues(alpha: 0.4)
        : PosTheme.border;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
        ),
      ),
    );
  }
}

class _OrderPrimaryMark extends StatelessWidget {
  const _OrderPrimaryMark({
    required this.heldStyle,
    required this.table,
    required this.token,
    required this.fallback,
    required this.color,
  });

  final bool heldStyle;
  final String? table;
  final String? token;
  final String fallback;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 54.0;
    final tokenValue = (token != null && token!.trim().isNotEmpty)
        ? token!.trim()
        : fallback;
    final compactToken =
        tokenValue.length > 4 ? tokenValue.substring(tokenValue.length - 4) : tokenValue;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: heldStyle
          ? Icon(Icons.pause_circle_outline_rounded, color: color, size: 26)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.posText('ordersTokenLabel', 'TOKEN'),
                  style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w800,
                    fontSize: 8,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  compactToken,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    color: color,
                  ),
                ),
              ],
            ),
    );
  }
}

ButtonStyle _orderPrimaryButtonStyle({required Color backgroundColor}) {
  return FilledButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: Colors.white,
    disabledBackgroundColor: backgroundColor.withValues(alpha: 0.4),
    disabledForegroundColor: Colors.white,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

Widget _orderActionLabel(String text) {
  return Text(
    text,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.money,
    this.accentColor,
  });

  final Map item;
  final String Function(dynamic) money;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final mods = (item['modifiers'] as List?)?.join(' · ');
    final qtyColor = accentColor ?? PosTheme.inkMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 28),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: qtyColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: qtyColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            '${item['quantity'] ?? 1}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: qtyColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['name'] ?? 'Item'}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: PosTheme.ink,
                  height: 1.25,
                ),
              ),
              if (mods != null && mods.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    mods,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: PosTheme.inkMuted,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          money(item['line_total']),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: PosTheme.ink,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = PosTheme.isDark ? posAccentSoft(color).fg : color;
    final bg = PosTheme.isDark
        ? posAccentSoft(color).bg
        : color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

Color _orderStatusColor(String status) {
  return switch (status.toLowerCase()) {
    'pending' || 'draft' => Colors.amber.shade700,
    'confirmed' => Colors.lightBlue.shade700,
    'preparing' => Colors.deepPurple.shade500,
    'ready' => Colors.green.shade600,
    'delivered' => Colors.teal.shade700,
    'cancelled' => const Color(0xFFBE123C),
    _ => PosTheme.inkMuted,
  };
}

IconData _orderChannelIcon(String channel) {
  return switch (channel) {
    'pos' => Icons.point_of_sale_outlined,
    'kiosk' => Icons.tablet_mac_outlined,
    'online' => Icons.language_rounded,
    'zomato' || 'swiggy' => Icons.delivery_dining_outlined,
    _ => Icons.storefront_outlined,
  };
}

String _orderLaneKey(String status) {
  return switch (status.toLowerCase()) {
    'pending' || 'draft' => 'new',
    'confirmed' => 'confirmed',
    'preparing' => 'preparing',
    'ready' => 'ready',
    _ => '',
  };
}

IconData _orderStatusIcon(
  BuildContext context,
  String status, {
  bool held = false,
}) {
  if (held) return Icons.pause_rounded;
  final lane = _orderLaneKey(status);
  if (lane.isNotEmpty) return kitchenLaneStyle(lane, context).icon;
  return switch (status.toLowerCase()) {
    'delivered' => Icons.check_circle_outline,
    'cancelled' => Icons.cancel_outlined,
    _ => Icons.receipt_long_outlined,
  };
}

String _orderStatusTitle(
  BuildContext context,
  String status, {
  required bool held,
}) {
  if (status.toLowerCase() == 'draft') {
    return context.posText('adminStatusDraftHeld', 'Draft (held)');
  }
  if (held) return context.l10n.ordersHeldTicket;
  final lane = _orderLaneKey(status);
  if (lane.isNotEmpty) return kitchenLaneTitleForKey(context, lane);
  return switch (status.toLowerCase()) {
    'delivered' => context.posText('ordersFilterDelivered', 'Delivered'),
    'cancelled' => context.posText('ordersFilterCancelled', 'Cancelled'),
    _ => status.replaceAll('_', ' '),
  };
}

Color _orderCardBackground(
  String status, {
  required bool held,
  required bool highlight,
}) {
  if (held || highlight) return kitchenLaneCardBackground('new');
  final lane = _orderLaneKey(status);
  if (lane.isNotEmpty) return kitchenLaneCardBackground(lane);
  return switch (status.toLowerCase()) {
    'delivered' => Color.lerp(
          PosTheme.surface,
          Colors.teal,
          PosTheme.isDark ? 0.22 : 0.08,
        ) ??
        PosTheme.surface,
    'cancelled' => Color.lerp(
          PosTheme.surface,
          const Color(0xFFBE123C),
          PosTheme.isDark ? 0.22 : 0.08,
        ) ??
        PosTheme.surface,
    _ => PosTheme.surface,
  };
}

Color _orderCardBorderColor(
  String status, {
  required bool held,
  required bool highlight,
}) {
  if (held || highlight) {
    return kitchenLaneCardBorder('new', urgent: false);
  }
  final lane = _orderLaneKey(status);
  if (lane.isNotEmpty) return kitchenLaneCardBorder(lane, urgent: false);
  return switch (status.toLowerCase()) {
    'delivered' => PosTheme.isDark
        ? Colors.teal.shade400.withValues(alpha: 0.5)
        : Colors.teal.shade200,
    'cancelled' => PosTheme.isDark
        ? const Color(0xFFFDA4AF).withValues(alpha: 0.5)
        : const Color(0xFFFECACA),
    _ => PosTheme.border,
  };
}

String _relativeTime(String? iso, AppLocalizations l10n) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final local = dt.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inSeconds < 45) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
  return DateFormat('MMM d · h:mm a').format(local);
}
