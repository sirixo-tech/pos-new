import '../widgets/pos_cart_summary_bar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../payments/payment_session.dart';
import '../payments/payment_session_manager.dart';
import '../providers/kitchen_controller.dart';
import '../providers/pos_catalog_layout_settings.dart';
import '../providers/pos_category_bar_settings.dart';
import '../providers/pos_admin_controller.dart';
import '../providers/pos_controller.dart';
import '../providers/pos_locale_controller.dart';
import '../services/customer_display/customer_display_broker.dart';
import '../services/customer_display/smartpos_customer_display_service.dart';
import '../services/kitchen_dock_storage.dart';
import '../services/offline/pending_order.dart';
import '../services/pos_api.dart';
import '../services/pos_display_mode.dart';
import '../services/pos_pin_prompt_storage.dart';
import '../services/printing/print_job_coordinator.dart';
import '../services/printing/print_skipped.dart';
import '../services/printing/pos_receipt_printer.dart';
import '../services/printing/printer_status_service.dart';
import '../services/printing/scan_to_print_history.dart';
import '../services/printing/scan_to_print_settings.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/media_url.dart';
import '../utils/outside_schedule.dart';
import '../utils/order_barcode_scan.dart';
import '../utils/pos_layout.dart';
import '../widgets/cash_register_sheet.dart';
import '../widgets/collect_payment_sheet.dart';
import '../widgets/day_end_reports_sheet.dart';
import '../widgets/modifier_sheet.dart';
import '../widgets/new_order_alert_banner.dart';
import '../widgets/order_placed_notice.dart';
import '../widgets/offline_status_indicator.dart';
import '../widgets/pos_app_update_ui.dart';
import '../widgets/pos_hardware_status.dart';
import '../widgets/pos_payment_qr_sheet.dart';
import '../widgets/pos_cart_panel.dart';
import '../widgets/pos_category_rail.dart';
import '../widgets/pos_menu_item_card.dart';
import '../widgets/pos_more_menu.dart';
import '../widgets/pos_more_menu_sections.dart';
import '../widgets/pos_network_logo.dart';
import '../widgets/pos_ops_bar.dart';
import '../widgets/pos_order_barcode_listener.dart';
import '../widgets/pos_overlay.dart';
import '../widgets/pos_scan_to_print_dialog.dart';
import '../widgets/pos_system_status_dialog.dart';
import '../widgets/pos_ui.dart';
import '../widgets/staff_notifications_panel.dart';
import 'admin/admin_menu_screen.dart';
import 'admin/admin_shell.dart';
import 'kitchen/kitchen_panel.dart';
import 'pos_orders_sheet.dart';
import 'printer_setup_screen.dart';
import 'pos_register_more_actions.dart';
import 'admin/admin_menu_import_screen.dart';
import 'pos_mobile_reports_page.dart';
import 'pos_mobile_settings_page.dart';
import 'shift_open_overlay.dart';
import 'set_pos_pin_screen.dart';

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _OpenHeldIntent extends Intent {
  const _OpenHeldIntent();
}

class _ParkIntent extends Intent {
  const _ParkIntent();
}

class _PayIntent extends Intent {
  const _PayIntent();
}

class _ClearCartIntent extends Intent {
  const _ClearCartIntent();
}

class _LockIntent extends Intent {
  const _LockIntent();
}

class _FullscreenIntent extends Intent {
  const _FullscreenIntent();
}

class PosShell extends StatefulWidget {
  const PosShell({super.key});

  @override
  State<PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<PosShell> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _cartOpen = false;
  int _mobileTab = 0;
  final Set<int> _seenMobileTabs = {0};
  BuildContext? _cartSheetContext;
  bool _scanPrintBusy = false;
  bool _kotDockOpen = false;
  bool _kotSheetOpen = false;

