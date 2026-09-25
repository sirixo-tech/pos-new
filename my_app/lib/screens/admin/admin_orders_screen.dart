import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../models/pos_models.dart';
import '../../providers/pos_admin_controller.dart';
import '../../providers/pos_controller.dart';
import '../../services/pos_api.dart';
import '../../services/printing/pos_receipt_printer.dart';
import '../../theme/pos_theme.dart';
import '../../utils/format.dart';
import '../../utils/marketplace_platform_ui.dart';
import '../../utils/order_cancel_reasons.dart';
import '../../widgets/pos_overlay.dart';
import '../../widgets/pos_ui.dart';
import '../../widgets/status_change_timeline.dart';
import 'admin_chrome.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _status;
  String? _source;
  String _period = 'today';
  String _payment = 'all';
  Timer? _searchDebounce;
  Timer? _autoRefresh;
  bool _detailOpen = false;
  DateTime? _lastRefreshedAt;

  static const _autoRefreshInterval = Duration(seconds: 10);

  static const _statuses = [
    'draft',
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'delivered',
    'cancelled',
    'abandoned',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reload());
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _autoRefresh?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted || _detailOpen) return;
      final admin = context.read<PosAdminController>();
      if (admin.ordersLoading) return;
      unawaited(
        _reload(
          page: admin.ordersPage?.currentPage ?? 1,
          silent: true,
        ),
      );
    });
  }

  Future<void> _reload({int page = 1, bool silent = false}) async {
    final enabled = context
            .read<PosController>()
            .bootstrap
            ?.marketplacePlatforms
            .map((p) => p.provider)
            .toSet() ??
        <String>{};
    if (_source != null && !enabled.contains(_source)) {
      _source = null;
    }
    await context.read<PosAdminController>().loadOrders(
          q: _searchCtrl.text,
          status: _status,
          source: _source,
          period: _period,
          payment: _payment,
          page: page,
          silent: silent,
        );
    if (!mounted) return;
    setState(() => _lastRefreshedAt = DateTime.now());
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(_reload());
    });
  }

  String _titleCase(String raw) {
    final t = raw.replaceAll('_', ' ').trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  String _periodLabel(BuildContext context) {
    return switch (_period) {
      'yesterday' =>
        context.posText('adminOrdersPeriodYesterday', 'Yesterday'),
      'last_7_days' =>
        context.posText('adminOrdersPeriodLast7Days', 'Last 7 days'),
      'all' => context.posText('adminOrdersPeriodAll', 'All time'),
      _ => context.posText('adminOrdersPeriodToday', 'Today'),
    };
  }

  List<({String key, String label})> _periodOptions(BuildContext context) {
    return [
      (
        key: 'today',
        label: context.posText('adminOrdersPeriodToday', 'Today'),
      ),
      (
        key: 'yesterday',
        label: context.posText('adminOrdersPeriodYesterday', 'Yesterday'),
      ),
      (
        key: 'last_7_days',
        label: context.posText('adminOrdersPeriodLast7Days', 'Last 7 days'),
      ),
      (
        key: 'all',
        label: context.posText('adminOrdersPeriodAll', 'All time'),
      ),
    ];
  }

  String _paymentLabel(BuildContext context) {
    return switch (_payment) {
      'paid' => context.posText('adminOrdersPaymentPaid', 'Paid'),
      'unpaid' => context.posText('adminOrdersPaymentUnpaid', 'Unpaid'),
      _ => context.posText('adminOrdersPaymentAll', 'All payments'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<PosAdminController>();
    final currency = context.watch<PosController>().currency;
    final page = admin.ordersPage;
    final accent = Theme.of(context).colorScheme.primary;
    final refreshedLabel = _lastRefreshedAt == null
        ? null
        : context.posText(
            'adminOrdersAutoRefresh',
            'Auto-refresh · {time}',
            {'time': DateFormat.jm().format(_lastRefreshedAt!)},
          );

    return Column(
      children: [
        Material(
          color: PosTheme.surface,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: PosTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.posText(
                        'adminOrdersSearch',
                        'Search order #, token, customer',
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.l10n.commonClear,
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _searchCtrl.clear();
                                setState(() => _query = '');
                                unawaited(_reload());
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: PosTheme.isDark
                          ? PosTheme.surfaceMuted
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusSm),
                        borderSide: BorderSide(color: PosTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusSm),
                        borderSide: BorderSide(color: PosTheme.border),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) {
                      _searchDebounce?.cancel();
                      unawaited(_reload());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.l10n.commonRefresh,
                  onPressed:
                      admin.ordersLoading ? null : () => unawaited(_reload()),
                  icon: admin.ordersLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
        Material(
          color: PosTheme.canvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    for (final option in _periodOptions(context)) ...[
                      if (option.key != 'today') const SizedBox(width: 8),
                      _StatusFilterChip(
                        label: option.label,
                        selected: _period == option.key,
                        accent: accent,
                        onTap: () {
                          if (_period == option.key) return;
                          setState(() => _period = option.key);
                          unawaited(_reload());
                        },
                      ),
                    ],
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 22,
                      color: PosTheme.border,
                    ),
                    const SizedBox(width: 12),
                    _StatusFilterChip(
                      label: context.posText(
                        'adminOrdersPaymentAll',
                        'All payments',
                      ),
                      selected: _payment == 'all',
                      accent: accent,
                      onTap: () {
                        if (_payment == 'all') return;
                        setState(() => _payment = 'all');
                        unawaited(_reload());
                      },
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: context.posText(
                        'adminOrdersPaymentUnpaid',
                        'Unpaid',
                      ),
                      selected: _payment == 'unpaid',
                      accent: accent,
                      onTap: () {
                        if (_payment == 'unpaid') return;
                        setState(() => _payment = 'unpaid');
                        unawaited(_reload());
                      },
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: context.posText(
                        'adminOrdersPaymentPaid',
                        'Paid',
                      ),
                      selected: _payment == 'paid',
                      accent: accent,
                      onTap: () {
                        if (_payment == 'paid') return;
                        setState(() => _payment = 'paid');
                        unawaited(_reload());
                      },
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _StatusFilterChip(
                      label: context.posText('adminAllStatuses', 'All'),
                      selected: _status == null,
                      accent: accent,
                      onTap: () {
                        setState(() => _status = null);
                        unawaited(_reload());
                      },
                    ),
                    for (final s in _statuses) ...[
                      const SizedBox(width: 8),
                      _StatusFilterChip(
                        label: s == 'draft'
                            ? context.posText(
                                'adminStatusDraftHeld',
                                'Draft (held)',
                              )
                            : _titleCase(s),
                        selected: _status == s,
                        accent: accent,
                        onTap: () {
                          setState(() => _status = s);
                          unawaited(_reload());
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Builder(
                builder: (context) {
                  final platforms = context
                          .watch<PosController>()
                          .bootstrap
                          ?.marketplacePlatforms ??
                      const <MarketplacePlatformInfo>[];
                  if (platforms.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.ordersFilterPartners,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PosTheme.inkMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < platforms.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _PartnerSourceChip(
                                    provider: platforms[i].provider,
                                    label: marketplacePlatformDisplayLabel(
                                      context.l10n,
                                      platforms[i],
                                    ),
                                    selected:
                                        _source == platforms[i].provider,
                                    onTap: () {
                                      setState(() {
                                        _source =
                                            _source == platforms[i].provider
                                                ? null
                                                : platforms[i].provider;
                                      });
                                      unawaited(_reload());
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (page != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      context.posText(
                        'adminOrdersCount',
                        '{n} orders',
                        {'n': '${page.total}'},
                      ),
                      _periodLabel(context),
                      if (_payment != 'all') _paymentLabel(context),
                      if (_status != null) _titleCase(_status!),
                      if (_source != null)
                        () {
                          final platforms = context
                                  .read<PosController>()
                                  .bootstrap
                                  ?.marketplacePlatforms ??
                              const <MarketplacePlatformInfo>[];
                          final match = platforms
                              .where((p) => p.provider == _source)
                              .firstOrNull;
                          if (match != null) {
                            return marketplacePlatformDisplayLabel(
                              context.l10n,
                              match,
                            );
                          }
                          return _titleCase(_source!);
                        }(),
                      if (_query.trim().isNotEmpty)
                        context.posText('adminFiltered', 'Filtered'),
                    ].join('  ·  '),
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (refreshedLabel != null)
                  Text(
                    refreshedLabel,
                    style: TextStyle(
                      color: PosTheme.inkMuted.withValues(alpha: 0.9),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        if (admin.error != null)
          AdminInlineError(
            message: admin.error!,
            onDismiss: admin.clearError,
          ),
        Expanded(
          child: admin.ordersLoading && page == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _reload(),
                  child: (page?.orders.isEmpty ?? true)
                      ? AdminEmptyPane(
                          icon: Icons.receipt_long_rounded,
                          title: context.posText(
                            'adminOrdersEmpty',
                            'No orders found.',
                          ),
                          subtitle: context.posText(
                            'adminOrdersEmptyHint',
                            'Try clearing filters or refreshing.',
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 14, 16),
                          itemCount: page!.orders.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = page.orders[index];
                            return _OrderCard(
                              order: order,
                              currency: currency,
                              onTap: () => _openDetail(context, order),
                            );
                          },
                        ),
                ),
        ),
        if (page != null && page.lastPage > 1)
          Material(
            color: PosTheme.surface,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: PosTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: page.currentPage <= 1 || admin.ordersLoading
                        ? null
                        : () => _reload(page: page.currentPage - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    context.posText(
                      'adminOrdersPageLabel',
                      'Page {page} of {pages} · {n} orders',
                      {
                        'page': '${page.currentPage}',
                        'pages': '${page.lastPage}',
                        'n': '${page.total}',
                      },
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PosTheme.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    onPressed: page.currentPage >= page.lastPage ||
                            admin.ordersLoading
                        ? null
                        : () => _reload(page: page.currentPage + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    AdminOrderSummary summary,
  ) async {
    final admin = context.read<PosAdminController>();
    final side = preferPosSidePanel(context);
    setState(() => _detailOpen = true);
    await showAdminPanel<void>(
      context: context,
      sidePanelWidth: 520,
      builder: (ctx) {
        return ChangeNotifierProvider.value(
          value: admin,
          child: AdminOrderDetailSheet(
            orderKey: '${summary.id}',
            summary: summary,
            asSidePanel: side,
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() => _detailOpen = false);
    unawaited(
      _reload(
        page: admin.ordersPage?.currentPage ?? 1,
        silent: true,
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Material(
      color: selected ? soft.bg : PosTheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? soft.fg.withValues(alpha: PosTheme.isDark ? 0.4 : 0.45)
                  : PosTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? soft.fg : PosTheme.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnerSourceChip extends StatelessWidget {
  const _PartnerSourceChip({
    required this.provider,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String provider;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = marketplaceBrandColor(provider);
    final soft = posAccentSoft(brand);

    return Material(
      color: selected ? soft.bg : PosTheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? brand.withValues(alpha: 0.45)
                  : PosTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Image.asset(
                  'assets/images/integrations/$provider.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    color: brand,
                    child: Text(
                      marketplacePlatformLetter(provider),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? soft.fg : PosTheme.inkMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.currency,
    required this.onTap,
  });

  final AdminOrderSummary order;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeLabel = order.createdAt == null
        ? null
        : DateFormat('MMM d · h:mm a').format(order.createdAt!.toLocal());
    final channel = _channelInfo(context, order);
    final typeLabel = (order.type != null && order.type!.trim().isNotEmpty)
        ? _pretty(order.type!)
        : null;
    final meta = <String>[
      if (order.tableName != null && order.tableName!.trim().isNotEmpty)
        context.posText(
          'adminOrdersTableMeta',
          'Table {name}',
          {'name': order.tableName!.trim()},
        ),
      if (order.customerName != null && order.customerName!.trim().isNotEmpty)
        order.customerName!.trim(),
      if (order.paymentMethod != null &&
          order.paymentMethod!.trim().isNotEmpty)
        _pretty(order.paymentMethod!),
      if (timeLabel != null) timeLabel,
    ];
    final showHint = order.paymentHint != null &&
        order.paymentHint!.trim().isNotEmpty &&
        order.paymentStatus.toLowerCase() != 'paid';

    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusMd),
            border: Border.all(color: PosTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChannelAvatar(
                  channel: channel,
                  token: order.token,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '#${order.orderNumber}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                letterSpacing: -0.2,
                                color: PosTheme.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatMoney(order.total, currency),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              letterSpacing: -0.2,
                              color: PosTheme.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaChip(
                            icon: channel.logoAsset == null ? channel.icon : null,
                            logoAsset: channel.logoAsset,
                            label: channel.label,
                            color: channel.color,
                          ),
                          if (typeLabel != null)
                            _MetaChip(
                              icon: _typeIcon(order.type),
                              label: typeLabel,
                              color: const Color(0xFF0F766E),
                            ),
                          AdminChip.status(order.status),
                          AdminChip.payment(order.paymentStatus),
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          meta.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PosTheme.inkMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (showHint) ...[
                        const SizedBox(height: 6),
                        Text(
                          order.paymentHint!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: PosTheme.inkFaint,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(String? type) {
    return switch ((type ?? '').toLowerCase()) {
      'delivery' => Icons.delivery_dining_rounded,
      'takeaway' => Icons.shopping_bag_outlined,
      _ => Icons.restaurant_rounded,
    };
  }

  static _ChannelInfo _channelInfo(
    BuildContext context,
    AdminOrderSummary order,
  ) {
    final source = (order.source ?? '').toLowerCase().trim();
    final channel = (order.posChannel ?? '').toLowerCase().trim();

    if (source == 'pos' || source.isEmpty && channel.isNotEmpty) {
      if (channel == 'captain') {
        return _ChannelInfo(
          label: context.posText(
            'adminOrdersChannelCaptain',
            'POS - Captain',
          ),
          icon: Icons.point_of_sale_rounded,
          color: const Color(0xFF4F46E5),
        );
      }
      return _ChannelInfo(
        label: context.posText('adminOrdersChannelPos', 'POS'),
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF4F46E5),
      );
    }

    return switch (source) {
      'kiosk' => _ChannelInfo(
          label: context.posText('adminOrdersChannelKiosk', 'Kiosk'),
          icon: Icons.tablet_mac_rounded,
          color: const Color(0xFF7C3AED),
        ),
      'mobile_app' => _ChannelInfo(
          label: context.posText('adminOrdersChannelApp', 'Mobile app'),
          icon: Icons.smartphone_rounded,
          color: const Color(0xFF059669),
        ),
      'api' => _ChannelInfo(
          label: context.posText('adminOrdersChannelApi', 'API'),
          icon: Icons.hub_outlined,
          color: const Color(0xFF64748B),
        ),
      'online' || 'storefront' || 'web' => _ChannelInfo(
          label: context.posText('adminOrdersChannelOnline', 'Online'),
          icon: Icons.storefront_outlined,
          color: const Color(0xFF2563EB),
        ),
      'zomato' => _ChannelInfo(
          label: context.posText('ordersSourceZomato', 'Zomato'),
          icon: Icons.delivery_dining_rounded,
          color: const Color(0xFFE23744),
          logoAsset: 'assets/images/integrations/zomato.png',
        ),
      'swiggy' => _ChannelInfo(
          label: context.posText('ordersSourceSwiggy', 'Swiggy'),
          icon: Icons.delivery_dining_rounded,
          color: const Color(0xFFFC8019),
          logoAsset: 'assets/images/integrations/swiggy.png',
        ),
      _ => _ChannelInfo(
          label: source.isEmpty
              ? context.posText('adminOrdersChannelUnknown', 'Order')
              : _pretty(source),
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF64748B),
        ),
    };
  }

  static String _pretty(String raw) {
    final t = raw.replaceAll('_', ' ').trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}

class _ChannelInfo {
  const _ChannelInfo({
    required this.label,
    required this.icon,
    required this.color,
    this.logoAsset,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String? logoAsset;
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({
    required this.channel,
    this.token,
  });

  final _ChannelInfo channel;
  final int? token;

  @override
  Widget build(BuildContext context) {
    if (token != null) {
      return Container(
        constraints: const BoxConstraints(
          minWidth: 46,
          minHeight: 46,
          maxHeight: 46,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              channel.color,
              Color.lerp(channel.color, Colors.black, 0.18)!,
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.posText('adminTokenShort', 'Token'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              '$token',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ],
        ),
      );
    }

    if (channel.logoAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          channel.logoAsset!,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            final soft = posAccentSoft(channel.color);
            return Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: soft.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: soft.fg.withValues(
                    alpha: PosTheme.isDark ? 0.28 : 0.22,
                  ),
                ),
              ),
              child: Icon(channel.icon, color: soft.fg, size: 22),
            );
          },
        ),
      );
    }

    final soft = posAccentSoft(channel.color);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: soft.fg.withValues(alpha: PosTheme.isDark ? 0.28 : 0.22),
        ),
      ),
      child: Icon(channel.icon, color: soft.fg, size: 22),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    this.icon,
    this.logoAsset,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: soft.fg.withValues(alpha: PosTheme.isDark ? 0.28 : 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logoAsset != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Image.asset(
                logoAsset!,
                width: 14,
                height: 14,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  icon ?? Icons.delivery_dining_rounded,
                  size: 13,
                  color: soft.fg,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: soft.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: soft.fg,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminOrderDetailSheet extends StatefulWidget {
  const AdminOrderDetailSheet({
    super.key,
    required this.orderKey,
    required this.summary,
    this.asSidePanel = false,
    this.readOnly = false,
  });

  final String orderKey;
  final AdminOrderSummary summary;
  final bool asSidePanel;

  /// When true, hide manage actions even if the user has manage_orders.
  final bool readOnly;

  /// Opens the same Manage → Orders detail modal used in admin.
  static Future<Map<String, dynamic>?> open(
    BuildContext context, {
    required int orderId,
    AdminOrderSummary? summary,
    Map<String, dynamic>? order,
    bool readOnly = false,
  }) async {
    final pos = context.read<PosController>();
    PosAdminController? existing;
    try {
      existing = context.read<PosAdminController>();
    } catch (_) {
      existing = null;
    }
    final owned = existing == null;
    final admin = existing ?? PosAdminController(api: PosApi(), pos: pos);
    final resolvedSummary = summary ??
        (order != null
            ? AdminOrderSummary.fromJson(Map<String, dynamic>.from(order))
            : AdminOrderSummary.placeholder(id: orderId));

    try {
      await showAdminPanel<void>(
        context: context,
        sidePanelWidth: 520,
        builder: (ctx) {
          return ChangeNotifierProvider.value(
            value: admin,
            child: AdminOrderDetailSheet(
              orderKey: '$orderId',
              summary: resolvedSummary,
              asSidePanel: preferPosSidePanel(context),
              readOnly: readOnly,
            ),
          );
        },
      );
      return admin.selectedOrder;
    } finally {
      if (owned) {
        admin.dispose();
      }
    }
  }

  @override
  State<AdminOrderDetailSheet> createState() => _AdminOrderDetailSheetState();
}

class _AdminOrderDetailSheetState extends State<AdminOrderDetailSheet> {
  bool _loading = true;
  bool _loadFailed = false;

  static const _workflow = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'delivered',
  ];

  static const _nextStatus = <String, (String value, String label)>{
    'pending': ('confirmed', 'Accept order'),
    'confirmed': ('preparing', 'Send to kitchen'),
    'preparing': ('ready', 'Mark ready for pickup'),
    'ready': ('delivered', 'Mark as served / picked up'),
  };

  static const _previousStatus = <String, (String value, String label)>{
    'confirmed': ('pending', 'Pending'),
    'preparing': ('confirmed', 'Confirmed'),
    'ready': ('preparing', 'Preparing'),
    'delivered': ('ready', 'Ready'),
  };

  static const _paymentStatuses = <(String value, String label)>[
    ('pending', 'Payment pending'),
    ('paid', 'Paid'),
    ('partial', 'Partial'),
    ('failed', 'Payment failed'),
    ('timed_out', 'Payment timed out'),
    ('refunded', 'Refunded'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final result =
        await context.read<PosAdminController>().loadOrder(widget.orderKey);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadFailed = result == null;
    });
  }

  String _statusLabel(String value) {
    return switch (value) {
      'draft' => context.posText('adminStatusDraftHeld', 'Draft (held)'),
      'pending' => context.posText('adminStatusPending', 'Pending'),
      'confirmed' => context.posText('adminStatusConfirmed', 'Confirmed'),
      'preparing' => context.posText('adminStatusPreparing', 'Preparing'),
      'ready' => context.posText('adminStatusReady', 'Ready'),
      'delivered' => context.posText('adminStatusDelivered', 'Delivered'),
      'cancelled' => context.posText('adminStatusCancelled', 'Cancelled'),
      'abandoned' => context.posText('adminStatusAbandoned', 'Abandoned'),
      _ => value,
    };
  }

  bool _canCheckPayment(Map<String, dynamic> order) {
    final paymentStatus =
        '${order['payment_status'] ?? ''}'.toLowerCase();
    final status = '${order['status'] ?? ''}'.toLowerCase();
    if (paymentStatus == 'paid' || status == 'cancelled') return false;
    if (!const {'pending', 'partial', 'timed_out'}.contains(paymentStatus)) {
      return false;
    }
    final method = '${order['payment_method'] ?? ''}'.toLowerCase();
    if (method == 'phonepe' || method == 'paytm') return true;
    final attempts = (order['payment_attempts'] as List? ?? const [])
        .whereType<Map>();
    return attempts.any((a) {
      final m = '${a['method'] ?? ''}'.toLowerCase();
      return m == 'phonepe' || m == 'paytm';
    });
  }

  Future<void> _printReceipt(Map<String, dynamic> order) async {
    final session = context.read<PosController>().session;
    if (session == null) return;

    final orderNumber =
        '${order['order_number'] ?? widget.summary.orderNumber}'.trim();
    if (orderNumber.isEmpty) {
      showPosSnackBar(
        context,
        context.l10n.ordersNumberMissing,
        error: true,
      );
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
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _printKot(Map<String, dynamic> order) async {
    final session = context.read<PosController>().session;
    if (session == null) return;

    final orderNumber =
        '${order['order_number'] ?? widget.summary.orderNumber}'.trim();
    if (orderNumber.isEmpty) {
      showPosSnackBar(
        context,
        context.l10n.ordersNumberMissing,
        error: true,
      );
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
      showPosErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showPosErrorSnackBar(context, e);
    }
  }

  Future<void> _setStatus(
    String status, {
    String? cancelReason,
    String? cancelNote,
  }) async {
    final admin = context.read<PosAdminController>();
    await admin.updateOrderStatus(
      widget.orderKey,
      status,
      cancelReason: cancelReason,
      cancelNote: cancelNote,
    );
  }

  Future<void> _cancelOrder() async {
    final result = await showPosCancelOrderDialog(
      context,
      canRefund: false,
    );
    if (result == null || !mounted) return;
    await _setStatus(
      'cancelled',
      cancelReason: result.cancelReason,
      cancelNote: result.cancelNote,
    );
  }

  Future<void> _reopenOrder() async {
    final ok = await showPosConfirmDialog(
      context,
      title: context.posText('adminReopenOrderTitle', 'Reopen this order?'),
      message: context.posText(
        'adminReopenOrderMessage',
        'The order will return to its previous status and kitchen tickets will be sent back to the board.',
      ),
      confirmLabel: context.posText('adminReopenOrder', 'Reopen order'),
      icon: Icons.undo_rounded,
    );
    if (!ok || !mounted) return;
    final admin = context.read<PosAdminController>();
    final success = await admin.reopenOrder(widget.orderKey);
    if (success && mounted) {
      showPosSnackBar(
        context,
        context.posText('adminReopenOrderSuccess', 'Order reopened successfully.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<PosAdminController>();
    final currency = context.watch<PosController>().currency;
    final order = admin.selectedOrder;
    final canManage = !widget.readOnly && admin.canManageOrders;
    final accent = Theme.of(context).colorScheme.primary;

    final soft = posAccentSoft(accent);
    return Material(
      color: PosTheme.canvas,
      child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: soft.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: soft.fg,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.posText('adminOrderDetail', 'Order detail'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: PosTheme.ink,
                          ),
                    ),
                  ),
                  Material(
                    color: soft.bg,
                    borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
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
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadFailed || order == null)
              Expanded(
                child: AdminErrorPane(
                  message: admin.error ??
                      context.posText(
                        'adminOrderLoadFailed',
                        'Could not load this order.',
                      ),
                  onRetry: _fetch,
                ),
              )
            else ...[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${order['order_number'] ?? widget.summary.orderNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    color: PosTheme.ink,
                                  ),
                                ),
                                if ((order['token'] ?? widget.summary.token) !=
                                    null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    context.posText(
                                      'adminTokenBadge',
                                      'Token {n}',
                                      {
                                        'n':
                                            '${order['token'] ?? widget.summary.token}',
                                      },
                                    ),
                                    style: TextStyle(
                                      color: PosTheme.inkMuted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            formatMoney(
                              (order['total'] as num?)?.toDouble() ??
                                  widget.summary.total,
                              currency,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: PosTheme.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _MetaBlock(order: order, summary: widget.summary),
                      const SizedBox(height: 14),
                      _OrderStatusWorkflow(
                        status: '${order['status'] ?? 'pending'}',
                        paymentStatus: '${order['payment_status'] ?? ''}',
                        cancelReason: (order['cancel_reason'] as String?)
                            ?.trim(),
                        cancelNote:
                            (order['cancel_note'] as String?)?.trim(),
                        cancelReasonLabel:
                            (order['cancel_reason_label'] as String?)
                                ?.trim(),
                        canManage: canManage,
                        canReopen: canManage && order['can_reopen'] == true,
                        busy: admin.mutating,
                        accent: accent,
                        statusLabel: _statusLabel,
                        workflow: _workflow,
                        next: _nextStatus['${order['status'] ?? ''}'],
                        previous: _previousStatus['${order['status'] ?? ''}'],
                        onAdvance: (s) => _setStatus(s),
                        onGoBack: (s) => _setStatus(s),
                        onCancel: _cancelOrder,
                        onReopen: _reopenOrder,
                      ),
                      Builder(
                        builder: (context) {
                          final statusLogs = (order['status_logs'] as List? ??
                                  const [])
                              .whereType<Map>()
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList();
                          if (statusLogs.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: PosTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: PosTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    context.posText(
                                      'adminStatusHistory',
                                      'Order status history',
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: PosTheme.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  StatusChangeTimeline(
                                    logs: statusLogs,
                                    statusLabel: _statusLabel,
                                    accent: const Color(0xFF7C3AED),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (PosReceiptPrinter.isSupported) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: admin.mutating
                                    ? null
                                    : () => _printReceipt(order),
                                icon: const Icon(Icons.print_rounded, size: 18),
                                label: Text(
                                  context.posText(
                                    'ordersPrintReceipt',
                                    'Print receipt',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: admin.mutating
                                    ? null
                                    : () => _printKot(order),
                                icon: const Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.posText(
                                    'ordersPrintKot',
                                    'Print KOT',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      _PaymentStatusCard(
                        order: order,
                        canManage: canManage,
                        busy: admin.mutating,
                        paymentStatuses: _paymentStatuses,
                        canCheckPayment: canManage && _canCheckPayment(order),
                        onPaymentStatusChanged: (status) async {
                          String? method;
                          final currentMethod =
                              '${order['payment_method'] ?? ''}'.toLowerCase();
                          if (status == 'paid' &&
                              '${order['payment_status'] ?? ''}' != 'paid' &&
                              !isManualPaymentMethod(currentMethod)) {
                            final gateways = context
                                    .read<PosController>()
                                    .bootstrap
                                    ?.paymentGateways
                                    .map((g) => g.slug) ??
                                const <String>[];
                            method = await showPosMarkPaidMethodDialog(
                              context,
                              activeGatewaySlugs: gateways,
                            );
                            if (method == null || !context.mounted) return;
                          }
                          final ok = await admin.updateOrderPaymentStatus(
                            widget.orderKey,
                            status,
                            paymentMethod: method,
                          );
                          if (ok && context.mounted) {
                            showPosSnackBar(
                              context,
                              context.posText(
                                'adminPaymentStatusUpdated',
                                'Payment status updated.',
                              ),
                            );
                          }
                        },
                        onCheckPayment: () async {
                          final result =
                              await admin.checkOrderPayment(widget.orderKey);
                          if (result != null && context.mounted) {
                            showPosSnackBar(
                              context,
                              result.message,
                              error: result.failed || result.timedOut,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _PaymentHistorySection(
                        order: order,
                        currency: currency,
                        accent: accent,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.posText('adminItems', 'Items'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: PosTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildItemRows(order, currency),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: PosTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PosTheme.border),
                        ),
                        child: Row(
                          children: [
                            Text(
                              context.posText('adminTotal', 'Total'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: PosTheme.ink,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              formatMoney(
                                (order['total'] as num?)?.toDouble() ?? 0,
                                currency,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: PosTheme.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
    );
  }

  List<Widget> _buildItemRows(Map<String, dynamic> order, String currency) {
    final items = (order['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (items.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: PosTheme.surfaceMuted.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            context.posText('adminNoOrderItems', 'No line items.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PosTheme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ];
    }

    return [
      for (final raw in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: PosTheme.surfaceMuted.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${raw['quantity'] ?? 1}× ${raw['name'] ?? ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: PosTheme.ink,
                          fontSize: 14,
                        ),
                      ),
                      if ((raw['notes'] as String?)?.trim().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${raw['notes']}',
                          style: TextStyle(
                            color: PosTheme.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  formatMoney(
                    (raw['line_total'] as num?)?.toDouble() ??
                        (raw['total'] as num?)?.toDouble() ??
                        0,
                    currency,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: PosTheme.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _OrderStatusWorkflow extends StatelessWidget {
  const _OrderStatusWorkflow({
    required this.status,
    required this.paymentStatus,
    this.cancelReason,
    this.cancelNote,
    this.cancelReasonLabel,
    required this.canManage,
    this.canReopen = false,
    required this.busy,
    required this.accent,
    required this.statusLabel,
    required this.workflow,
    required this.next,
    required this.previous,
    required this.onAdvance,
    required this.onGoBack,
    required this.onCancel,
    this.onReopen,
  });

  final String status;
  final String paymentStatus;
  final String? cancelReason;
  final String? cancelNote;
  final String? cancelReasonLabel;
  final bool canManage;
  final bool canReopen;
  final bool busy;
  final Color accent;
  final String Function(String) statusLabel;
  final List<String> workflow;
  final (String value, String label)? next;
  final (String value, String label)? previous;
  final ValueChanged<String> onAdvance;
  final ValueChanged<String> onGoBack;
  final VoidCallback onCancel;
  final VoidCallback? onReopen;

  int get _currentIndex {
    if (status == 'cancelled' || status == 'abandoned') return -1;
    final i = workflow.indexOf(status);
    return i >= 0 ? i : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (status == 'abandoned') {
      return _TerminalBanner(
        color: const Color(0xFFE11D48),
        icon: Icons.cancel_outlined,
        title: statusLabel('abandoned'),
        message: context.posText(
          'adminOrderAbandonedMessage',
          'This checkout was abandoned before it was completed.',
        ),
      );
    }
    if (status == 'cancelled') {
      final refunded = paymentStatus.toLowerCase() == 'refunded';
      final reasonCode = (cancelReason ?? '').trim();
      final reasonLabel = (cancelReasonLabel ?? '').trim().isNotEmpty
          ? cancelReasonLabel!.trim()
          : (reasonCode.isNotEmpty
              ? orderCancelReasonLabel(context, reasonCode)
              : null);
      final note = (cancelNote ?? '').trim();
      return _TerminalBanner(
        color: const Color(0xFFDC2626),
        icon: Icons.cancel_outlined,
        title: statusLabel('cancelled'),
        message: refunded
            ? context.posText(
                'adminOrderCancelledRefundedMessage',
                'This order was cancelled and marked refunded.',
              )
            : canReopen
                ? context.posText(
                    'adminOrderCancelledMessage',
                    'This order was cancelled. You can reopen it if that was a mistake.',
                  )
                : context.posText(
                    'adminOrderCancelledClosedMessage',
                    'This order is closed. No further updates can be made.',
                  ),
        detail: reasonLabel == null
            ? null
            : context.posText(
                'cancelReasonBanner',
                'Reason: {reason}',
                {'reason': reasonLabel},
              ),
        footnote: note.isEmpty ? null : note,
        actionLabel: canReopen && !busy
            ? context.posText('adminReopenOrder', 'Reopen order')
            : null,
        onAction: canReopen && !busy ? onReopen : null,
        actionIcon: Icons.undo_rounded,
      );
    }
    if (status == 'delivered') {
      return _TerminalBanner(
        color: const Color(0xFF0D9488),
        icon: Icons.check_circle_outline_rounded,
        title: context.posText('adminOrderCompleteTitle', 'Order complete'),
        message: context.posText(
          'adminOrderCompleteMessage',
          'This order has been served or picked up.',
        ),
      );
    }

    final current = _currentIndex;
    final canChange = canManage && current >= 0;

    return Container(
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
              border: Border(bottom: BorderSide(color: PosTheme.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  context.posText(
                    'adminOrderProgressTitle',
                    'Order progress',
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: PosTheme.ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
            child: _WorkflowStepper(
              labels: [
                for (final step in workflow) statusLabel(step),
              ],
              currentIndex: current,
              accent: accent,
            ),
          ),
          if (canChange && next != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                children: [
                  Text(
                    context.posText(
                      'adminStatusNextPrompt',
                      'Ready for the next step?',
                    ),
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : () => onAdvance(next!.$1),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: accent,
                      ),
                      child: Text(
                        context.posText(
                          'adminStatusAction_${next!.$1}',
                          next!.$2,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (canChange) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Column(
                children: [
                  if (previous != null)
                    TextButton.icon(
                      onPressed: busy ? null : () => onGoBack(previous!.$1),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: Text(
                        context.posText(
                          'adminStatusGoBack',
                          'Go back to {step}',
                          {'step': previous!.$2},
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: busy ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                    child: Text(
                      context.posText('adminCancelOrder', 'Cancel order'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkflowStepper extends StatelessWidget {
  const _WorkflowStepper({
    required this.labels,
    required this.currentIndex,
    required this.accent,
  });

  final List<String> labels;
  final int currentIndex;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: compact ? 11 : 13),
                    child: Container(
                      height: 2,
                      color: i <= currentIndex
                          ? const Color(0xFF34D399)
                          : PosTheme.border,
                    ),
                  ),
                ),
              _WorkflowStep(
                label: labels[i],
                done: i < currentIndex,
                active: i == currentIndex,
                accent: accent,
                compact: compact,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.label,
    required this.done,
    required this.active,
    required this.accent,
    required this.compact,
  });

  final String label;
  final bool done;
  final bool active;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? const Color(0xFF059669)
        : active
            ? accent
            : PosTheme.inkFaint;
    final size = compact ? 24.0 : 28.0;

    return SizedBox(
      width: compact ? 52 : 64,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: done || active ? color : PosTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              done
                  ? Icons.check_rounded
                  : active
                      ? Icons.circle
                      : Icons.circle_outlined,
              size: done ? (compact ? 14 : 16) : (compact ? 8 : 10),
              color: done || active ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: active || done ? FontWeight.w800 : FontWeight.w600,
              fontSize: compact ? 10 : 11,
              height: 1.15,
              color: active
                  ? accent
                  : done
                      ? const Color(0xFF047857)
                      : PosTheme.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalBanner extends StatelessWidget {
  const _TerminalBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    this.detail,
    this.footnote,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final String? detail;
  final String? footnote;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(color);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: soft.fg.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: soft.fg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: soft.fg,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if ((detail ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        detail!.trim(),
                        style: TextStyle(
                          color: soft.fg,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if ((footnote ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        footnote!.trim(),
                        style: TextStyle(
                          color: color.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.undo_rounded, size: 18),
              label: Text(actionLabel!),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                side: const BorderSide(color: Color(0xFFFBBF24)),
                backgroundColor: const Color(0xFFFFFBEB),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({
    required this.order,
    required this.currency,
    required this.accent,
  });

  final Map<String, dynamic> order;
  final String currency;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final payments = (order['payments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final attempts = (order['payment_attempts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final statusLogs = (order['payment_status_logs'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final timeline = <_PaymentLogEntry>[
      for (final payment in payments) _PaymentLogEntry.payment(payment),
      for (final attempt in attempts) _PaymentLogEntry.attempt(attempt),
    ]..sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });

    final totalPaid = (order['total_paid'] as num?)?.toDouble() ??
        payments.fold<double>(0, (sum, row) {
          if ('${row['method'] ?? ''}'.toLowerCase() == 'refund') return sum;
          return sum + ((row['amount'] as num?)?.toDouble() ?? 0);
        });
    final remaining = (order['remaining'] as num?)?.toDouble() ??
        (((order['total'] as num?)?.toDouble() ?? 0) - totalPaid)
            .clamp(0, double.infinity)
            .toDouble();
    final paymentStatus = '${order['payment_status'] ?? ''}'.toLowerCase();
    final paymentMethod = '${order['payment_method'] ?? ''}'.trim();
    final showBalance =
        paymentStatus == 'partial' || (totalPaid > 0 && remaining > 0.001);
    final showPaidHint = timeline.isEmpty &&
        statusLogs.isEmpty &&
        paymentStatus == 'paid' &&
        paymentMethod.isNotEmpty;

    String paymentStatusLabel(String status) {
      final key = 'adminPayment_$status';
      return context.posText(key, status.replaceAll('_', ' '));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.posText('adminPaymentHistory', 'Payment log'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.posText(
              'adminPaymentHistoryHelp',
              'Attempts, failures, and received payments',
            ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PosTheme.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          if (showBalance) ...[
            Row(
              children: [
                Expanded(
                  child: _PaymentBalanceTile(
                    label: context.posText('adminTotalPaid', 'Total paid'),
                    value: formatMoney(totalPaid, currency),
                    color: const Color(0xFF166534),
                    background: PosTheme.isDark
                        ? const Color(0xFF052E16)
                        : const Color(0xFFDCFCE7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentBalanceTile(
                    label: context.posText('adminRemaining', 'Remaining'),
                    value: remaining <= 0.001
                        ? context.posText('adminPayment_paid', 'Paid')
                        : formatMoney(remaining, currency),
                    color: remaining <= 0.001
                        ? const Color(0xFF166534)
                        : const Color(0xFF92400E),
                    background: remaining <= 0.001
                        ? (PosTheme.isDark
                            ? const Color(0xFF052E16)
                            : const Color(0xFFDCFCE7))
                        : (PosTheme.isDark
                            ? const Color(0xFF422006)
                            : const Color(0xFFFEF3C7)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (statusLogs.isNotEmpty) ...[
            Text(
              context.posText(
                'adminPaymentStatusHistory',
                'Payment status changes',
              ),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: PosTheme.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            StatusChangeTimeline(
              logs: statusLogs,
              statusLabel: paymentStatusLabel,
              accent: const Color(0xFF0284C7),
            ),
            if (timeline.isNotEmpty || showPaidHint) const SizedBox(height: 14),
          ],
          if (timeline.isNotEmpty)
            for (var i = 0; i < timeline.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _PaymentLogRow(
                entry: timeline[i],
                currency: currency,
                accent: accent,
              ),
            ]
          else if (showPaidHint)
            Text(
              context.posText(
                'adminPaidVia',
                'Paid via {method} (no payment records).',
                {'method': _prettyMethod(paymentMethod)},
              ),
              style: TextStyle(
                color: PosTheme.inkMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            )
          else if (statusLogs.isEmpty)
            Text(
              context.posText(
                'adminNoPaymentActivity',
                'No payment activity recorded yet.',
              ),
              style: TextStyle(
                color: PosTheme.inkMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  static String _prettyMethod(String raw) {
    final t = raw.replaceAll('_', ' ').trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}

class _PaymentBalanceTile extends StatelessWidget {
  const _PaymentBalanceTile({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentLogEntry {
  _PaymentLogEntry.payment(this.data)
      : kind = _PaymentLogKind.payment,
        createdAt = DateTime.tryParse('${data['created_at'] ?? ''}');

  _PaymentLogEntry.attempt(this.data)
      : kind = _PaymentLogKind.attempt,
        createdAt = DateTime.tryParse('${data['created_at'] ?? ''}');

  final _PaymentLogKind kind;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
}

enum _PaymentLogKind { payment, attempt }

class _PaymentLogRow extends StatelessWidget {
  const _PaymentLogRow({
    required this.entry,
    required this.currency,
    required this.accent,
  });

  final _PaymentLogEntry entry;
  final String currency;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (entry.kind == _PaymentLogKind.payment) {
      return _buildPayment(context);
    }
    return _buildAttempt(context);
  }

  Widget _buildPayment(BuildContext context) {
    final data = entry.data;
    final method = '${data['method'] ?? ''}'.toLowerCase();
    final isRefund = method == 'refund';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final note = '${data['note'] ?? ''}'.trim();
    final cashTendered = (data['cash_tendered'] as num?)?.toDouble();
    final changeGiven = (data['change_given'] as num?)?.toDouble();
    final dark = PosTheme.isDark;

    final bg = isRefund
        ? (dark ? const Color(0xFF4C0519) : const Color(0xFFFEF2F2))
        : (dark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4));
    final border = isRefund
        ? (dark ? const Color(0xFF9F1239) : const Color(0xFFFECACA))
        : (dark ? const Color(0xFF166534) : const Color(0xFFBBF7D0));
    final amountColor = isRefund
        ? (dark ? const Color(0xFFFAA2B0) : const Color(0xFFB91C1C))
        : (dark ? const Color(0xFF6EE7B7) : const Color(0xFF166534));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRefund ? Icons.undo_rounded : Icons.check_circle_rounded,
            color: isRefund ? amountColor : accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PaymentLogChip(
                      label: _PaymentHistorySection._prettyMethod(
                        method.isEmpty ? 'payment' : method,
                      ),
                    ),
                    _PaymentLogChip(
                      label: isRefund
                          ? context.posText('adminPaymentRefund', 'Refund')
                          : context.posText(
                              'adminPaymentReceived',
                              'Received',
                            ),
                      background: isRefund
                          ? (dark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFEE2E2))
                          : (dark
                              ? const Color(0xFF14532D)
                              : const Color(0xFFDCFCE7)),
                      foreground: amountColor,
                    ),
                    if (entry.createdAt != null)
                      Text(
                        formatReceiptDatetime(entry.createdAt!),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: PosTheme.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (method == 'cash' &&
                    cashTendered != null &&
                    changeGiven != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.posText(
                      'adminTenderedChange',
                      'Tendered {tendered} · Change {change}',
                      {
                        'tendered': formatMoney(cashTendered, currency),
                        'change': formatMoney(changeGiven, currency),
                      },
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isRefund && amount > 0 ? '−' : ''}${formatMoney(amount.abs(), currency)}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttempt(BuildContext context) {
    final data = entry.data;
    final status = '${data['status'] ?? ''}'.toLowerCase();
    final method = '${data['method'] ?? ''}';
    final amount = (data['amount'] as num?)?.toDouble();
    final failure = '${data['failure_reason'] ?? ''}'.trim();
    final source = '${data['source'] ?? ''}'.trim();
    final failed = status == 'failed';
    final held = status == 'held';
    final dark = PosTheme.isDark;

    final bg = failed
        ? (dark ? const Color(0xFF4C0519) : const Color(0xFFFEF2F2))
        : held
            ? (dark ? const Color(0xFF422006) : const Color(0xFFFFFBEB))
            : PosTheme.surfaceMuted;
    final border = failed
        ? (dark ? const Color(0xFF9F1239) : const Color(0xFFFECACA))
        : held
            ? (dark ? const Color(0xFFB45309) : const Color(0xFFFDE68A))
            : PosTheme.border;
    final iconColor = failed
        ? const Color(0xFFDC2626)
        : held
            ? const Color(0xFFD97706)
            : PosTheme.inkMuted;
    final statusLabel = failed
        ? context.posText('adminPaymentFailed', 'Failed')
        : held
            ? context.posText('adminPaymentHeld', 'Held')
            : context.posText('adminPaymentAttempted', 'Attempted');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed
                ? Icons.error_outline_rounded
                : held
                    ? Icons.pause_circle_outline_rounded
                    : Icons.schedule_rounded,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (method.isNotEmpty)
                      _PaymentLogChip(
                        label: _PaymentHistorySection._prettyMethod(method),
                      ),
                    _PaymentLogChip(
                      label: statusLabel,
                      background: failed
                          ? (dark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFEE2E2))
                          : held
                              ? (dark
                                  ? const Color(0xFF78350F)
                                  : const Color(0xFFFEF3C7))
                              : PosTheme.surface,
                      foreground: failed
                          ? const Color(0xFF991B1B)
                          : held
                              ? const Color(0xFF92400E)
                              : PosTheme.inkMuted,
                    ),
                    if (entry.createdAt != null)
                      Text(
                        formatReceiptDatetime(entry.createdAt!),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                  ],
                ),
                if (failure.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    failure,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: failed ? FontWeight.w600 : FontWeight.w500,
                      color: failed
                          ? (dark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFB91C1C))
                          : PosTheme.inkMuted,
                    ),
                  ),
                ],
                if (source.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.posText(
                      'adminPaymentViaSource',
                      'Via {source}',
                      {'source': source.replaceAll('_', ' ')},
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 8),
            Text(
              formatMoney(amount, currency),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: failed
                    ? (dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                    : PosTheme.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentLogChip extends StatelessWidget {
  const _PaymentLogChip({
    required this.label,
    this.background,
    this.foreground,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? PosTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosTheme.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground ?? PosTheme.ink,
        ),
      ),
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({
    required this.order,
    required this.canManage,
    required this.busy,
    required this.paymentStatuses,
    required this.canCheckPayment,
    required this.onPaymentStatusChanged,
    required this.onCheckPayment,
  });

  final Map<String, dynamic> order;
  final bool canManage;
  final bool busy;
  final List<(String value, String label)> paymentStatuses;
  final bool canCheckPayment;
  final ValueChanged<String> onPaymentStatusChanged;
  final VoidCallback onCheckPayment;

  @override
  Widget build(BuildContext context) {
    final current = '${order['payment_status'] ?? 'pending'}';
    final method = '${order['payment_method'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.posText('adminPaymentStatus', 'Payment status'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (canManage)
            DropdownButtonFormField<String>(
              initialValue: paymentStatuses.any((s) => s.$1 == current)
                  ? current
                  : 'pending',
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    PosTheme.isDark ? PosTheme.surfaceMuted : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                  borderSide: BorderSide(color: PosTheme.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: [
                for (final s in paymentStatuses)
                  DropdownMenuItem(
                    value: s.$1,
                    child: Text(
                      context.posText('adminPayment_${s.$1}', s.$2),
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (v) {
                      if (v == null || v == current) return;
                      onPaymentStatusChanged(v);
                    },
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: AdminChip.payment(current),
            ),
          if (method.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              context.posText(
                'adminPaymentMethodValue',
                'Method: {method}',
                {'method': method.replaceAll('_', ' ')},
              ),
              style: TextStyle(
                color: PosTheme.inkMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
          if (canCheckPayment) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PosTheme.surfaceMuted.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PosTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.posText(
                      'adminCheckPaymentHelp',
                      'Ask PhonePe / Paytm again if the guest may have paid while the network was down.',
                    ),
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onCheckPayment,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(
                      context.posText(
                        'adminCheckLatestPayment',
                        'Check latest payment status',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({
    required this.order,
    required this.summary,
  });

  final Map<String, dynamic> order;
  final AdminOrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final customer = (order['customer_name'] as String?)?.trim().isNotEmpty ==
            true
        ? '${order['customer_name']}'
        : (summary.customerName?.trim().isNotEmpty == true
            ? summary.customerName!
            : null);
    final type = (order['type'] as String?) ?? summary.type;
    final method =
        (order['payment_method'] as String?) ?? summary.paymentMethod;
    final createdRaw = order['created_at'] as String?;
    final created = createdRaw != null
        ? DateTime.tryParse(createdRaw)?.toLocal()
        : summary.createdAt?.toLocal();

    final rows = <(String, String)>[
      if (customer != null)
        (context.posText('adminCustomer', 'Customer'), customer),
      if (type != null && type.trim().isNotEmpty)
        (context.posText('adminOrderType', 'Type'), _pretty(type)),
      if (method != null && method.trim().isNotEmpty)
        (
          context.posText('adminPaymentMethod', 'Payment'),
          _pretty(method),
        ),
      if (created != null)
        (
          context.posText('adminPlacedAt', 'Placed'),
          DateFormat('MMM d · h:mm a').format(created),
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    rows[i].$1,
                    style: TextStyle(
                      color: PosTheme.inkFaint,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    style: TextStyle(
                      color: PosTheme.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _pretty(String raw) {
    final t = raw.replaceAll('_', ' ').trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}
