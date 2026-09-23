import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../theme/pos_theme.dart';
import 'pos_ui.dart';

/// Compact keyboard key badge (e.g. `F3`, `⇧ Enter`).
class PosKeyBadge extends StatelessWidget {
  const PosKeyBadge(
    this.label, {
    super.key,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PosTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: PosTheme.inkMuted,
          letterSpacing: 0.2,
          height: 1.1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

Future<void> showPosShortcutsDialog(BuildContext context) {
  final accent = Theme.of(context).colorScheme.primary;
  final l10n = context.l10n;

  final rows = <(String keys, String action, String? note)>[
    ('/', l10n.shortcutsFocusSearch, l10n.shortcutsFocusSearchDesc),
    ('F2', l10n.shortcutsHoldTicket, l10n.shortcutsHoldTicketDesc),
    ('F3', l10n.shortcutsPay, l10n.shortcutsPayDesc),
    (l10n.shortcutsPayAlt, l10n.shortcutsPay, l10n.shortcutsPayAltDesc),
    ('F4 / F5', l10n.shortcutsHeldOrders, l10n.shortcutsHeldOrdersDesc),
    ('F6', l10n.shortcutsLockRegister, l10n.shortcutsLockRegisterDesc),
    (l10n.shortcutsLockAlt, l10n.shortcutsLockRegister, l10n.shortcutsLockAltDesc),
    (l10n.shortcutsClearCartKeys, l10n.shortcutsClearCart, l10n.shortcutsClearCartDesc),
    (
      'F11',
      context.posText('shellFullscreenShortcut', 'Fullscreen'),
      context.posText(
        'shellFullscreenShortcutDesc',
        'Toggle immersive / window fullscreen',
      ),
    ),
  ];

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (dialogContext) {
      return PosDialogShell(
        title: l10n.shortcutsTitle,
        subtitle: l10n.shortcutsSubtitle,
        icon: Icons.keyboard_alt_outlined,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _ShortcutRow(
                keys: rows[i].$1,
                action: rows[i].$2,
                note: rows[i].$3,
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PosTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: PosTheme.border.withValues(alpha: 0.9),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 18,
                    color: PosTheme.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.menuBarcodeTooltip,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: PosTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        footer: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n.shortcutsGotIt,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    },
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.keys,
    required this.action,
    this.note,
  });

  final String keys;
  final String action;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final parts = keys.split(' / ').expand((part) {
      // Keep compound keys like "⇧ Enter" as one badge.
      return [part.trim()];
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PosTheme.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.border.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '/',
                      style: TextStyle(
                        fontSize: 11,
                        color: PosTheme.inkFaint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                PosKeyBadge(parts[i]),
              ],
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: PosTheme.ink,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    note!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line hint under the search field on wide layouts.
class PosShortcutsHintLine extends StatelessWidget {
  const PosShortcutsHintLine({super.key, this.onOpenHelp});

  final VoidCallback? onOpenHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: onOpenHelp ?? () => showPosShortcutsDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            Icon(
              Icons.keyboard_alt_outlined,
              size: 13,
              color: PosTheme.inkFaint,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.shortcutsBarcodeNote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: PosTheme.inkFaint,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.shortcutsAll,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