  Future<void> _openCart() async {
    if (_cartOpen) return;
    setState(() => _cartOpen = true);
    await showPosBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        _cartSheetContext = sheetContext;
        return SizedBox(
          height: posMobileSheetHeight(sheetContext),
          child: _MobileCartSheet(
            onClose: () => Navigator.of(sheetContext).pop(),
            onPay: () => _onPay(quickMethod: 'more'),
            onPayMethod: (method) => _onPay(quickMethod: method),
            onPark: _onPark,
            onOpenHeld: () {
              Navigator.of(sheetContext).maybePop();
              _openHeldOrders();
            },
          ),
        );
      },
    );
    _cartSheetContext = null;
    if (mounted) setState(() => _cartOpen = false);
  }

  void _closeCart() {
    final sheetContext = _cartSheetContext;
    if (sheetContext != null && sheetContext.mounted) {
      Navigator.of(sheetContext).maybePop();
    }
    if (mounted && _cartOpen) {
      setState(() => _cartOpen = false);
    }
  }

  void _selectMobileTab(int index) {
    setState(() {
      _mobileTab = index;
      _seenMobileTabs.add(index);
    });
  }

  PosController? _printerSetupPos;
  bool _printerSetupOpened = false;

  void _checkPrinterSetupAfterLogin() {
    final pos = _printerSetupPos;
    if (!mounted || pos == null || _printerSetupOpened ||
        pos.phase != PosAppPhase.ready || !pos.isRegisterMode) {
      return;
    }
    _printerSetupOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (pos.phase != PosAppPhase.ready || !pos.isRegisterMode) {
        _printerSetupOpened = false;
        return;
      }
      if (!pos.claimPrinterSetupForSession()) return;
      unawaited(_openPrinterSetupAfterLogin(pos));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _onMobileSettings(String value) {
    final pos = context.read<PosController>();
    return handlePosRegisterMoreAction(
      context: context, pos: pos, l10n: context.l10n, value: value,
      hasPin: pos.session?.hasPosPin == true,
      onOpenPartnerOrders: _openPartnerOrders,
      onOpenDayEndReports: () => _selectMobileTab(4),
      onOpenNotifications: _openNotifications,
      onOpenDelivery: _openDeliveryOrders,
      onRefreshMenu: () => pos.refreshBootstrap(),
      onOpenCustomerDisplay: () => showCustomerDisplayStatusDialog(context),
    );
  }

  Widget _handheldTabs(Color accent) {
    Widget tab(int index, Widget child) {
      if (!_seenMobileTabs.contains(index)) return const SizedBox.shrink();
      return child;
    }

    return IndexedStack(
      index: _mobileTab,
      children: [
        _phoneLayout(accent),
        tab(
          1,
          PosOrdersSheet(initialTab: 'orders', embedded: true,
            onResume: () => _selectMobileTab(0)),
        ),
        tab(
          2,
          const AdminMenuImportScreen(enableVoice: true),
        ),
        // Load the editor while POS is visible, and retain its data between tabs.
        _mobileMenu(),
        tab(
          4,
          PosMobileReportsPage(onPrint: _printThermalReport),
        ),
        tab(5, PosMobileSettingsPage(onSelected: _onMobileSettings)),
      ],
    );
  }

  Widget _mobileMenu() {
    return Builder(
      builder: (context) {
        final pos = context.read<PosController>();
        final api = context.read<PosApi>();
        if (pos.bootstrap?.adminCapabilities.canAccessAdmin != true) {
          return const Center(child: Text('Menu access is not available for this account.'));
        }
        return ChangeNotifierProvider(
          create: (_) => PosAdminController(api: api, pos: pos),
          child: const AdminMenuScreen(),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // macOS "Delete" is usually Backspace; text fields also swallow Delete.
    // A hardware handler keeps ⇧ Delete / ⇧ ⌫ working for clear-cart.
    HardwareKeyboard.instance.addHandler(_handleClearCartShortcut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pos = context.read<PosController>();
      pos.refreshHeldOrderCount();
      unawaited(pos.refreshRegisterBillAlerts(silent: true));
      _printerSetupPos = pos;
      pos.addListener(_checkPrinterSetupAfterLogin);
      _checkPrinterSetupAfterLogin();
      unawaited(_loadKotDockState());
      unawaited(_bootKitchenIfNeeded());
      unawaited(
        PosAdminController.warm(context.read<PosApi>(), pos),
      );
    });
  }

  Future<void> _openPrinterSetupAfterLogin(PosController pos) async {
    if (pos.phase == PosAppPhase.ready && pos.isRegisterMode) {
      await PrinterSetupScreen.open(context);
    }
    if (mounted) await _maybePromptSetPosPin(pos);
  }

  Future<void> _loadKotDockState() async {
    final branchId = context.read<PosController>().session?.branchId;
    if (branchId == null) return;
    final open = await KitchenDockStorage.readOpen(branchId);
    if (!mounted) return;
    final width = MediaQuery.sizeOf(context).width;
    final canInline =
        usePosDesktopLayout(context) && width >= kPosKotOverlayBreakpoint;
    setState(() => _kotDockOpen = open && canInline);
  }

  Future<void> _bootKitchenIfNeeded() async {
    final pos = context.read<PosController>();
    if (!pos.canUseKitchen) return;
    final session = pos.session;
    if (session == null) return;
    await context.read<KitchenController>().ensureRunning(
      session: session,
      ensureKitchenToken: pos.ensureKitchenApiToken,
    );
  }

  Future<void> _toggleKotDock() async {
    final pos = context.read<PosController>();
    final desktop = usePosDesktopLayout(context);
    if (!desktop) {
      await _openKotSheet();
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width < kPosKotOverlayBreakpoint) {
      if (_kotSheetOpen) return;
      await _openKotOverlay();
      return;
    }
    final next = !_kotDockOpen;
    setState(() => _kotDockOpen = next);
    final branchId = pos.session?.branchId;
    if (branchId != null) {
      await KitchenDockStorage.persistOpen(branchId, next);
    }
    if (next) {
      await _bootKitchenIfNeeded();
    }
  }

  Future<void> _openKotOverlay() async {
    if (_kotSheetOpen) return;
    setState(() => _kotSheetOpen = true);
    await _bootKitchenIfNeeded();
    if (!mounted) return;
    final width = MediaQuery.sizeOf(context).width;
    await showPosSidePanel<void>(
      context: context,
      width: width.clamp(300.0, 360.0),
      builder: (sheetContext) => PosSidePanelShell(
        child: KitchenDockPanel(
          splitCompact: true,
          showCloseButton: true,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (mounted) setState(() => _kotSheetOpen = false);
  }

  Future<void> _openKotSheet() async {
    if (_kotSheetOpen) return;
    setState(() => _kotSheetOpen = true);
    await _bootKitchenIfNeeded();
    if (!mounted) return;
    await showPosBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return SizedBox(
          height: posMobileSheetHeight(sheetContext) * 0.92,
          child: KitchenDockPanel(
            showCloseButton: true,
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    );
    if (mounted) setState(() => _kotSheetOpen = false);
  }

  Future<void> _openNotifications() async {
    final l10n = context.l10n;
    await StaffNotificationsPanel.open(
      context,
      emptySubtitle: l10n.registerNotificationsEmptySubtitle,
    );
  }

  void _maybeShowRegisterBillBanner(PosController pos) {
    final pending = pos.registerBannerAlert;
    if (pending == null) return;
    // New-order / marketplace cues use [NewOrderAlertBannerHost].
    if (pending.type.isNewOrderCue) return;
    final alert = pos.takeRegisterBannerAlert();
    if (alert == null || !mounted) return;
    HapticFeedback.mediumImpact();
    showPosSnackBar(context, alert.body, duration: const Duration(seconds: 4));
  }

  bool _handleClearCartShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isShiftPressed) return false;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.delete &&
        key != LogicalKeyboardKey.backspace) {
      return false;
    }
    if (!mounted) return false;
    // Don't steal the shortcut while another route/dialog is on top.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    unawaited(_clearCartShortcut());
    return true;
  }

  Future<void> _maybePromptSetPosPin(PosController pos) async {
    if (!pos.offerSetPosPinPrompt || pos.session?.hasPosPin == true) {
      return;
    }
    final userId = pos.profile?.user.id;
    if (userId != null && userId > 0) {
      final dismissed = await PosPinPromptStorage.isDismissed(userId);
      if (dismissed) {
        pos.clearSetPosPinPrompt();
        return;
      }
    }
    pos.clearSetPosPinPrompt();
    if (!mounted) return;

    final l10n = context.l10n;
    final goSet = await showPosConfirmDialog(
      context,
      title: l10n.pinPromptTitle,
      message: l10n.pinPromptMessage,
      confirmLabel: l10n.pinPromptSet,
      cancelLabel: l10n.pinPromptNotNow,
    );
    if (!mounted) return;
    if (!goSet) {
      if (userId != null && userId > 0) {
        await PosPinPromptStorage.dismiss(userId);
      }
      return;
    }
    await SetPosPinScreen.open(context);
  }

  @override
  void dispose() {
    _printerSetupPos?.removeListener(_checkPrinterSetupAfterLogin);
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleClearCartShortcut);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PosController>().refreshAlertsOnResume();
    }
  }

  void _focusSearch() {
    _searchFocus.requestFocus();
  }

  Future<void> _openOrders() async {
    await PosOrdersSheet.open(context, initialTab: 'orders');
    if (mounted) {
      context.read<PosController>().refreshHeldOrderCount();
    }
  }

  Future<void> _openHeldOrders() async {
    await PosOrdersSheet.open(context, initialTab: 'held');
    if (mounted) {
      context.read<PosController>().refreshHeldOrderCount();
    }
  }

  Future<void> _openDeliveryOrders() async {
    await PosOrdersSheet.open(
      context,
      initialTab: 'orders',
      deliveryOnly: true,
    );
    if (mounted) {
      context.read<PosController>().refreshHeldOrderCount();
    }
  }

  Future<void> _openPartnerOrders(String provider) async {
    await PosOrdersSheet.open(
      context,
      initialTab: 'orders',
      initialFilter: provider,
    );
    if (mounted) {
      context.read<PosController>().refreshHeldOrderCount();
    }
  }

  Future<void> _toggleFullscreen() async {
    if (!PosDisplayMode.supportsToggle) return;
    final enabled = await PosDisplayMode.toggle();
    if (!mounted) return;
    setState(() {});
    showPosSnackBar(
      context,
      enabled
          ? context.posText('shellFullscreenOn', 'Fullscreen on')
          : context.posText('shellFullscreenOff', 'Fullscreen off'),
    );
  }

  Future<void> _clearCartShortcut() async {
    final pos = context.read<PosController>();
    if (pos.cart.isEmpty && !pos.hasParkedTicket) return;
    final l10n = context.l10n;
    final ok = await showPosConfirmDialog(
      context,
      title: l10n.cartClearTitle,
      message: l10n.cartClearMessage,
      confirmLabel: l10n.commonClear,
      destructive: true,
    );
    if (!ok || !mounted) return;
    pos.clearCart();
    _closeCart();
  }

  Future<void> _onItemTap(MenuItem item) async {
    final pos = context.read<PosController>();
    final alreadyInCart = pos.cart.any((line) => line.menuItem.id == item.id);
    if (!alreadyInCart) {
      final ok = await confirmOutsideScheduleIfNeeded(context, item);
      if (!ok || !mounted) return;
    }

    if (item.hasOptions) {
      await ModifierSheet.show(context, item);
      return;
    }
    pos.addToCart(CartLine(menuItem: item));
  }

  bool _isQrMethod(String method) {
    final slug = method.trim().toLowerCase();
    if (['upi', 'phonepe', 'paytm'].contains(slug)) return true;
    return context.read<PosController>().bootstrap?.paymentGateways.any(
      (gateway) => gateway.slug.toLowerCase() == slug && gateway.isDynamicQr,
    ) ?? false;
  }

  Future<void> _payCartDirect(String quickMethod) async {
    final pos = context.read<PosController>();
    if (pos.cart.isEmpty || pos.submitting) return;

    final gateways = pos.bootstrap?.paymentGateways ?? const [];
    var method = quickMethod.trim().toLowerCase();
    if (method == 'upi') {
      final qr = gateways.where(
        (g) => g.isDynamicQr || g.slug == 'phonepe' || g.slug == 'paytm',
      );
      method = qr.isEmpty ? 'phonepe' : qr.first.slug;
    }

    final isQrPayment = _isQrMethod(method);
    if (isQrPayment && pos.isOffline) {
      showPosSnackBar(context, context.l10n.payNotCompleted, error: true);
      return;
    }

    final due = pos.cartAmountDue;
    await _submitCartPayment(
      PaymentSubmission(
        method: method,
        cashTendered: method == 'cash' ? due : null,
      ),
    );
  }

  Future<void> _onPay({String? quickMethod}) async {
    final pos = context.read<PosController>();
    if (pos.cart.isEmpty || pos.submitting) return;

    if (quickMethod != 'more') {
      await _payCartDirect(quickMethod ?? 'cash');
      return;
    }

    // Skip checkout upsells — More opens the full register (split, tender, tips).
    final tips = pos.bootstrap?.restaurant.tips ?? const TipSettings();
    final gateways = pos.bootstrap?.paymentGateways ?? const [];
    final cartTotal = pos.cartTotal;
    final amountDue = pos.cartAmountDue;
    final alreadyPaid = pos.parkedAmountPaid;
    final parkedId = pos.parkedOrderId;
    final itemCount = pos.cartItemCount;
    final orderDetail = itemCount == 1
        ? context.l10n.cartItemCount(itemCount)
        : context.l10n.cartItemCountPlural(itemCount);

    Map<String, dynamic>? splitTicket;

    final result = await CollectPaymentSheet.openForCart(
      context,
      total: amountDue,
      currency: pos.currency,
      tipSettings: tips,
      paymentGateways: gateways,
      offlineMode: pos.isOffline,
      orderLabel: pos.parkedOrderLabel,
      initialPaymentMethod: null,
      orderDetail: alreadyPaid > 0.001
          ? context.posText(
              'cartPartialBalance',
              '{paid} paid · {due} remaining',
              {
                'paid': formatMoney(alreadyPaid, pos.currency),
                'due': formatMoney(amountDue, pos.currency),
              },
            )
          : orderDetail,
      createUnpaidOrder: () async {
        if (parkedId != null && pos.parkedLocalUuid == null) {
          await pos.syncParkedOpenOrder();
          splitTicket = pos.parkedPaymentSnapshot();
          return splitTicket!;
        }
        final placed = await pos.submitOrder(
          paymentMethod: 'pay_later',
          allowOffline: false,
        );
        pos.registerSelfPlacedOrder(placed.id);
        final total = placed.total ?? cartTotal;
        splitTicket = {
          'id': placed.id,
          'order_number': placed.orderNumber,
          'token': placed.token,
          'total': total,
          'amount_due': placed.amountDue ?? total,
          'amount_paid': alreadyPaid,
          'payment_status': alreadyPaid > 0.001 ? 'partial' : 'pending',
          'can_collect_payment': true,
        };
        return splitTicket!;
      },
    );
    if (!mounted || result == null) {
      if (result == null && splitTicket != null && mounted) {
        final number = splitTicket?['order_number']?.toString() ?? '';
        final orderId = splitTicket?['id'];
        final id = orderId is int
            ? orderId
            : (orderId is num ? orderId.toInt() : int.tryParse('$orderId'));
        if (id != null && id > 0 && number.isNotEmpty) {
          unawaited(
            context.read<PrintJobCoordinator>().enqueueKot(
              orderId: id,
              orderNumber: number,
              source: 'pos',
              cashierCheckout: true,
            ),
          );
        }
        context.read<PosController>().showCashierPlacedNotice(
          orderNumber: number.isEmpty ? context.l10n.payLaterHelp : number,
          orderId: id,
        );
        _closeCart();
      }
      return;
    }

    if (result == true) {
      final orderId = splitTicket?['id'];
      final id = orderId is int
          ? orderId
          : (orderId is num ? orderId.toInt() : int.tryParse('$orderId'));
      final number = splitTicket?['order_number']?.toString() ?? '';
      showPosSnackBar(
        context,
        number.isEmpty
            ? context.l10n.splitBillFullyPaid
            : context.l10n.ordersPaymentReceived(number),
      );
      _closeCart();
      if (id != null && id > 0) {
        _queueCheckoutPrints(orderId: id, orderNumber: number);
        context.read<PosController>().showCashierPlacedNotice(
          orderNumber: number.isEmpty ? '#$id' : number,
          orderId: id,
        );
      }
      return;
    }

    if (result is! PaymentSubmission) return;
    await _submitCartPayment(result, splitTicket: splitTicket);
  }

  Future<void> _submitCartPayment(
    PaymentSubmission payment, {
    Map<String, dynamic>? splitTicket,
  }) async {
    final pos = context.read<PosController>();

    final existingRaw = splitTicket?['id'];
    final existingId = existingRaw is int
        ? existingRaw
        : (existingRaw is num
              ? existingRaw.toInt()
              : int.tryParse('$existingRaw'));
    if (existingId != null && existingId > 0) {
      await _settleOpenTicketPayment(
        orderId: existingId,
        orderLabel: splitTicket?['order_number']?.toString() ?? '#$existingId',
        payment: payment,
      );
      return;
    }

    final isQrPayment = _isQrMethod(payment.method);

    final parkedId = pos.parkedOrderId;
    if (isQrPayment && parkedId != null && parkedId > 0) {
      final existing = PaymentSessionManager.instance.sessionForOrder(parkedId);
      final sameAmount =
          existing != null && (existing.amount - pos.cartTotal).abs() < 0.005;
      if (existing != null &&
          sameAmount &&
          !existing.status.isTerminal &&
          DateTime.now().isBefore(existing.expiresAt) &&
          existing.qrData.trim().isNotEmpty) {
        await _reopenHeldPaymentQr(existing);
        return;
      }
    }

    try {
      final order = await pos.submitOrder(
        paymentMethod: payment.method,
        cashTendered: payment.cashTendered,
        tip: payment.tip,
        allowOffline: !isQrPayment,
      );
      if (!mounted) return;

      if ((isQrPayment || order.isQrPayment) &&
          order.id > 0 &&
          pos.session != null &&
          pos.serverUrl != null) {
        final qrClose = await PosPaymentQrSheet.show(
          context,
          order: order,
          session: pos.session!,
          serverUrl: pos.serverUrl!,
          currency: pos.currency,
          initialPayment: order.payment,
          timeoutSeconds: pos.bootstrap?.paymentQrTimeoutSeconds ?? 300,
        );
        if (!mounted) return;
        if (qrClose != null && qrClose.held) {
          _closeCart();
          showPosSnackBar(
            context,
            context.posText(
              'qrHoldPendingSnack',
              'Payment pending. Customer QR is cleared — reopen it beside Scan.',
            ),
          );
          return;
        }
        final paidOrder = qrClose?.order;
        if (qrClose?.cancelled == true) {
          _closeCart();
          return;
        }
        if (paidOrder == null) {
          showPosSnackBar(context, context.l10n.payNotCompleted, error: true);
          return;
        }
        _closeCart();
        _queueCheckoutPrints(
          orderId: paidOrder.id,
          orderNumber: paidOrder.orderNumber,
        );
        pos.showCashierPlacedNotice(
          orderNumber: paidOrder.orderNumber,
          orderId: paidOrder.id,
        );
        return;
      }

      final isOfflineOrder = pos.lastOfflineOrder != null;
      if (payment.method == 'cash') {
        CustomerDisplayBroker.instance.showCashPaymentSuccess(
          amount: pos.cartTotal,
          orderNumber: order.orderNumber,
        );
      }
      _closeCart();
      pos.showCashierPlacedNotice(
        orderNumber: order.orderNumber,
        orderId: order.id > 0 ? order.id : null,
      );

      if (isOfflineOrder && pos.lastOfflineOrder != null) {
        final bootstrap = pos.bootstrap;
        if (!PosReceiptPrinter.isSupported) {
          // Browser checkout has no printer port. The order stays queued.
        } else if (bootstrap == null) {
          showPosSnackBar(
            context,
            'Order saved on this register. Receipt data is not loaded yet.',
            error: true,
          );
        } else {
          await _printOfflineReceipt(bootstrap, pos.lastOfflineOrder!);
          if (payment.method == 'cash') {
            try {
              await PosReceiptPrinter.openCashDrawer();
            } catch (_) {}
          }
        }
      } else if (order.id > 0) {
        if (payment.method == 'cash') {
          unawaited(() async {
            try {
              await PosReceiptPrinter.openCashDrawer();
            } catch (_) {}
          }());
        }
        _queueCheckoutPrints(orderId: order.id, orderNumber: order.orderNumber);
      }
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _settleOpenTicketPayment({
    required int orderId,
    required String orderLabel,
    required PaymentSubmission payment,
  }) async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;

    final isQrPayment = _isQrMethod(payment.method);
    final paymentPayload = {
      'method': payment.method,
      if (payment.cashTendered != null) 'cash_tendered': payment.cashTendered,
      if (payment.tip != null && payment.tip! > 0) 'tip': payment.tip,
    };

    try {
      final data = await PosApi().payOrder(
        session,
        orderId: orderId,
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

      if ((isQrPayment || placed.isQrPayment) && placed.id > 0 && pos.serverUrl != null) {
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
          _closeCart();
          showPosSnackBar(
            context,
            context.posText(
              'qrHoldPendingSnack',
              'Payment pending. Customer QR is cleared — reopen it beside Scan.',
            ),
          );
          return;
        }
        final paidOrder = qrClose?.order;
        if (qrClose?.cancelled == true) {
          _closeCart();
          return;
        }
        if (paidOrder == null) {
          showPosSnackBar(
            context,
            context.l10n.ordersPaymentNotCompleted(orderLabel),
            error: true,
          );
          return;
        }
        showPosSnackBar(
          context,
          context.l10n.ordersPaymentReceived(paidOrder.orderNumber),
        );
        _closeCart();
        _queueCheckoutPrints(
          orderId: paidOrder.id,
          orderNumber: paidOrder.orderNumber,
        );
        pos.showCashierPlacedNotice(
          orderNumber: paidOrder.orderNumber,
          orderId: paidOrder.id,
        );
        return;
      }

      showPosSnackBar(context, context.l10n.ordersPaymentRecorded(orderLabel));
      if (payment.method == 'cash') {
        unawaited(() async {
          try {
            await PosReceiptPrinter.openCashDrawer();
          } catch (_) {}
        }());
        CustomerDisplayBroker.instance.showCashPaymentSuccess(
          amount: placed.chargeAmount,
          orderNumber: placed.orderNumber,
        );
      }
      _closeCart();
      if (placed.id > 0) {
        _queueCheckoutPrints(
          orderId: placed.id,
          orderNumber: placed.orderNumber,
        );
        pos.showCashierPlacedNotice(
          orderNumber: placed.orderNumber,
          orderId: placed.id,
        );
      }
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _reopenHeldPaymentQr(PaymentSession session) async {
    if (session.status.isTerminal ||
        !DateTime.now().isBefore(session.expiresAt) ||
        session.qrData.trim().isEmpty) {
      showPosSnackBar(
        context,
        context.posText(
          'qrPendingInactive',
          'This payment QR is no longer active.',
        ),
        error: true,
      );
      return;
    }
    final pos = context.read<PosController>();
    final live = pos.session;
    final serverUrl = pos.serverUrl;
    if (live == null || serverUrl == null) return;

    final timeout = session.expiresAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(1, 900);
    final payment = PosOrderPaymentInfo(
      type: 'dynamic_qr',
      gateway: 'upi',
      timeoutSeconds: timeout,
      amount: session.amount,
      qr: PaymentQrData(
        upiUrl: session.qrData,
        qrUrl: '',
        displayUpiId: '',
        payeeName: '',
      ),
    );
    final order = PlacedPosOrder(
      id: session.orderId,
      orderNumber: session.orderNumber,
      total: session.amount,
      amountDue: session.amount,
      payment: payment,
    );
    final qrClose = await PosPaymentQrSheet.show(
      context,
      order: order,
      session: live,
      serverUrl: serverUrl,
      currency: pos.currency,
      initialPayment: payment,
      timeoutSeconds: timeout,
    );
    if (!mounted || qrClose == null) return;
    if (qrClose.cancelled) {
      _closeCart();
      return;
    }
    if (qrClose.held) {
      showPosSnackBar(
        context,
        context.posText(
          'qrHoldPendingSnack',
          'Payment pending. Customer QR is cleared — reopen it beside Scan.',
        ),
      );
      return;
    }
    final paid = qrClose.order;
    if (paid == null) return;
    showPosSnackBar(
      context,
      context.l10n.ordersPaymentReceived(paid.orderNumber),
    );
    _queueCheckoutPrints(orderId: paid.id, orderNumber: paid.orderNumber);
    pos.showCashierPlacedNotice(
      orderNumber: paid.orderNumber,
      orderId: paid.id,
    );
  }

  void _queueCheckoutPrints({
    required int orderId,
    required String orderNumber,
  }) {
    if (orderId <= 0) return;
    final jobs = context.read<PrintJobCoordinator>();
    unawaited(
      jobs.enqueueKot(
        orderId: orderId,
        orderNumber: orderNumber,
        source: 'pos',
        cashierCheckout: true,
      ),
    );
    unawaited(jobs.enqueueReceipt(orderId: orderId, orderNumber: orderNumber));
  }

  Future<void> _openScanToPrintDialog() async {
    final reference = await showPosScanToPrintDialog(context);
    if (reference == null || !mounted) return;
    await _handleScannedPayload(reference, orderOnly: true);
  }

  Future<void> _submitSearch(String raw) async {
    final added = await _handleScannedPayload(raw, quietMiss: true);
    if (!added || !mounted) return;
    _searchController.clear();
    context.read<PosController>().setSearchQuery('');
  }

  /// A connected scanner adds the menu item for that barcode.
  /// An order slip still prints only from the scan-to-print dialog, or when
  /// the code is an order reference and not a menu barcode.
  /// Returns true when the payload was a known item or a printed order.
  Future<bool> _handleScannedPayload(
    String payload, {
    bool quietMiss = false,
    bool orderOnly = false,
  }) async {
    final pos = context.read<PosController>();
    if (!orderOnly) {
      final match = pos.matchBarcode(payload);
      if (match != null) {
        return _addScannedItem(pos, match);
      }
    }

    final orderNumber = OrderBarcodeScan.parseOrderNumber(payload);
    if (orderNumber != null &&
        (orderOnly || OrderBarcodeScan.isOrderReference(payload))) {
      await _printScannedOrder(orderNumber);
      return true;
    }

    if (!quietMiss && mounted) {
      showPosSnackBar(
        context,
        'No menu item for barcode ${payload.trim()}',
        error: true,
      );
    }
    return false;
  }

  Future<bool> _addScannedItem(
    PosController pos,
    MenuBarcodeMatch match,
  ) async {
    final variant = match.variant;
    if (variant != null && match.item.modifiers.isEmpty) {
      final alreadyInCart = pos.cart.any(
        (line) =>
            line.menuItem.id == match.item.id && line.variant?.id == variant.id,
      );
      if (!alreadyInCart) {
        final ok = await confirmOutsideScheduleIfNeeded(context, match.item);
        if (!ok || !mounted) return true;
      }
      pos.addToCart(CartLine(menuItem: match.item, variant: variant));
      return true;
    }

    await _onItemTap(match.item);
    return true;
  }

  Future<void> _printScannedOrder(String orderNumber) async {
    if (_scanPrintBusy) return;

    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;

    if (!PosReceiptPrinter.isSupported) {
      showPosSnackBar(
        context,
        PosReceiptPrinter.unsupportedMessage,
        error: true,
      );
      return;
    }

    final alreadyPrinted = await ScanToPrintHistory.hasPrinted(
      branchId: session.branchId,
      orderNumber: orderNumber,
    );
    if (!mounted) return;
    if (alreadyPrinted) {
      await _showReceiptAlreadyPrintedDialog(orderNumber);
      return;
    }

    final jobs = context.read<PrintJobCoordinator>();
    setState(() => _scanPrintBusy = true);
    try {
      final handoff = await ScanToPrintSettings.clearHandoffOnScanPrint();
      await PosReceiptPrinter.printOrderByNumber(
        session: session,
        orderNumber: orderNumber,
        handoff: handoff,
      );
      await ScanToPrintHistory.markPrinted(
        branchId: session.branchId,
        orderNumber: orderNumber,
      );
      await jobs.completeHandPrinted(
        kind: PrintJobKind.receipt,
        orderNumber: orderNumber,
      );
      var handoffCleared = false;
      if (handoff && mounted) {
        handoffCleared = await context
            .read<KitchenController>()
            .clearHandoffForOrderNumber(orderNumber);
      }
      if (!mounted) return;
      context.read<PrinterStatusService>().refresh();
      showPosSnackBar(
        context,
        handoffCleared
            ? 'Printed $orderNumber and cleared the kitchen ticket'
            : context.l10n.printPrinted(orderNumber),
      );
    } on PrintSkipped catch (e) {
      if (!mounted) return;
      showPosSnackBar(context, e.message);
    } on PosApiException catch (e) {
      if (!mounted) return;
      if (e.isPrintingDisabled) {
        showPosSnackBar(context, e.message);
      } else if (e.statusCode == 404) {
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
      context.read<PrinterStatusService>().refresh(allowBluetoothScan: true);
      showPosErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _scanPrintBusy = false);
      }
    }
  }

  Future<void> _showReceiptAlreadyPrintedDialog(String orderNumber) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => PosDialogShell(
        title: 'Receipt already printed',
        icon: Icons.info_outline_rounded,
        headerColor: const Color(0xFFF59E0B),
        onClose: () => Navigator.pop(ctx),
        body: Text(
          'This receipt has already been printed ($orderNumber). If you need another copy, please ask the cashier.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: PosTheme.ink,
          ),
        ),
        footer: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printOfflineReceipt(
    PosBootstrap bootstrap,
    PendingOrder order,
  ) async {
    try {
      await PosReceiptPrinter.printOfflineKot(
        bootstrap: bootstrap,
        order: order,
      );
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
    try {
      await PosReceiptPrinter.printOfflineReceipt(
        bootstrap: bootstrap,
        order: order,
      );
      await PendingOrderStore.markPrinted(order.localUuid);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _openDayEndReports() async {
    if (!PosReceiptPrinter.isSupported) {
      showPosSnackBar(
        context,
        PosReceiptPrinter.unsupportedMessage,
        error: true,
      );
      return;
    }

    await DayEndReportsSheet.open(context, onPrint: _printThermalReport);
  }

  Future<void> _printThermalReport(String type) async {
    final pos = context.read<PosController>();
    final session = pos.session;
    final serverUrl = pos.serverUrl;
    if (session == null || serverUrl == null) {
      if (mounted) {
        showPosSnackBar(context, context.l10n.authNotSignedIn, error: true);
      }
      throw StateError(context.l10n.authNotSignedIn);
    }

    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      await PosReceiptPrinter.printThermalReport(
        session: session,
        serverUrl: serverUrl,
        type: type,
        dateFrom: today,
        dateTo: today,
      );
      if (!mounted) return;
      showPosSnackBar(context, context.l10n.reportsSentToPrinter);
    } catch (e) {
      if (mounted) {
        showPosErrorSnackBar(context, e);
      }
      rethrow;
    }
  }

  Future<void> _onPark() async {
    final pos = context.read<PosController>();
    try {
      final order = await pos.parkCurrentTicket();
      if (!mounted) return;
      showPosSnackBar(context, context.l10n.cartHeldSnack(order.orderNumber));
      _closeCart();
    } on PosApiException catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final accent = Theme.of(context).colorScheme.primary;
    final desktop = usePosDesktopLayout(context);
    final blocked = context.select((PosController p) => p.posBlocked);
    final billUnread = context.select(
      (PosController p) => p.registerBillUnreadCount,
    );
    final billBannerPending = context.select((PosController p) {
      final alert = p.registerBannerAlert;
      return alert != null && !alert.type.isNewOrderCue;
    });
    final paymentNoticePending = context.select(
      (PosController p) => p.paymentSessionNotice != null,
    );
    final canUseKitchen = context.select((PosController p) => p.canUseKitchen);
    final kotOpenCount = context.select((KitchenController k) => k.totalActive);
    if (billBannerPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeShowRegisterBillBanner(context.read<PosController>());
      });
    }
    if (paymentNoticePending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notice = context.read<PosController>().takePaymentSessionNotice();
        if (notice != null) {
          showPosSnackBar(context, notice);
        }
      });
    }

    final shell = PosOrderBarcodeListener(
      onScan: (payload) => unawaited(_handleScannedPayload(payload)),
      child: Scaffold(
        backgroundColor: PosTheme.canvas,
        appBar: PosRegisterAppBar(
          accent: accent,
          onOpenSettings: () => _selectMobileTab(5),
          onOpenDayEndReports: () {
            if (usePosHandheldLayout(context)) {
              _selectMobileTab(4);
              return;
            }
            _openDayEndReports();
          },
          onOpenOrders: _openOrders,
          onOpenDelivery: _openDeliveryOrders,
          onOpenPartnerOrders: _openPartnerOrders,
          onOpenTable: () => showPosTablePicker(context),
          onOpenNotifications: _openNotifications,
          notificationCount: billUnread,
          canUseKitchen: canUseKitchen,
          kotDockOpen: _kotDockOpen,
          kotOpenCount: kotOpenCount,
          onToggleKotDock: _toggleKotDock,
        ),
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OfflineBanner(),
                const PosOptionalUpdateBanner(),
                const PosPinSetupBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: blocked ? 0.38 : 1,
                        child: IgnorePointer(
                          ignoring: blocked,
                          child: usePosHandheldLayout(context)
                              ? _handheldTabs(accent)
                              : desktop
                              ? _desktopLayout(accent)
                              : _phoneLayout(accent),
                        ),
                      ),
                      if (blocked)
                        const Positioned.fill(child: ShiftOpenOverlay()),
                    ],
                  ),
                ),
              ],
            ),
            if (!desktop &&
                !usePosHandheldLayout(context) &&
                !_cartOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ViewCartPillHost(accent: accent, onTap: _openCart),
              ),
            if (usePosHandheldLayout(context) && _mobileTab == 0 && !blocked)
              Positioned(
                right: 16,
                bottom: 16,
                child: _MobileCartShortcut(onTap: _openCart),
              ),
            const NewOrderAlertBannerHost(),
          ],
        ),
        bottomNavigationBar: usePosHandheldLayout(context)
            ? PosMobileNavBar(
                index: _mobileTab,
                ordersCount: context.select(
                  (PosController p) => p.todayOrderCount,
                ),
                onSelected: _selectMobileTab,
              )
            : null,
      ),
    );

    if (blocked) {
      return Stack(children: [shell, const OrderPlacedNoticeHost()]);
    }

    return Stack(
      children: [
        Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.slash): _FocusSearchIntent(),
            SingleActivator(LogicalKeyboardKey.f2): _ParkIntent(),
            SingleActivator(LogicalKeyboardKey.f3): _PayIntent(),
            SingleActivator(LogicalKeyboardKey.enter, shift: true):
                _PayIntent(),
            SingleActivator(LogicalKeyboardKey.f4): _OpenHeldIntent(),
            SingleActivator(LogicalKeyboardKey.f5): _OpenHeldIntent(),
            SingleActivator(LogicalKeyboardKey.f6): _LockIntent(),
            SingleActivator(LogicalKeyboardKey.keyL, meta: true): _LockIntent(),
            SingleActivator(LogicalKeyboardKey.keyL, control: true):
                _LockIntent(),
            // Forward-delete (Windows/Linux) and Backspace (macOS "Delete").
            SingleActivator(LogicalKeyboardKey.delete, shift: true):
                _ClearCartIntent(),
            SingleActivator(LogicalKeyboardKey.backspace, shift: true):
                _ClearCartIntent(),
            SingleActivator(LogicalKeyboardKey.f11): _FullscreenIntent(),
            // macOS system-style fullscreen chord.
            SingleActivator(LogicalKeyboardKey.keyF, meta: true, control: true):
                _FullscreenIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
                onInvoke: (_) {
                  _focusSearch();
                  return null;
                },
              ),
              _OpenHeldIntent: CallbackAction<_OpenHeldIntent>(
                onInvoke: (_) {
                  _openHeldOrders();
                  return null;
                },
              ),
              _ParkIntent: CallbackAction<_ParkIntent>(
                onInvoke: (_) {
                  final pos = context.read<PosController>();
                  if (pos.cart.isNotEmpty && !pos.submitting) {
                    _onPark();
                  }
                  return null;
                },
              ),
              _PayIntent: CallbackAction<_PayIntent>(
                onInvoke: (_) {
                  final pos = context.read<PosController>();
                  if (pos.cart.isNotEmpty && !pos.submitting) {
                    _onPay(
                      quickMethod: context
                          .read<PosController>()
                          .cartQuickPayMethod,
                    );
                  }
                  return null;
                },
              ),
              _LockIntent: CallbackAction<_LockIntent>(
                onInvoke: (_) {
                  context.read<PosController>().lockSession();
                  return null;
                },
              ),
              _ClearCartIntent: CallbackAction<_ClearCartIntent>(
                onInvoke: (_) {
                  _clearCartShortcut();
                  return null;
                },
              ),
              _FullscreenIntent: CallbackAction<_FullscreenIntent>(
                onInvoke: (_) {
                  _toggleFullscreen();
                  return null;
                },
              ),
            },
            child: Focus(autofocus: true, child: shell),
          ),
        ),
        const OrderPlacedNoticeHost(),
      ],
    );
  }

  Widget _desktopLayout(Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = PosTheme.isShort(context);
        final canUseKitchen = context.select(
          (PosController p) => p.canUseKitchen,
        );
        final categoriesOnTop = context.select(
          (PosCategoryBarSettings s) => s.isTop,
        );
        final layout = resolvePosDesktopPanelLayout(
          totalWidth: constraints.maxWidth,
          kotOpen: _kotDockOpen && canUseKitchen,
          short: short,
          categoryRailVisible: !categoriesOnTop,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!categoriesOnTop)
              _PosCategoryRailHost(
                accent: accent,
                searchController: _searchController,
              ),
            Expanded(
              child: _menuColumn(accent, categoriesOnTop: categoriesOnTop),
            ),
            if (layout.kotColumnWidth > 0)
              SizedBox(
                width: layout.kotColumnWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: PosTheme.border.withValues(alpha: 0.8),
                      ),
                      right: BorderSide(
                        color: PosTheme.border.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  child: KitchenDockPanel(
                    splitCompact: layout.kotSplitCompact,
                    onClose: _toggleKotDock,
                  ),
                ),
              ),
            SizedBox(
              width: layout.cartWidth,
              child: PosCartPanel(
                compact: layout.cartCompact,
                splitCompact: layout.kotSplitCompact,
                onPay: () => _onPay(quickMethod: 'more'),
                onPayMethod: (method) => _onPay(quickMethod: method),
                onPark: _onPark,
                onOpenHeld: _openHeldOrders,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _phoneLayout(Color accent) {
    final top = context.watch<PosCategoryBarSettings>().isTop;
    if (!top) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PosCategoryRailHost(
            accent: accent,
            searchController: _searchController,
          ),
          Expanded(child: _menuColumn(accent)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PosCategoryRailHost(
          accent: accent,
          searchController: _searchController,
          horizontal: true,
        ),
        Expanded(child: _menuColumn(accent)),
      ],
    );
  }

  Widget _menuColumn(Color accent, {bool categoriesOnTop = false}) {
    return ColoredBox(
      color: PosTheme.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchStrip(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (q) => context.read<PosController>().setSearchQuery(q),
            onClear: () {
              _searchController.clear();
              context.read<PosController>().setSearchQuery('');
            },
            onSubmitted: (value) => unawaited(_submitSearch(value)),
            onScan: () => unawaited(_openScanToPrintDialog()),
            onHeldQr: _reopenHeldPaymentQr,
          ),
          if (categoriesOnTop)
            _PosCategoryRailHost(
              accent: accent,
              searchController: _searchController,
              horizontal: true,
            ),
          Expanded(
            child: _MenuScrollBody(accent: accent, onItemTap: _onItemTap),
          ),
        ],
      ),
    );
  }
}

