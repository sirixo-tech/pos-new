import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/pos_l10n.dart';
import '../theme/pos_theme.dart';

String statusChangeChannelLabel(BuildContext context, String? channel) {
  switch ((channel ?? '').toLowerCase()) {
    case 'admin':
      return context.posText('statusChangeChannelAdmin', 'Admin');
    case 'pos':
      return context.posText('statusChangeChannelPos', 'POS');
    case 'kitchen':
      return context.posText('statusChangeChannelKitchen', 'Kitchen');
    case 'kiosk':
      return context.posText('statusChangeChannelKiosk', 'Kiosk');
    case 'storefront':
      return context.posText('statusChangeChannelStorefront', 'Online');
    case 'marketplace':
      return context.posText('statusChangeChannelMarketplace', 'Marketplace');
    case 'system':
      return context.posText('statusChangeChannelSystem', 'System');
    default:
      if (channel == null || channel.isEmpty) return '';
      return channel.replaceAll('_', ' ');
  }
}

/// Vertical timeline for order / payment status change audit logs.
class StatusChangeTimeline extends StatelessWidget {
  const StatusChangeTimeline({
    super.key,
    required this.logs,
    required this.statusLabel,
    this.accent = const Color(0xFF7C3AED),
  });

  final List<Map<String, dynamic>> logs;
  final String Function(String status) statusLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < logs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _StatusChangeRow(
            log: logs[i],
            statusLabel: statusLabel,
            accent: accent,
            isLast: i == logs.length - 1,
          ),
        ],
      ],
    );
  }
}

class _StatusChangeRow extends StatelessWidget {
  const _StatusChangeRow({
    required this.log,
    required this.statusLabel,
    required this.accent,
    required this.isLast,
  });

  final Map<String, dynamic> log;
  final String Function(String status) statusLabel;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final from = statusLabel('${log['from_status'] ?? '—'}');
    final to = statusLabel('${log['to_status'] ?? '—'}');
    final note = '${log['note'] ?? ''}'.trim();
    final user = log['user'] is Map
        ? Map<String, dynamic>.from(log['user'] as Map)
        : null;
    final actor = '${user?['name'] ?? ''}'.trim().isNotEmpty
        ? context.posText(
            'statusChangedBy',
            'By {name}',
            {'name': '${user!['name']}'},
          )
        : context.posText('statusChangedBySystem', 'System');
    final channel = statusChangeChannelLabel(context, '${log['channel'] ?? ''}');
    final createdAt = _formatDate(log['created_at']);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: PosTheme.surface, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: accent.withValues(alpha: 0.28),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: PosTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PosTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Chip(
                        label: from,
                        background: PosTheme.isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        foreground: PosTheme.inkMuted,
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: PosTheme.inkMuted,
                      ),
                      _Chip(
                        label: to,
                        background: accent.withValues(alpha: 0.12),
                        foreground: accent,
                        bold: true,
                      ),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 12,
                        color: PosTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        actor,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PosTheme.ink,
                        ),
                      ),
                      if (channel.isNotEmpty)
                        _Chip(
                          label: channel,
                          icon: Icons.devices_rounded,
                          background: accent.withValues(alpha: 0.1),
                          foreground: accent,
                          compact: true,
                        ),
                      Text(
                        createdAt,
                        style: TextStyle(
                          fontSize: 11,
                          color: PosTheme.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return '$value';
    return DateFormat('MMM d · h:mm a').format(parsed);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.bold = false,
    this.compact = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool bold;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
