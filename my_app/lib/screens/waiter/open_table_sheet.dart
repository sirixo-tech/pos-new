import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/pos_l10n.dart';
import '../../theme/pos_theme.dart';
import '../../utils/waiter_table_status.dart';
import '../../widgets/pos_ui.dart';

class OpenTableResult {
  const OpenTableResult({required this.guests});

  final int guests;
}

Future<OpenTableResult?> showOpenTableSheet(
  BuildContext context, {
  required String tableName,
  int initialGuests = 2,
  int maxGuests = 20,
}) {
  return showDialog<OpenTableResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => _OpenTableDialog(
      tableName: tableName,
      initialGuests: initialGuests,
      maxGuests: maxGuests,
    ),
  );
}

class _OpenTableDialog extends StatefulWidget {
  const _OpenTableDialog({
    required this.tableName,
    required this.initialGuests,
    required this.maxGuests,
  });

  final String tableName;
  final int initialGuests;
  final int maxGuests;

  @override
  State<_OpenTableDialog> createState() => _OpenTableDialogState();
}

class _OpenTableDialogState extends State<_OpenTableDialog> {
  static const _quickGuests = [1, 2, 3, 4, 6, 8];

  late int _guests;

  @override
  void initState() {
    super.initState();
    _guests = widget.initialGuests.clamp(1, widget.maxGuests);
  }

  void _setGuests(int value) {
    HapticFeedback.selectionClick();
    setState(() => _guests = value.clamp(1, widget.maxGuests));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availableStyle = waiterTableStatusStyle(
      WaiterTableStatus.available,
      isDark: isDark,
    );

    return PosDialogShell(
      title: l10n.waiterOpenTableTitle(widget.tableName),
      subtitle: l10n.waiterOpenTableSubtitle,
      icon: Icons.table_restaurant_rounded,
      headerColor: availableStyle.dot,
      maxWidth: 420,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: availableStyle.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: availableStyle.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: availableStyle.dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.waiterStatusAvailable} · ${l10n.waiterTableStatusHintAvailable}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: availableStyle.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.waiterGuestsLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: PosTheme.inkMuted,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in _quickGuests)
                if (n <= widget.maxGuests)
                  ChoiceChip(
                    label: Text('$n'),
                    selected: _guests == n,
                    onSelected: (_) => _setGuests(n),
                    showCheckmark: false,
                    selectedColor: posAccentSoft(accent).bg,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _guests == n
                          ? posAccentSoft(accent).fg
                          : PosTheme.ink,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: PosTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PosTheme.border),
            ),
            child: Row(
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onPressed: _guests > 1 ? () => _setGuests(_guests - 1) : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$_guests',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        l10n.waiterGuestsCount(_guests),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onPressed: _guests < widget.maxGuests
                      ? () => _setGuests(_guests + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, OpenTableResult(guests: _guests)),
            icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
            label: Text(l10n.waiterOpenTableConfirm),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: availableStyle.dot,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: PosTheme.surface,
          foregroundColor: PosTheme.ink,
          disabledBackgroundColor: PosTheme.surface.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: PosTheme.border),
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
        ),
        child: Icon(icon, size: 26),
      ),
    );
  }
}