class _PosCategoryRailHost extends StatelessWidget {
  const _PosCategoryRailHost({
    required this.accent,
    required this.searchController,
    this.horizontal = false,
  });

  final Color accent;
  final TextEditingController searchController;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final categories = context.select((PosController p) => p.categories);
    final activeCategoryId = context.select(
      (PosController p) => p.activeCategoryId,
    );
    final searchActive = context.select(
      (PosController p) => p.searchQuery.isNotEmpty,
    );
    final serverUrl = context.select(
      (PosController p) => p.serverUrl ?? p.session?.serverUrl,
    );
    final showCategoryImages = context.select(
      (PosCatalogLayoutSettings s) => s.showsCategoryImages,
    );

    return PosCategoryRail(
      categories: categories,
      activeCategoryId: activeCategoryId,
      accent: accent,
      serverUrl: serverUrl,
      showImages: showCategoryImages,
      horizontal: horizontal,
      searchActive: searchActive,
      onSelect: (id) {
        searchController.clear();
        final pos = context.read<PosController>();
        pos.setSearchQuery('');
        pos.selectCategory(id);
      },
    );
  }
}

class _SearchStrip extends StatefulWidget {
  const _SearchStrip({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.onSubmitted,
    this.onScan,
    this.onHeldQr,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onScan;
  final ValueChanged<PaymentSession>? onHeldQr;

  @override
  State<_SearchStrip> createState() => _SearchStripState();
}

class _SearchStripState extends State<_SearchStrip> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      widget.onChanged(value);
    });
  }

  void _onClear() {
    _debounce?.cancel();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(
          bottom: BorderSide(color: PosTheme.border.withValues(alpha: 0.9)),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: usePosHandheldLayout(context) ? 10 : 14,
        vertical: usePosHandheldLayout(context) ? 6 : 10,
      ),
      child: ListenableBuilder(
        listenable: PaymentSessionManager.instance,
        builder: (context, _) {
          final held = _pendingHeldQr();
          return PosSearchField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: _onQueryChanged,
            onClear: _onClear,
            onSubmitted: widget.onSubmitted,
            onScan: widget.onScan,
            voiceSearch: true,
            voiceItemNames: [
              for (final item in context.watch<PosController>().flatItems) ...[
                item.name,
                for (final translation in item.translations.values)
                  if (translation['name'] != null) translation['name']!,
              ],
            ],
            onHeldQr: held == null || widget.onHeldQr == null
                ? null
                : () => widget.onHeldQr!(held),
            heldQrLabel: held == null ? null : 'Pending UPI QR',
          );
        },
      ),
    );
  }

  PaymentSession? _pendingHeldQr() {
    final now = DateTime.now();
    PaymentSession? latest;
    for (final session in PaymentSessionManager.instance.activeSessions) {
      if (!session.heldForNewOrder || !now.isBefore(session.expiresAt)) {
        continue;
      }
      if (session.qrData.trim().isEmpty) continue;
      latest = session;
    }
    return latest;
  }
}

