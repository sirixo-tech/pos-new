import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/waiter_alert.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/marketplace_platform_ui.dart';

/// In-app overlay for new-order / marketplace priority alerts (register + waiter).
class NewOrderAlertBannerHost extends StatelessWidget {
  const NewOrderAlertBannerHost({super.key});

  @override
  Widget build(BuildContext context) {
    final alert = context.select((PosController p) => p.registerBannerAlert);
    if (alert == null || !alert.type.isNewOrderCue) {
      return const SizedBox.shrink();
    }
    final moreCount = context.select(
      (PosController p) => p.pendingNewOrderBannerExtraCount,
    );
    final currency = context.select((PosController p) => p.currency);

    return Positioned.fill(
      child: Stack(
        children: [
          // Soft scrim — tap outside dismisses (doesn't block register forever).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                context.read<PosController>().dismissRegisterBannerAlert(
                      markRead: false,
                      showNext: false,
                    );
              },
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 180),
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: alert.isPriority ? 0.34 : 0.22,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: NewOrderAlertBanner(
                    key: ValueKey(alert.id),
                    alert: alert,
                    moreCount: moreCount,
                    currency: currency,
                    onDismiss: () {
                      context.read<PosController>().dismissRegisterBannerAlert(
                            markRead: false,
                            showNext: false,
                          );
                    },
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

class NewOrderAlertBanner extends StatefulWidget {
  const NewOrderAlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
    required this.currency,
    this.moreCount = 0,
  });

  final WaiterAlert alert;
  final VoidCallback onDismiss;
  final String currency;
  final int moreCount;

  @override
  State<NewOrderAlertBanner> createState() => _NewOrderAlertBannerState();
}

class _NewOrderAlertBannerState extends State<NewOrderAlertBanner>
    with SingleTickerProviderStateMixin {
  Timer? _autoDismiss;
  late final AnimationController _enter;

  bool get _priority => widget.alert.isPriority;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    if (_priority) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    // Marketplace + standard both auto-dismiss; priority stays a bit longer.
    _autoDismiss = Timer(
      Duration(seconds: _priority ? 12 : 8),
      () {
        if (mounted) widget.onDismiss();
      },
    );
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _enter.dispose();
    super.dispose();
  }

  String _typeLabel(AppLocalizations l10n, String? type) {
    return switch ((type ?? '').toLowerCase()) {
      'dine_in' || 'dine-in' => l10n.orderTypeDineIn,
      'takeaway' => l10n.orderTypeTakeaway,
      'delivery' => l10n.orderTypeDelivery,
      final t when t.isNotEmpty => t,
      _ => '',
    };
  }

  String _relativeTime(AppLocalizations l10n) {
    final local = widget.alert.at.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inSeconds < 45) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    return DateFormat('h:mm a').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final alert = widget.alert;
    final source = (alert.source ?? '').toLowerCase().trim();
    final brand = _priority && source.isNotEmpty
        ? marketplaceBrandColor(source)
        : const Color(0xFF059669);
    final partner = _priority
        ? marketplaceSourceDisplayLabel(l10n, alert.source)
        : '';
    final number = (alert.orderNumber ?? '').trim();
    final title = _priority
        ? alert.title
        : (number.isEmpty
            ? alert.title
            : l10n.newOrderAlertTitleOne(number));
    final description = _priority
        ? l10n.marketplacePriorityDescription
        : l10n.newOrderAlertDescription;
    final typeLabel = _typeLabel(l10n, alert.orderType);
    final enter = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.08),
        end: Offset.zero,
      ).animate(enter),
      child: FadeTransition(
        opacity: enter,
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PosTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PosTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: brand.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          brand.withValues(alpha: 0.14),
                          PosTheme.surface,
                          brand.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: brand.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeaderIcon(
                            brand: brand,
                            source: source,
                            priority: _priority,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_priority) ...[
                                  Text(
                                    l10n.marketplacePriorityChip.toUpperCase(),
                                    style: TextStyle(
                                      color: brand,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10.5,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: PosTheme.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    letterSpacing: -0.25,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: PosTheme.inkMuted,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.moreCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: brand.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  l10n.newOrderAlertMore(widget.moreCount),
                                  style: TextStyle(
                                    color: brand,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: PosTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: PosTheme.border),
                          ),
                          child: Row(
                            children: [
                              _TokenBadge(
                                brand: brand,
                                token: alert.token,
                                priority: _priority,
                                tokenLabel: l10n.newOrderAlertToken,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      number.isEmpty ? alert.body : number,
                                      style: TextStyle(
                                        color: PosTheme.ink,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        fontFamily: 'monospace',
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        l10n.newOrderAlertPlaced,
                                        _relativeTime(l10n),
                                        if (_priority && partner.isNotEmpty)
                                          partner,
                                        if (!_priority &&
                                            source.isNotEmpty &&
                                            source != 'pos')
                                          source[0].toUpperCase() +
                                              source.substring(1),
                                      ].join(' · '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: PosTheme.inkMuted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (typeLabel.isNotEmpty ||
                                        (alert.externalId ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (typeLabel.isNotEmpty)
                                            _MetaChip(
                                              label: typeLabel,
                                              color: PosTheme.inkMuted,
                                            ),
                                          if ((alert.externalId ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            _MetaChip(
                                              label: alert.externalId!.trim(),
                                              color: brand,
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
                        if (alert.total != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: brand.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: brand.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  l10n.newOrderAlertTotal,
                                  style: TextStyle(
                                    color: brand,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formatMoney(alert.total!, widget.currency),
                                  style: TextStyle(
                                    color: brand,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          widget.onDismiss();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.newOrderAlertDismiss,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.brand,
    required this.source,
    required this.priority,
  });

  final Color brand;
  final String source;
  final bool priority;

  @override
  Widget build(BuildContext context) {
    final logo = priority && (source == 'zomato' || source == 'swiggy')
        ? 'assets/images/integrations/$source.png'
        : null;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: logo != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    logo,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            )
          : const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 22,
            ),
    );
  }
}

class _TokenBadge extends StatelessWidget {
  const _TokenBadge({
    required this.brand,
    required this.token,
    required this.priority,
    required this.tokenLabel,
  });

  final Color brand;
  final String? token;
  final bool priority;
  final String tokenLabel;

  @override
  Widget build(BuildContext context) {
    final value = (token ?? '').trim();
    if (value.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosTheme.border),
        ),
        alignment: Alignment.center,
        child: Icon(
          priority
              ? Icons.local_shipping_rounded
              : Icons.receipt_long_rounded,
          color: brand,
          size: 24,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 56,
        minHeight: 56,
        maxHeight: 56,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brand,
            Color.lerp(brand, Colors.black, 0.18)!,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tokenLabel.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 8,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              height: 1,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
