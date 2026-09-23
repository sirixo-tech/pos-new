import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/waiter_alert.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/marketplace_platform_ui.dart';
import 'pos_overlay.dart';
import 'pos_ui.dart';

/// Shared captain + register notifications inbox.
class StaffNotificationsPanel extends StatelessWidget {
  const StaffNotificationsPanel({
    super.key,
    this.embedded = true,
    this.asSidePanel = false,
    this.emptySubtitle,
  });

  /// When true, used as a full tab (captain Alerts) — no overlay chrome.
  final bool embedded;

  /// Wide desktop presentation (matches orders / reports side panels).
  final bool asSidePanel;

  /// Override empty-state subtitle (register vs captain copy).
  final String? emptySubtitle;

  static Future<void> open(
    BuildContext context, {
    String? emptySubtitle,
  }) {
    final side = preferPosSidePanel(context);
    return showPosOverlay<void>(
      context: context,
      sidePanelWidth: 440,
      useSafeArea: false,
      builder: (ctx) => StaffNotificationsPanel(
        embedded: false,
        asSidePanel: side,
        emptySubtitle: emptySubtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final content = _NotificationsBody(
      embedded: embedded,
      asSidePanel: asSidePanel,
      emptySubtitle: emptySubtitle,
    );

    if (embedded) {
      return SafeArea(bottom: false, child: content);
    }

    if (asSidePanel) {
      return PosSidePanelShell(child: content);
    }

    return PosMobileSheetFrame(child: content);
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody({
    required this.embedded,
    required this.asSidePanel,
    required this.emptySubtitle,
  });

  final bool embedded;
  final bool asSidePanel;
  final String? emptySubtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final alerts = pos.waiterAlerts;
    final unread = pos.waiterUnreadAlertCount;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final today = <WaiterAlert>[];
    final earlier = <WaiterAlert>[];
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    for (final alert in alerts) {
      if (!alert.at.toLocal().isBefore(dayStart)) {
        today.add(alert);
      } else {
        earlier.add(alert);
      }
    }

    final subtitle = unread > 0
        ? l10n.waiterNotificationsUnread(unread)
        : l10n.waiterNotificationsAllCaughtUp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            embedded ? 12 : (asSidePanel ? 18 : 16),
            embedded ? 8 : 12,
            8,
          ),
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
                  Icons.notifications_active_rounded,
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
                      l10n.waiterNavAlerts,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: unread > 0 ? accent : PosTheme.inkMuted,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              if (!embedded)
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        if (alerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                if (unread > 0)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      pos.markAllWaiterAlertsRead();
                    },
                    child: Text(l10n.waiterNotificationsMarkAllRead),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    pos.clearWaiterAlerts();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: Text(l10n.commonClear),
                ),
              ],
            ),
          ),
        Expanded(
          child: alerts.isEmpty
              ? PosEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: l10n.waiterAlertsEmptyTitle,
                  subtitle: emptySubtitle ?? l10n.waiterAlertsEmptySubtitle,
                  accent: accent,
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottom),
                  children: [
                    if (today.isNotEmpty) ...[
                      _SectionLabel(label: l10n.waiterNotificationsToday),
                      const SizedBox(height: 8),
                      for (var i = 0; i < today.length; i++) ...[
                        _NotificationCard(
                          alert: today[i],
                          onDismiss: () => pos.dismissWaiterAlert(today[i].id),
                        ),
                        if (i < today.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                    if (earlier.isNotEmpty) ...[
                      if (today.isNotEmpty) const SizedBox(height: 18),
                      _SectionLabel(label: l10n.waiterNotificationsEarlier),
                      const SizedBox(height: 8),
                      for (var i = 0; i < earlier.length; i++) ...[
                        _NotificationCard(
                          alert: earlier[i],
                          onDismiss: () =>
                              pos.dismissWaiterAlert(earlier[i].id),
                        ),
                        if (i < earlier.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: PosTheme.inkMuted,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.alert,
    required this.onDismiss,
  });

  final WaiterAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = (alert.source ?? '').toLowerCase().trim();
    final accent = switch (alert.type) {
      WaiterAlertType.kitchenReady => const Color(0xFF059669),
      WaiterAlertType.newOrder => const Color(0xFF2563EB),
      WaiterAlertType.marketplaceOrder => source.isNotEmpty
          ? marketplaceBrandColor(source)
          : const Color(0xFFE23744),
      WaiterAlertType.billRequested => const Color(0xFFD97706),
    };
    final icon = switch (alert.type) {
      WaiterAlertType.kitchenReady => Icons.restaurant_rounded,
      WaiterAlertType.newOrder => Icons.notifications_active_rounded,
      WaiterAlertType.marketplaceOrder => Icons.local_shipping_rounded,
      WaiterAlertType.billRequested => Icons.receipt_long_rounded,
    };
    final fill = accent.withValues(alpha: alert.isRead ? 0.08 : 0.14);

    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Builder(
        builder: (context) {
          final tone = posStatusColors('cancelled');
          return Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: tone.fg,
        ),
      );
        },
      ),
      child: Material(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PosTheme.radiusMd),
              border: Border.all(
                color: alert.isRead
                    ? PosTheme.border
                    : accent.withValues(alpha: 0.40),
              ),
              boxShadow: PosTheme.cardShadow(),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: -0.2,
                                color: PosTheme.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relativeTime(alert.at, l10n),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: alert.isRead
                                  ? PosTheme.inkMuted
                                  : accent,
                            ),
                          ),
                          if (!alert.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight:
                              alert.isRead ? FontWeight.w500 : FontWeight.w600,
                          color: PosTheme.ink.withValues(
                            alpha: alert.isRead ? 0.72 : 0.9,
                          ),
                        ),
                      ),
                      if (alert.isPriority ||
                          (alert.tableName != null &&
                              alert.tableName!.isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (alert.isPriority)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: fill,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  l10n.marketplacePriorityChip,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ),
                            if (alert.tableName != null &&
                                alert.tableName!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: fill,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  alert.tableName!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.commonClear,
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: PosTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

String _relativeTime(DateTime at, AppLocalizations l10n) {
  final local = at.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inSeconds < 45) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
  return DateFormat('MMM d').format(local);
}