class _MenuScrollBody extends StatelessWidget {
  const _MenuScrollBody({required this.accent, required this.onItemTap});

  final Color accent;
  final ValueChanged<MenuItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final menuEmpty = context.select((PosController p) => p.menuItemsEmpty);
    final showPopular = context.select((PosController p) => p.showPopularStrip);
    final searchQuery = context.select((PosController p) => p.searchQuery);
    final items = context.select((PosController p) => p.itemsToDisplay);
    final popularItems = context.select((PosController p) => p.popularItems);
    final currency = context.select((PosController p) => p.currency);
    final serverUrl = context.select(
      (PosController p) => p.serverUrl ?? p.session?.serverUrl,
    );
    final categoryTitle = context.select(
      (PosController p) => p.activeCategoryTitle,
    );
    final categorySubtitle = context.select(
      (PosController p) => p.activeCategorySubtitle,
    );
    final cartQty = context.select((PosController p) => p.cartQtyByMenuItemId);
    final simpleLines = context.select(
      (PosController p) => p.simpleCartLineByMenuItemId,
    );
    final showItemImages = context.select(
      (PosCatalogLayoutSettings s) => s.showsItemImages,
    );
    final pos = context.read<PosController>();

    if (menuEmpty) {
      return PosEmptyState(
        icon: Icons.search_off_rounded,
        title: context.l10n.menuNoItemsTitle,
        subtitle: context.l10n.menuNoItemsSubtitle,
        accent: accent,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth = constraints.maxWidth;
        final handheld = usePosHandheldLayout(context);
        final crossAxisCount = posMenuGridCrossAxisCount(paneWidth);
        final screenSize = MediaQuery.sizeOf(context);
        final compactRegisterGrid = !handheld &&
            screenSize.width >= 900 && screenSize.width <= 1100 &&
            screenSize.height >= 700;

        return CustomScrollView(
          slivers: [
            if (showPopular && !handheld)
              SliverToBoxAdapter(
                child: _PopularSection(
                  items: popularItems,
                  currency: currency,
                  accent: accent,
                  serverUrl: serverUrl,
                  onTap: onItemTap,
                  qtyByItemId: cartQty,
                  simpleLineByItemId: simpleLines,
                  onIncrementSimple: pos.incrementSimpleCartLine,
                  onDecrementSimple: pos.decrementSimpleCartLine,
                  showImage: showItemImages,
                ),
              ),
            if (searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    context.l10n.menuSearchResults(searchQuery),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: PosTheme.ink,
                    ),
                  ),
                ),
              ),
            if (!handheld && searchQuery.isEmpty && items.isNotEmpty)
              SliverToBoxAdapter(
                child: _CategorySectionHeader(
                  categoryName: categoryTitle,
                  subtitle: categorySubtitle,
                ),
              ),
            if (items.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  handheld ? 10 : 16,
                  4,
                  handheld ? 10 : 16,
                  handheld ? 88 : 24,
                ),
                sliver: handheld && paneWidth < 220
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PosMenuItemCard(
                              handheld: true,
                              key: ValueKey(item.id),
                              item: item,
                              currency: currency,
                              accent: accent,
                              compact: true,
                              serverUrl: serverUrl,
                              showImage: showItemImages,
                              inTicketQty: cartQty[item.id] ?? 0,
                              simpleCartLine: simpleLines[item.id],
                              onTap: () => onItemTap(item),
                              onIncrementSimple: pos.incrementSimpleCartLine,
                              onDecrementSimple: pos.decrementSimpleCartLine,
                            ),
                          );
                        }, childCount: items.length),
                      )
                    : SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: handheld ? 2 : crossAxisCount,
                          mainAxisExtent: handheld
                              ? handheldMenuCardExtent(context, paneWidth)
                              : compactRegisterGrid ? 130 : null,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: posMenuGridChildAspectRatio(
                            paneWidth,
                            compact: true,
                            images: showItemImages,
                          ),
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = items[index];
                          return PosMenuItemCard(
                            handheld: handheld,
                            photoGrid: handheld,
                            key: ValueKey(item.id),
                            item: item,
                            currency: currency,
                            accent: accent,
                            compact: true,
                            serverUrl: serverUrl,
                            showImage: showItemImages,
                            inTicketQty: cartQty[item.id] ?? 0,
                            simpleCartLine: simpleLines[item.id],
                            onTap: () => onItemTap(item),
                            onIncrementSimple: pos.incrementSimpleCartLine,
                            onDecrementSimple: pos.decrementSimpleCartLine,
                          );
                        }, childCount: items.length),
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _PopularSection extends StatelessWidget {
  const _PopularSection({
    required this.items,
    required this.currency,
    required this.accent,
    required this.onTap,
    required this.qtyByItemId,
    required this.simpleLineByItemId,
    required this.onIncrementSimple,
    required this.onDecrementSimple,
    this.serverUrl,
    this.showImage = true,
  });

  final List<MenuItem> items;
  final String currency;
  final Color accent;
  final ValueChanged<MenuItem> onTap;
  final Map<int, int> qtyByItemId;
  final Map<int, CartLine?> simpleLineByItemId;
  final ValueChanged<CartLine> onIncrementSimple;
  final ValueChanged<CartLine> onDecrementSimple;
  final String? serverUrl;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final short = PosTheme.isShort(context);
    final soft = posAccentSoft(accent);
    final stripHeight = showImage
        ? (short ? 148.0 : 200.0)
        : (short ? 148.0 : 168.0);
    final cardWidth = short ? 120.0 : 144.0;
    final pad = short
        ? const EdgeInsets.fromLTRB(12, 8, 12, 10)
        : const EdgeInsets.fromLTRB(16, 12, 16, 16);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, short ? 4 : 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: soft.bg,
          borderRadius: BorderRadius.circular(PosTheme.radiusLg),
          border: Border.all(color: soft.fg.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: short ? 28 : 36,
                    height: short ? 28 : 36,
                    decoration: BoxDecoration(
                      color: soft.bg,
                      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
                      border: Border.all(
                        color: soft.fg.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: short ? 14 : 18,
                      color: soft.fg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.menuPopularTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: PosTheme.ink,
                          ),
                        ),
                        if (!short)
                          Text(
                            context.l10n.menuPopularSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: PosTheme.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: short ? 8 : 12),
              SizedBox(
                height: stripHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => SizedBox(width: short ? 12 : 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SizedBox(
                      width: cardWidth,
                      height: stripHeight,
                      child: PosMenuItemCard(
                        key: ValueKey('popular-${item.id}'),
                        item: item,
                        currency: currency,
                        accent: accent,
                        serverUrl: serverUrl,
                        showImage: showImage,
                        compact: true,
                        inTicketQty: qtyByItemId[item.id] ?? 0,
                        simpleCartLine: simpleLineByItemId[item.id],
                        onTap: () => onTap(item),
                        onIncrementSimple: onIncrementSimple,
                        onDecrementSimple: onDecrementSimple,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({
    required this.categoryName,
    required this.subtitle,
  });

  final String categoryName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        usePosHandheldLayout(context) ? 6 : 12,
      ),
      child: Row(
        children: [
          Container(
            width: usePosHandheldLayout(context) ? 24 : 36,
            height: usePosHandheldLayout(context) ? 24 : 36,
            decoration: BoxDecoration(
              color: PosTheme.searchFill,
              borderRadius: BorderRadius.circular(PosTheme.radiusMd),
              border: Border.all(color: PosTheme.border),
            ),
            child: Icon(
              Icons.grid_view_rounded,
              size: 18,
              color: PosTheme.inkMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: PosTheme.ink,
                  ),
                ),
                if (!usePosHandheldLayout(context))
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: PosTheme.inkMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCartShortcut extends StatelessWidget {
  const _MobileCartShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = context.select((PosController p) => p.cartItemCount);
    if (count <= 0) return const SizedBox.shrink();
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: const Color(0xFFE64B58),
      textColor: Colors.white,
      child: Material(
        color: const Color(0xFF2E7D32),
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Tooltip(
              message: context.l10n.shellViewCart,
              child: const Icon(
                Icons.shopping_bag_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewCartPillHost extends StatelessWidget {
  const _ViewCartPillHost({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = context.select((PosController p) => p.cartItemCount);
    if (count <= 0) return const SizedBox.shrink();
    return PosCartSummaryBar(accent: accent, onTap: onTap);
  }
}

class _MobileCartSheet extends StatelessWidget {
  const _MobileCartSheet({
    required this.onClose,
    required this.onPay,
    this.onPayMethod,
    required this.onPark,
    required this.onOpenHeld,
  });

  final VoidCallback onClose;
  final VoidCallback onPay;
  final ValueChanged<String>? onPayMethod;
  final VoidCallback onPark;
  final VoidCallback onOpenHeld;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final l10n = context.l10n;

    return PosBottomSheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: soft.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    color: soft.fg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.cartCurrentTicket,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Material(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.close_rounded, color: soft.fg),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PosCartPanel(
              compact: true,
              onPay: onPay,
              onPayMethod: onPayMethod,
              onPark: onPark,
              onOpenHeld: onOpenHeld,
            ),
          ),
        ],
      ),
    );
  }
}

class PosRegisterAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PosRegisterAppBar({
    super.key,
    required this.accent,
    required this.onOpenDayEndReports,
    required this.onOpenOrders,
    required this.onOpenDelivery,
    required this.onOpenPartnerOrders,
    required this.onOpenTable,
    required this.onOpenNotifications,
    required this.notificationCount,
    this.canUseKitchen = false,
    this.kotDockOpen = false,
    this.kotOpenCount = 0,
    this.onToggleKotDock,
    this.statusControl,
    this.onOpenSettings,
  });

  final Color accent;
  final VoidCallback onOpenDayEndReports;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenDelivery;
  final ValueChanged<String> onOpenPartnerOrders;
  final VoidCallback onOpenTable;
  final VoidCallback onOpenNotifications;
  final int notificationCount;
  final bool canUseKitchen;
  final bool kotDockOpen;
  final int kotOpenCount;
  final VoidCallback? onToggleKotDock;
  final Widget? statusControl;
  final VoidCallback? onOpenSettings;

  @override
  Size get preferredSize => Size.fromHeight(PosTheme.headerPx(56));

  @override
  Widget build(BuildContext context) {
    final ordersCount = context.select((PosController p) => p.todayOrderCount);
    final marketplacePlatforms = context.select(
      (PosController p) =>
          p.bootstrap?.marketplacePlatforms ??
          const <MarketplacePlatformInfo>[],
    );
    final marketplaceCounts = context.select(
      (PosController p) => p.marketplaceOpenOrderCounts,
    );
    final tableId = context.select((PosController p) => p.tableId);
    final selectedTableLabel = context.select(
      (PosController p) => p.tableLabel,
    );
    final hasTable = tableId != null;
    final hasPin = context.select(
      (PosController p) => p.session?.hasPosPin == true,
    );
    final restaurantName = context.select(
      (PosController p) => p.bootstrap?.restaurant.name,
    );
    final branchName = context.select(
      (PosController p) => p.bootstrap?.branch.name,
    );
    final staffName = context.select(
      (PosController p) => p.session?.userName?.trim(),
    );
    final logoRawUrl = context.select(
      (PosController p) => p.bootstrap?.restaurant.logoUrl,
    );
    final serverUrl = context.select((PosController p) => p.session?.serverUrl);
    final terminalCount = context.select(
      (PosController p) => p.bootstrap?.posTerminals.length ?? 0,
    );
    final pendingOrderCount = context.select(
      (PosController p) => p.pendingOrderCount,
    );
    final checkingForUpdates = context.select(
      (PosController p) => p.checkingForUpdates,
    );
    final canUseCaptain = context.select((PosController p) => p.canUseCaptain);
    final canChooseWorkMode = context.select(
      (PosController p) => p.canChooseWorkMode,
    );
    final canChangeLocation = context.select(
      (PosController p) => p.canChangeLocation,
    );
    final hasDeviceBinding = context.select(
      (PosController p) => p.deviceBinding != null,
    );
    final showLanguageSwitcher = context.select(
      (PosLocaleController c) => c.showSwitcher,
    );
    context.select((PosLocaleController c) => c.catalogGeneration);
    final pos = context.read<PosController>();
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < PosTheme.compactWidthBreakpoint;
    final handheld = usePosHandheldLayout(context);
    final allowDelivery = context.select(
      (PosController p) => p.bootstrap?.allowsPosDelivery ?? true,
    );
    // Wide registers: show text next to key header actions.
    final showActionLabels = width >= 1280;
    final logoUrl = resolveMediaUrl(logoRawUrl, serverUrl: serverUrl);
    final canAccessAdmin = context.select(
      (PosController p) =>
          p.bootstrap?.adminCapabilities.canAccessAdmin == true,
    );
    final canViewMenu = context.select((PosController p) {
      final caps = p.bootstrap?.adminCapabilities;
      return caps?.canViewMenu == true ||
          caps?.canManageMenu == true ||
          caps?.canManageMenuItems == true;
    });
    final canManageStore = context.select(
      (PosController p) =>
          p.bootstrap?.adminCapabilities.canManageSettings == true,
    );
    final guestOrdering = context.select(
      (PosController p) =>
          p.bootstrap?.guestOrdering ?? const PosGuestOrdering(),
    );
    final storeAccepting = guestOrdering.acceptOnlineOrders;
    final storeStatusLabel = guestOrdering.open
        ? l10n.storeOpen
        : (guestOrdering.isPaused || !storeAccepting
              ? l10n.storePaused
              : l10n.storeClosed);
    final titleText = restaurantName ?? 'POS';
    final titleTooltip = [
      if (restaurantName != null && restaurantName.isNotEmpty) restaurantName,
      if (branchName != null && branchName.isNotEmpty) branchName,
      if (staffName != null && staffName.isNotEmpty) staffName,
    ].join(' · ');

    return AppBar(
      toolbarHeight: PosTheme.headerPx(56),
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: PosTheme.canvas,
      surfaceTintColor: Colors.transparent,
      titleSpacing: compact ? 10 : 14,
      shape: Border(
        bottom: BorderSide(color: PosTheme.border.withValues(alpha: 0.7)),
      ),
      title: handheld
          ? Row(
              children: [
                if (width >= 400) ...[
                  _HeaderBrandMark(
                    logoUrl: logoUrl,
                    accent: accent,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _HeaderBrandMark(
                  logoUrl: logoUrl,
                  accent: accent,
                  compact: compact,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Tooltip(
                    message: titleTooltip.isEmpty ? 'POS' : titleTooltip,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.25,
                            height: 1.15,
                            color: PosTheme.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (branchName != null && branchName.isNotEmpty)
                          Text(
                            branchName,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: PosTheme.inkMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const PosShiftControl(),
              ],
            ),
      actions: [
        _HeaderSegment(
          children: [
            statusControl ??
                PosSystemStatusButton(showLabel: showActionLabels && !compact),
          ],
        ),
        if (!handheld) ...[
          OfflineStatusIndicator(compact: true),
          const PosPrinterWarningButton(),
          const SizedBox(width: 6),
        ],
        _HeaderSegment(
          children: [
            if (canUseKitchen && onToggleKotDock != null)
              _HeaderIconButton(
                tooltip: context.posText('kitchenDockToggle', 'Kitchen orders'),
                label: showActionLabels
                    ? context.posText('kitchenDockTitle', 'Kitchen')
                    : null,
                icon: kotDockOpen
                    ? Icons.soup_kitchen_rounded
                    : Icons.soup_kitchen_outlined,
                iconColor: kotOpenCount > 0
                    ? const Color(0xFFDC2626)
                    : kotDockOpen
                    ? accent
                    : null,
                badgeCount: kotOpenCount,
                badgeColor: const Color(0xFFDC2626),
                onPressed: onToggleKotDock!,
              ),
            if (!handheld && canAccessAdmin && canViewMenu)
              _HeaderIconButton(
                tooltip: l10n.adminMenu,
                label: showActionLabels ? l10n.adminMenu : null,
                icon: Icons.menu_book_outlined,
                onPressed: () => openPosAdminMenuSheet(context),
              ),
            _HeaderIconButton(
              tooltip: hasTable
                  ? (selectedTableLabel ??
                        context.posText('shellTable', 'Table'))
                  : context.posText('cartSelectTable', 'Select table'),
              label: handheld
                  ? null
                  : hasTable &&
                        selectedTableLabel != null &&
                        selectedTableLabel.isNotEmpty
                  ? selectedTableLabel
                  : context.posText('shellTable', 'Table'),
              icon: Icons.table_restaurant_rounded,
              iconColor: hasTable ? accent : null,
              onPressed: onOpenTable,
            ),
            if (!handheld && allowDelivery)
              _HeaderIconButton(
                tooltip: context.posText(
                  'shellDeliveryOrders',
                  'Delivery orders',
                ),
                label: context.posText('shellDelivery', 'Delivery'),
                icon: Icons.delivery_dining_rounded,
                iconColor: const Color(0xFFEA580C),
                badgeCount: marketplaceCounts.values.fold<int>(
                  0,
                  (sum, count) => sum + count,
                ),
                badgeColor: const Color(0xFFEA580C),
                onPressed: onOpenDelivery,
              ),
            if (!handheld)
              _HeaderIconButton(
                tooltip: l10n.shellOrders,
                label: showActionLabels ? l10n.shellOrders : null,
                icon: Icons.receipt_long_rounded,
                badgeCount: ordersCount,
                badgeColor: accent,
                onPressed: onOpenOrders,
              ),
            if (!handheld)
              _HeaderIconButton(
                tooltip: l10n.waiterNavAlerts,
                icon: notificationCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                iconColor: notificationCount > 0
                    ? const Color(0xFFD97706)
                    : null,
                badgeCount: notificationCount,
                badgeColor: const Color(0xFFD97706),
                onPressed: onOpenNotifications,
              ),
            if (!handheld)
              _HeaderIconButton(
                tooltip: l10n.shellRefreshMenu,
                icon: Icons.refresh_rounded,
                onPressed: () => _refreshMenu(context, pos, l10n),
              ),
          ],
        ),
        const SizedBox(width: 6),
        _HeaderSegment(
            children: [
              const _HeaderHelpButton(),
              if (handheld)
                _HeaderIconButton(
                  tooltip: 'Settings',
                  icon: Icons.settings_rounded,
                  onPressed: onOpenSettings ?? () {},
                )
              else PosMoreMenuButton(
                accent: accent,
                embedded: true,
                tooltip: l10n.shellMore,
                sections: buildPosMoreMenuSections(
                  context: context,
                  l10n: l10n,
                  storeAccepting: storeAccepting,
                  storeStatusLabel: storeStatusLabel,
                  canManageStore: canManageStore,
                  canAccessAdmin: canAccessAdmin,
                  canViewMenu: canViewMenu,
                  marketplacePlatforms: marketplacePlatforms,
                  showLanguageSwitcher: showLanguageSwitcher,
                  terminalCount: terminalCount,
                  canChangeLocation: canChangeLocation,
                  hasPin: hasPin,
                  canUseCaptain: canUseCaptain,
                  canChooseWorkMode: canChooseWorkMode,
                  checkingForUpdates: checkingForUpdates,
                  pendingOrderCount: pendingOrderCount,
                  hasDeviceBinding: hasDeviceBinding,
                  includeShortcuts: !compact,
                ),
                onSelected: (value) async {
                  await _handleMoreMenuAction(
                    context: context,
                    pos: pos,
                    l10n: l10n,
                    value: value,
                    hasPin: hasPin,
                    onOpenPartnerOrders: onOpenPartnerOrders,
                    onOpenDayEndReports: onOpenDayEndReports,
                  );
                },
              ),
            ],
          ),
        const SizedBox(width: 10),
      ],
    );
  }

  Future<void> _refreshMenu(
    BuildContext context,
    PosController pos,
    AppLocalizations l10n,
  ) async {
    try {
      await pos.refreshBootstrap();
      if (context.mounted) {
        showPosSnackBar(context, l10n.shellMenuRefreshed);
      }
    } catch (e) {
      if (context.mounted) {
        showPosErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _handleMoreMenuAction({
    required BuildContext context,
    required PosController pos,
    required AppLocalizations l10n,
    required String value,
    required bool hasPin,
    required ValueChanged<String> onOpenPartnerOrders,
    required VoidCallback onOpenDayEndReports,
  }) {
    return handlePosRegisterMoreAction(
      context: context,
      pos: pos,
      l10n: l10n,
      value: value,
      hasPin: hasPin,
      onOpenPartnerOrders: onOpenPartnerOrders,
      onOpenDayEndReports: onOpenDayEndReports,
      onOpenNotifications: onOpenNotifications,
      onOpenDelivery: onOpenDelivery,
      onRefreshMenu: () => _refreshMenu(context, pos, l10n),
      onOpenCustomerDisplay: () => showCustomerDisplayStatusDialog(context),
    );
  }
}

class _HeaderBrandMark extends StatelessWidget {
  const _HeaderBrandMark({
    required this.logoUrl,
    required this.accent,
    required this.compact,
  });

  final String? logoUrl;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    if (logoUrl == null) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: soft.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.storefront_rounded, color: soft.fg, size: 18),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosTheme.logoPlate,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PosTheme.logoPlateBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: PosNetworkLogo(
          imageUrl: logoUrl!,
          maxWidth: compact ? 64 : 88,
          maxHeight: 28,
          portraitSide: 28,
          alignment: Alignment.center,
          errorWidget: (context, url, error) =>
              Icon(Icons.storefront_rounded, color: soft.fg, size: 18),
          placeholder: (context, url) => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

/// Soft bordered group that holds related header actions.
class _HeaderSegment extends StatelessWidget {
  const _HeaderSegment({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(const _HeaderSegmentDivider());
      }
    }

    return Container(
      height: usePosHandheldLayout(context) ? 44 : 38,
      margin: EdgeInsets.symmetric(
        vertical: usePosHandheldLayout(context) ? 6 : 9,
      ),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: PosTheme.isDark ? 0.18 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

class _HeaderSegmentDivider extends StatelessWidget {
  const _HeaderSegmentDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: 18,
        color: PosTheme.border.withValues(alpha: 0.9),
      ),
    );
  }
}

class _HeaderHelpButton extends StatelessWidget {
  const _HeaderHelpButton();

  static const _phone = '9988223919';
  static const _mail = 'hello@selfx.in';

  void _open(Uri uri) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final handheld = usePosHandheldLayout(context);
    final fg = PosTheme.ink.withValues(alpha: 0.78);
    return PopupMenuButton<void>(
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      tooltip: 'Help',
      color: PosTheme.surface,
      elevation: 10,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: PosTheme.border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          height: 58,
          onTap: () => _open(Uri.parse('tel:+91$_phone')),
          child: const _HelpMenuRow(
            icon: Icons.call_rounded,
            label: 'Phone',
            value: _phone,
          ),
        ),
        PopupMenuItem<void>(
          height: 58,
          onTap: () => _open(Uri.parse('mailto:$_mail')),
          child: const _HelpMenuRow(
            icon: Icons.mail_outline_rounded,
            label: 'Mail',
            value: _mail,
          ),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: handheld ? 13 : PosTheme.headerPx(10),
        ),
        child: Icon(Icons.phone_rounded, size: PosTheme.headerPx(18), color: fg),
      ),
    );
  }
}

class _HelpMenuRow extends StatelessWidget {
  const _HelpMenuRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PosTheme.ink),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PosTheme.inkMuted,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: PosTheme.ink,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Flat icon control used inside a [_HeaderSegment].
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.label,
    this.badgeCount = 0,
    this.badgeColor,
    this.iconColor,
  });

  final String tooltip;
  final String? label;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
  final Color? badgeColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fg = iconColor ?? PosTheme.ink.withValues(alpha: 0.78);
    final countColor = badgeColor ?? Theme.of(context).colorScheme.primary;
    final badge = badgeCount > 9 ? '9+' : '$badgeCount';
    final showLabel = label != null && label!.trim().isNotEmpty;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: PosTheme.surfaceMuted,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: usePosHandheldLayout(context)
                  ? 13
                  : PosTheme.headerPx(showLabel ? 12 : 10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: badgeCount > 0,
                  backgroundColor: countColor,
                  smallSize: 8,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  label: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  child: Icon(icon, size: PosTheme.headerPx(18), color: fg),
                ),
                if (showLabel) ...[
                  SizedBox(width: PosTheme.headerPx(6)),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: PosTheme.headerPx(12.5),
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showCustomerDisplayStatusDialog(BuildContext context) async {
  final title = context.posText('shellCustomerDisplay', 'Customer display');
  WindowsCustomerDisplayStatus? status;
  Object? error;
  try {
    status = await CustomerDisplayBroker.instance.hardwareStatus();
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final connected = status?.connected == true;
      final message = error != null
          ? error.toString()
          : (status?.message ??
                dialogContext.posText(
                  'shellCustomerDisplayUnavailable',
                  'No USB customer display is connected.',
                ));
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              connected
                  ? dialogContext.posText(
                      'shellCustomerDisplayConnected',
                      'Connected',
                    )
                  : dialogContext.posText(
                      'shellCustomerDisplayDisconnected',
                      'Not connected',
                    ),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: connected
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB45309),
              ),
            ),
            const SizedBox(height: 8),
            Text(message),
            if (status?.port != null && status!.port!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(status.port!),
            ],
            if (status?.device != null && status!.device!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(status.device!.toUpperCase()),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.commonClose),
          ),
        ],
      );
    },
  );
}
