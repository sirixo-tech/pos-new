import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/pos_app_info.dart';
import '../../providers/pos_controller.dart';
import '../../services/customer_display/customer_display_controller.dart';
import '../../services/customer_display/customer_display_models.dart';
import '../../services/customer_display/customer_voice_service.dart';
import '../../services/pos_display_mode.dart';
import '../../widgets/pos_ui.dart';

extension _CustomerDisplayTr on BuildContext {
  String tr(String value) => value;
}

class CustomerDisplayPage extends StatefulWidget {
  const CustomerDisplayPage({super.key});

  static const routePath = '/customer-display';

  @override
  State<CustomerDisplayPage> createState() => _CustomerDisplayPageState();
}

class _CustomerDisplayPageState extends State<CustomerDisplayPage> {
  Timer? _clockTimer;
  late final CustomerVoiceService _voiceService;
  late final CustomerDisplayController _controller;
  DateTime _now = DateTime.now();
  bool _fullscreen = true;
  bool _controlsVisible = false;

  @override
  void initState() {
    super.initState();
    final pos = context.read<PosController>();
    _voiceService = CustomerVoiceService.instance;
    unawaited(_voiceService.loadSettings());
    _voiceService.setCustomerScreenActive(true);
    _controller = CustomerDisplayController(
      serverUrl: pos.serverUrl ?? '',
      voice: _voiceService,
      session: pos.session,
      bootstrap: pos.bootstrap,
      terminal: pos.selectedTerminal,
    );
    _controller.addListener(_onControllerTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_controller.showOrderBoard());
      }
    });
    unawaited(PosDisplayMode.setEnabled(true));
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() => _now = DateTime.now());
      },
    );
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _controller.removeListener(_onControllerTick);
    _controller.dispose();
    _voiceService.setCustomerScreenActive(false);
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return MouseRegion(
      onEnter: (_) => setState(() => _controlsVisible = true),
      onExit: (_) => setState(() => _controlsVisible = false),
      child: Scaffold(
        backgroundColor: _DisplayColors.background,
        body: Stack(
          children: [
            const _GridBackdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      _TopBar(
                        state: state,
                        now: _now,
                        compact: constraints.maxWidth < 900,
                        controlsVisible:
                            _controlsVisible || constraints.maxWidth < 900,
                        fullscreen: _fullscreen,
                        onKitchenDisplay: _returnToKitchenDisplay,
                        onSetup: () => _showSetupSheet(context, state),
                        onFullscreen: _toggleFullscreen,
                        onLogout: _exitTokenDisplayToPos,
                        voiceEnabled: _voiceService.isEnabled,
                        onToggleVoice: () async {
                          final next = !_voiceService.isEnabled;
                          await _voiceService.setEnabled(next);
                          if (next) unawaited(_voiceService.testAnnouncement('1'));
                          if (!context.mounted) return;
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                next
                                    ? 'Voice announcements enabled (Testing Token 1)'
                                    : 'Voice announcements muted',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const _InstructionBand(),
                      if (state.errorMessage != null)
                        _ErrorBand(
                          message: state.errorMessage!,
                          onRetry: () => unawaited(_controller.refresh()),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(
                            constraints.maxWidth < 900 ? 12 : 18,
                          ),
                          child: _OrderHistoryPanel(
                            preparing: state.preparing,
                            ready: state.ready,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // The order board is useful even before its first poll completes:
            // it can immediately show the empty Preparing/Ready lanes and its
            // controls. Do not cover the entire customer-facing screen during
            // initial or background API work.
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    await PosDisplayMode.toggle();
  }

  void _exitTokenDisplayToPos() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  void _returnToKitchenDisplay() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _showSetupSheet(
    BuildContext context,
    CustomerDisplayState state,
  ) async {
    final slugController = TextEditingController(text: state.restaurantSlug);
    final branchController = TextEditingController(
      text: state.branchId > 0 ? state.branchId.toString() : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SetupSheet(
          slugController: slugController,
          branchController: branchController,
          isSaving: state.isSavingSetup,
          onSave: () async {
            await _controller.saveSetup(
                  restaurantSlug: slugController.text,
                  branchId: int.tryParse(branchController.text.trim()) ?? 0,
                  terminalCode: state.terminalCode,
                  syncToken: state.syncToken,
                );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }
}

class CustomerCartDisplayPage extends StatefulWidget {
  const CustomerCartDisplayPage({super.key, this.branchId, this.terminalCode});

  static const routePath = '/customer-cart-display';

  static String routeFor({
    required int branchId,
    required String terminalCode,
  }) {
    return '/order/oneness/display/$branchId/${Uri.encodeComponent(terminalCode)}';
  }

  final int? branchId;
  final String? terminalCode;

  @override
  State<CustomerCartDisplayPage> createState() =>
      _CustomerCartDisplayPageState();
}

class _CustomerCartDisplayPageState extends State<CustomerCartDisplayPage> {
  Timer? _clockTimer;
  late final CustomerDisplayController _controller;
  late final CustomerVoiceService _voiceService;
  DateTime _now = DateTime.now();
  bool _fullscreen = true;

  @override
  void initState() {
    super.initState();
    final pos = context.read<PosController>();
    _voiceService = CustomerVoiceService.instance;
    unawaited(_voiceService.loadSettings());
    _controller = CustomerDisplayController(
      serverUrl: pos.serverUrl ?? '',
      voice: _voiceService,
      session: pos.session,
      bootstrap: pos.bootstrap,
      terminal: pos.selectedTerminal,
    );
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _controller.showCartDisplay(
            branchId: widget.branchId,
            terminalCode: widget.terminalCode,
          ),
        );
      }
    });
    unawaited(PosDisplayMode.setEnabled(true));
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void didUpdateWidget(covariant CustomerCartDisplayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId ||
        oldWidget.terminalCode != widget.terminalCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            _controller.showCartDisplay(
              branchId: widget.branchId,
              terminalCode: widget.terminalCode,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _controller.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 760;

    return Scaffold(
      backgroundColor: _CartDisplayColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _CartDisplayBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 18 : 28,
                    vertical: compact ? 18 : 34,
                  ),
                  child: Column(
                    children: [
                      _CartDisplayTopBar(
                        state: state,
                        now: _now,
                        fullscreen: _fullscreen,
                        onFullscreen: _toggleFullscreen,
                        onExitToPos: _exitToPos,
                      ),
                      SizedBox(height: compact ? 26 : 42),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _CartDisplayContent(
                            state: state,
                            compact: compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (state.isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _CartDisplayColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    await PosDisplayMode.toggle();
  }

  Future<void> _exitToPos() async {
    final shouldExit = await showPosConfirmDialog(
      context,
      title: 'Exit customer display?',
      message: 'Return to the POS screen?',
      confirmLabel: 'Go to POS',
    );
    if (!shouldExit || !mounted) return;
    Navigator.of(context).maybePop();
  }
}

class _CartDisplayTopBar extends StatelessWidget {
  const _CartDisplayTopBar({
    required this.state,
    required this.now,
    required this.fullscreen,
    required this.onFullscreen,
    required this.onExitToPos,
  });

  final CustomerDisplayState state;
  final DateTime now;
  final bool fullscreen;
  final VoidCallback onFullscreen;
  final VoidCallback onExitToPos;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(now);
    final date = DateFormat('EEEE d MMMM').format(now);
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE9E4F8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset(
                PosAppInfo.emblemAsset,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.storefront_rounded, color: Colors.white),
              ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.restaurantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _CartDisplayColors.accent,
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${state.branchName} · ${state.terminalCode}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              date,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(width: 18),
        Tooltip(
          message: fullscreen ? 'Exit fullscreen' : 'Fullscreen',
          child: SizedBox.square(
            dimension: 48,
            child: IconButton(
              onPressed: onFullscreen,
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Back to POS',
          child: SizedBox.square(
            dimension: 48,
            child: IconButton(
              onPressed: onExitToPos,
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartDisplayContent extends StatelessWidget {
  const _CartDisplayContent({required this.state, required this.compact});

  final CustomerDisplayState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cart = state.cart;
    final items = cart.items;
    final money = NumberFormat.simpleCurrency(name: cart.currency);
    final total = cart.total > 0
        ? cart.total
        : items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final subtotal = cart.subtotal > 0 ? cart.subtotal : total;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CartItemsCard(items: items, money: money, compact: compact),
        const SizedBox(height: 20),
        _CartTotalsCard(subtotal: subtotal, total: total, money: money),
        const SizedBox(height: 44),
        Text(
          context.tr('Thank you for dining with us!'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr(
            items.isEmpty
                ? 'Your order will appear here once items are added.'
                : 'Please proceed to payment to finalize your order.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 18),
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _CartItemsCard extends StatelessWidget {
  const _CartItemsCard({
    required this.items,
    required this.money,
    required this.compact,
  });

  final List<CustomerCartItem> items;
  final NumberFormat money;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 34,
              compact ? 20 : 28,
              compact ? 18 : 34,
              compact ? 18 : 26,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDE2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    color: _CartDisplayColors.accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    context.tr('Review Your Order'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF030712),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _CartDisplayColors.accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55FF6B1A),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Text(
                    '${items.length} item${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 56,
            color: const Color(0xFFF8FAFC),
            padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 34),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(context.tr('QTY'), style: _cartHeaderStyle),
                ),
                Expanded(
                  child: Text(context.tr('ITEM NAME'), style: _cartHeaderStyle),
                ),
                SizedBox(
                  width: 132,
                  child: Text(
                    context.tr('AMOUNT'),
                    textAlign: TextAlign.right,
                    style: _cartHeaderStyle,
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
              child: Text(
                context.tr('No items in the cart'),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            for (var index = 0; index < items.length; index += 1)
              _CartItemRow(
                item: items[index],
                money: money,
                compact: compact,
                showDivider: index != items.length - 1,
              ),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.money,
    required this.compact,
    required this.showDivider,
  });

  final CustomerCartItem item;
  final NumberFormat money;
  final bool compact;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 82 : 96,
      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 34),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EC),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFFFD1B8)),
                ),
                child: Text(
                  item.quantity.toString(),
                  style: const TextStyle(
                    color: _CartDisplayColors.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 21,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 132,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                money.format(item.lineTotal),
                style: const TextStyle(
                  color: Color(0xFF030712),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartTotalsCard extends StatelessWidget {
  const _CartTotalsCard({
    required this.subtotal,
    required this.total,
    required this.money,
  });

  final double subtotal;
  final double total;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(34, 26, 34, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Subtotal'),
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                money.format(subtotal),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  context.tr('Grand Total'),
                  style: const TextStyle(
                    color: Color(0xFF030712),
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money.format(total),
                  style: const TextStyle(
                    color: _CartDisplayColors.accent,
                    fontSize: 44,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartDisplayBackdrop extends StatelessWidget {
  const _CartDisplayBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.25),
          radius: 0.78,
          colors: [
            _CartDisplayColors.accent.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

const _cartHeaderStyle = TextStyle(
  color: Color(0xFF64748B),
  fontSize: 14,
  letterSpacing: 1.8,
  fontWeight: FontWeight.w900,
);

class _CartDisplayColors {
  const _CartDisplayColors._();

  static const background = Color(0xFFFEFEFF);
  static const accent = Color(0xFFFF6B1A);
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.now,
    required this.compact,
    required this.controlsVisible,
    required this.fullscreen,
    required this.onKitchenDisplay,
    required this.onSetup,
    required this.onFullscreen,
    required this.onLogout,
    required this.voiceEnabled,
    required this.onToggleVoice,
  });

  final CustomerDisplayState state;
  final DateTime now;
  final bool compact;
  final bool controlsVisible;
  final bool fullscreen;
  final VoidCallback onKitchenDisplay;
  final VoidCallback onSetup;
  final VoidCallback onFullscreen;
  final VoidCallback onLogout;
  final bool voiceEnabled;
  final VoidCallback onToggleVoice;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm:ss').format(now);
    final date = DateFormat('EEE d MMM').format(now).toUpperCase();
    final isVoiceEnabled = voiceEnabled;

    return Container(
      height: compact ? 68 : 76,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
      decoration: const BoxDecoration(
        color: _DisplayColors.background,
        border: Border(bottom: BorderSide(color: _DisplayColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 40 : 44,
            height: compact ? 40 : 44,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF17171B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E2E35)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x6634D399),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                PosAppInfo.emblemAsset,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.storefront_rounded, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  state.branchName,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: _DisplayColors.muted,
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) _ConnectionPill(online: state.errorMessage == null),
          if (!compact) const SizedBox(width: 10),
          _ClockCard(time: time, date: date, compact: compact),
          SizedBox(width: compact ? 6 : 10),
          _KitchenDisplayButton(onPressed: onKitchenDisplay, compact: compact),
          if (!compact) ...[
          const SizedBox(width: 10),
          _HoverControls(
            visible: controlsVisible,
            fullscreen: fullscreen,
            voiceEnabled: isVoiceEnabled,
            onToggleVoice: onToggleVoice,
            onSetup: onSetup,
            onFullscreen: onFullscreen,
            onLogout: onLogout,
          ),
          ] else ...[
            const SizedBox(width: 6),
            _CompactDisplayMenu(
              fullscreen: fullscreen,
              voiceEnabled: isVoiceEnabled,
              onToggleVoice: onToggleVoice,
              onSetup: onSetup,
              onFullscreen: onFullscreen,
              onLogout: onLogout,
            ),
          ],
        ],
      ),
    );
  }
}

class _ClockCard extends StatelessWidget {
  const _ClockCard({
    required this.time,
    required this.date,
    required this.compact,
  });

  final String time;
  final String date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF17171B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DisplayColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_rounded,
            color: _DisplayColors.muted,
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 14,
              color: _DisplayColors.border,
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: const TextStyle(
                color: _DisplayColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? _DisplayColors.mint : _DisplayColors.orange;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _withAlpha(color, 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _withAlpha(color, 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            online ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverControls extends StatelessWidget {
  const _HoverControls({
    required this.visible,
    required this.fullscreen,
    required this.voiceEnabled,
    required this.onToggleVoice,
    required this.onSetup,
    required this.onFullscreen,
    required this.onLogout,
  });

  final bool visible;
  final bool fullscreen;
  final bool voiceEnabled;
  final VoidCallback onToggleVoice;
  final VoidCallback onSetup;
  final VoidCallback onFullscreen;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xEE17171B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2E2E35)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HoverIconButton(
                tooltip: voiceEnabled ? 'Mute voice' : 'Enable voice',
                icon: voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                onPressed: onToggleVoice,
              ),
              _HoverIconButton(
                tooltip: fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                icon: fullscreen ? Icons.fullscreen_exit : Icons.open_in_full,
                onPressed: onFullscreen,
              ),
              _HoverIconButton(
                tooltip: context.tr('Display setup'),
                icon: Icons.tune,
                onPressed: onSetup,
              ),
              _HoverIconButton(
                tooltip: context.tr('Exit Token Display'),
                icon: Icons.arrow_back_rounded,
                onPressed: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDisplayMenu extends StatelessWidget {
  const _CompactDisplayMenu({
    required this.fullscreen,
    required this.voiceEnabled,
    required this.onToggleVoice,
    required this.onSetup,
    required this.onFullscreen,
    required this.onLogout,
  });

  final bool fullscreen;
  final bool voiceEnabled;
  final VoidCallback onToggleVoice;
  final VoidCallback onSetup;
  final VoidCallback onFullscreen;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Display options',
      color: const Color(0xFF17171B),
      onSelected: (value) {
        switch (value) {
          case 'voice':
            onToggleVoice();
          case 'full':
            onFullscreen();
          case 'setup':
            onSetup();
          case 'exit':
            onLogout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'voice',
          child: Text(voiceEnabled ? 'Mute voice' : 'Enable voice'),
        ),
        PopupMenuItem(
          value: 'full',
          child: Text(fullscreen ? 'Exit fullscreen' : 'Fullscreen'),
        ),
        const PopupMenuItem(value: 'setup', child: Text('Display setup')),
        const PopupMenuItem(value: 'exit', child: Text('Exit token display')),
      ],
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF17171B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _DisplayColors.border),
        ),
        child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _KitchenDisplayButton extends StatelessWidget {
  const _KitchenDisplayButton({required this.onPressed, this.compact = false});

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Kitchen display',
      child: SizedBox(
        height: 42,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: _DisplayColors.border),
            backgroundColor: const Color(0xFF17171B),
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          icon: const Icon(Icons.soup_kitchen_outlined, size: 16),
          label: Text(compact ? 'Kitchen' : context.tr('Kitchen display')),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatelessWidget {
  const _HoverIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          color: const Color(0xFFEDEDF2),
          icon: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _ErrorBand extends StatelessWidget {
  const _ErrorBand({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2B1717),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFFFA7A7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFD6D6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('Retry')),
          ),
        ],
      ),
    );
  }
}

class _InstructionBand extends StatelessWidget {
  const _InstructionBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: _DisplayColors.background,
        border: Border(bottom: BorderSide(color: _DisplayColors.border)),
      ),
      child: Text(
        context.tr(
          'Watch for your token number. When it appears under Ready, please collect your order at the counter.',
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _OrderHistoryPanel extends StatelessWidget {
  const _OrderHistoryPanel({required this.preparing, required this.ready});

  final List<CustomerDisplayOrder> preparing;
  final List<CustomerDisplayOrder> ready;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final children = [
          Expanded(
            child: _TokenColumnPanel(
              title: 'PREPARING',
              subtitle: 'Your order is being made',
              orders: preparing,
              color: _DisplayColors.orange,
              icon: Icons.bakery_dining_outlined,
              ready: false,
              compact: compact,
            ),
          ),
          Expanded(
            child: _TokenColumnPanel(
              title: 'READY TO COLLECT',
              subtitle: 'Please pick up at the counter',
              orders: ready,
              color: _DisplayColors.mint,
              icon: Icons.check_circle_outline_rounded,
              ready: true,
              compact: compact,
            ),
          ),
        ];
        if (compact) {
          return Column(
            children: [children[1], const SizedBox(height: 12), children[0]],
          );
        }
        return Row(
          children: [children[0], const SizedBox(width: 28), children[1]],
        );
      },
    );
  }
}

class _TokenColumnPanel extends StatelessWidget {
  const _TokenColumnPanel({
    required this.title,
    required this.subtitle,
    required this.orders,
    required this.color,
    required this.icon,
    required this.ready,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final List<CustomerDisplayOrder> orders;
  final Color color;
  final IconData icon;
  final bool ready;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xF20C0C0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _withAlpha(color, ready ? 0.34 : 0.28)),
        boxShadow: [
          BoxShadow(
            color: _withAlpha(color, 0.10),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 24,
              vertical: compact ? 12 : 22,
            ),
            decoration: BoxDecoration(
              color: _withAlpha(color, ready ? 0.12 : 0.16),
              border: Border(
                bottom: BorderSide(color: _withAlpha(color, 0.24)),
              ),
            ),
            child: Row(
              children: [
                _HeaderIcon(icon: icon, color: color, compact: compact),
                SizedBox(width: compact ? 10 : 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFF6F1E8),
                          fontSize: compact ? 16 : 29,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 9),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _DisplayColors.muted,
                          fontSize: compact ? 12 : 17,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                _CountBadge(count: orders.length, color: color, compact: compact),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? _EmptyState(
                    color: color,
                    title: ready ? 'No ready tokens' : 'No preparing tokens',
                    body: ready
                        ? 'Ready orders will appear here.'
                        : 'Preparing orders will appear here.',
                    icon: icon,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = ready
                          ? (constraints.maxWidth / 220).floor().clamp(2, 4)
                          : (constraints.maxWidth / 190).floor().clamp(2, 5);
                      return GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: ready ? 1.05 : 1.30,
                        ),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return _AnimatedTokenWrapper(
                            key: ValueKey(order.token),
                            tokenKey: order.token,
                            child: _TokenTile(
                              order: order,
                              color: color,
                              ready: ready,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTokenWrapper extends StatelessWidget {
  const _AnimatedTokenWrapper({
    super.key,
    required this.tokenKey,
    required this.child,
  });

  final Object tokenKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(tokenKey),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _TokenTile extends StatelessWidget {
  const _TokenTile({
    required this.order,
    required this.color,
    required this.ready,
  });

  final CustomerDisplayOrder order;
  final Color color;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _withAlpha(color, ready ? 0.56 : 0.28),
          width: ready ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _withAlpha(color, ready ? 0.20 : 0.05),
            blurRadius: ready ? 20 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.tr('TOKEN'),
                style: TextStyle(
                  color: color,
                  fontSize: ready ? 14 : 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: ready ? 4.0 : 2.5,
                ),
              ),
              SizedBox(height: ready ? 8 : 4),
              Text(
                order.token,
                maxLines: 1,
                style: TextStyle(
                  color: const Color(0xFFF6F1E8),
                  fontSize: ready ? 88 : 64,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: ready ? -2.0 : -1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 60.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _withAlpha(color, 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _withAlpha(color, 0.32)),
      ),
      child: Icon(icon, color: color, size: compact ? 20 : 28),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.color,
    this.compact = false,
  });

  final int count;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 54.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: _withAlpha(color, 0.36),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 16 : 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.color,
    required this.title,
    required this.body,
    required this.icon,
  });

  final Color color;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: _withAlpha(color, 0.11),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _withAlpha(color, 0.28)),
              ),
              child: Icon(icon, color: _withAlpha(color, 0.72), size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB8B6BF),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _DisplayColors.muted,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupSheet extends StatelessWidget {
  const _SetupSheet({
    required this.slugController,
    required this.branchController,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController slugController;
  final TextEditingController branchController;
  final bool isSaving;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: _DisplayColors.mint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('Order Board Setup'),
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('Close'),
                        onPressed: () => Navigator.of(context).pop(),
                        color: const Color(0xFF111827),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SetupField(
                    controller: slugController,
                    label: 'Restaurant slug',
                    hint: 'restaurant-slug',
                  ),
                  const SizedBox(height: 12),
                  _SetupField(
                    controller: branchController,
                    label: 'Branch ID',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: isSaving ? null : onSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: _DisplayColors.mint,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(isSaving ? 'Saving setup' : 'Save setup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupField extends StatelessWidget {
  const _SetupField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _DisplayColors.mint, width: 2),
        ),
      ),
    );
  }
}

class _GridBackdrop extends StatelessWidget {
  const _GridBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), child: const SizedBox.expand());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _DisplayColors.background,
    );
    final paint = Paint()
      ..color = _withAlpha(const Color(0xFF1D1D20), 0.36)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DisplayColors {
  const _DisplayColors._();

  static const background = Color(0xFF08080A);
  // ignore: unused_field
  static const surface = Color(0xFF17171B);
  static const border = Color(0xFF202024);
  static const muted = Color(0xFF8F8B98);
  static const orange = Color(0xFFFFB020);
  static const mint = Color(0xFF34D399);
}

Color _withAlpha(Color color, double alpha) {
  final normalized = alpha.clamp(0.0, 1.0);
  return color.withAlpha((normalized * 255).round());
}
