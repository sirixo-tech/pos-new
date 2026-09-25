import 'package:flutter/material.dart';

import '../../l10n/pos_l10n.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_overlay.dart';
import '../../widgets/pos_ui.dart';

/// Manage overlays: side panel on wide screens, bottom sheet on compact.
Future<T?> showAdminPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double sidePanelWidth = 480,
}) {
  final side = preferPosSidePanel(context);
  return showPosOverlay<T>(
    context: context,
    sidePanelWidth: sidePanelWidth,
    useSafeArea: true,
    builder: (ctx) {
      final child = builder(ctx);
      if (side) {
        return PosSidePanelShell(child: child);
      }
      return PosMobileSheetFrame(
        heightFactor: kPosAdminSheetHeightFactor,
        child: child,
      );
    },
  );
}

/// Colored status / payment / availability pill used across Manage screens.
class AdminChip extends StatelessWidget {
  const AdminChip({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color? color;
  final Color? backgroundColor;
  final IconData? icon;
  final bool compact;

  factory AdminChip.status(String status) {
    final key = status.toLowerCase();
    // Table statuses share the order/payment palette via [posStatusColors].
    final mapped = switch (key) {
      'available' => 'ready',
      'occupied' => 'preparing',
      'reserved' => 'pending',
      'cleaning' => 'abandoned',
      'partial' => 'pending',
      'timed_out' => 'failed',
      _ => key,
    };
    final tone = posStatusColors(mapped);
    return AdminChip(
      label: key == 'draft'
          ? 'Draft (held)'
          : _titleCase(status),
      color: tone.fg,
      backgroundColor: tone.bg,
    );
  }

  factory AdminChip.payment(String paymentStatus) {
    final key = paymentStatus.toLowerCase();
    final mapped = switch (key) {
      'partial' => 'pending',
      'timed_out' => 'failed',
      'refunded' => 'cancelled',
      _ => key,
    };
    final tone = posStatusColors(mapped);
    return AdminChip(
      label: switch (key) {
        'pending' => 'Payment pending',
        'failed' || 'failure' => 'Payment failed',
        _ => _titleCase(paymentStatus),
      },
      color: tone.fg,
      backgroundColor: tone.bg,
    );
  }

  factory AdminChip.availability({required bool active, required String onLabel, required String offLabel}) {
    final tone = posStatusColors(active ? 'ready' : 'draft');
    return AdminChip(
      label: active ? onLabel : offLabel,
      color: tone.fg,
      backgroundColor: tone.bg,
      icon: active ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
    );
  }

  static String _titleCase(String raw) {
    final t = raw.replaceAll('_', ' ').trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final seed = color ?? PosTheme.inkMuted;
    final soft = posAccentSoft(seed);
    final fg = color ?? soft.fg;
    final bg = backgroundColor ?? soft.bg;
    final border = PosTheme.isDark
        ? fg.withValues(alpha: 0.28)
        : seed.withValues(alpha: 0.22);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean Manage surface: white/slate fill, hairline border, no accent tint/shadow.
class AdminSurfaceCard extends StatelessWidget {
  const AdminSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final radius = borderRadius ?? BorderRadius.circular(PosTheme.radiusMd);

    Widget card = Material(
      color: PosTheme.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: PosTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            )
          : InkWell(
              onTap: onTap,
              borderRadius: radius,
              splashColor: accent.withValues(alpha: 0.08),
              highlightColor: accent.withValues(alpha: 0.04),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
    );

    if (width != null) {
      card = SizedBox(width: width, child: card);
    }
    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }
    return card;
  }
}

/// Horizontal action toolbar used above Manage lists.
class AdminToolbar extends StatelessWidget {
  const AdminToolbar({
    super.key,
    required this.children,
    this.leading,
  });

  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosTheme.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: PosTheme.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (leading != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: leading!,
                  ),
                ...children,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shared list / entity card for modifiers, slots, tables, hub tiles.
class AdminEntityCard extends StatelessWidget {
  const AdminEntityCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.chips = const [],
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<Widget> chips;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return AdminSurfaceCard(
      onTap: onTap,
      padding: EdgeInsets.all(dense ? 12 : 14),
      child: Row(
        children: [
          Container(
            width: dense ? 42 : 48,
            height: dense ? 42 : 48,
            decoration: BoxDecoration(
              color: PosTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PosTheme.border),
            ),
            child: Icon(icon, color: accent, size: dense ? 20 : 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: dense ? 14.5 : 15.5,
                    color: PosTheme.ink,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: PosTheme.inkFaint),
        ],
      ),
    );
  }
}

class AdminEmptyPane extends StatelessWidget {
  const AdminEmptyPane({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.45,
          child: Center(
            child: PosEmptyState(
              icon: icon,
              title: title,
              subtitle: subtitle,
              action: action,
            ),
          ),
        ),
      ],
    );
  }
}

class AdminErrorPane extends StatelessWidget {
  const AdminErrorPane({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: PosTheme.inkFaint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: PosTheme.inkMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminInlineError extends StatelessWidget {
  const AdminInlineError({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bg = PosTheme.isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEF2F2);
    final fg = PosTheme.isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
    return Material(
      color: bg,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.error_outline_rounded, color: fg),
        title: Text(
          message,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: fg),
          onPressed: onDismiss,
        ),
      ),
    );
  }
}

/// Consistent Manage form chrome — side panel on wide, sheet on compact.
Future<T?> showAdminFormDialog<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  IconData icon = Icons.edit_rounded,
  double maxWidth = 480,
  required Widget Function(BuildContext ctx, void Function(void Function()) setLocal) builder,
  required T? Function() onSave,
  String? saveLabel,
}) {
  return showAdminPanel<T>(
    context: context,
    sidePanelWidth: maxWidth.clamp(360, 560),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return PosDialogShell(
            title: title,
            subtitle: subtitle,
            icon: icon,
            maxWidth: maxWidth,
            embedded: true,
            onClose: () => Navigator.pop(ctx),
            body: builder(ctx, setLocal),
            footer: posDialogActionFooter(
              context: ctx,
              confirmLabel: saveLabel ?? context.l10n.commonSave,
              onCancel: () => Navigator.pop(ctx),
              onConfirm: () {
                final value = onSave();
                if (value != null) Navigator.pop(ctx, value);
              },
            ),
          );
        },
      );
    },
  );
}

class AdminCountBadge extends StatelessWidget {
  const AdminCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosTheme.border),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: PosTheme.inkMuted,
        ),
      ),
    );
  }
}
