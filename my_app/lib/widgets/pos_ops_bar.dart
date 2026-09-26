import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../models/opening_hours_models.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import 'pos_close_shift_dialog.dart';
import 'pos_open_shift_dialog.dart';
import 'pos_ui.dart';

/// Opens the same guest-store confirm used by the header control.
Future<void> togglePosGuestStore(BuildContext context) async {
  final pos = context.read<PosController>();
  final currentlyAccepting =
      pos.bootstrap?.guestOrdering.acceptOnlineOrders ?? false;
  final l10n = context.l10n;
  final closing = currentlyAccepting;
  final ok = await showPosConfirmDialog(
    context,
    title: closing ? l10n.storeCloseTitle : l10n.storeOpenTitle,
    message: closing ? l10n.storeCloseMessage : l10n.storeOpenMessage,
    confirmLabel: closing ? l10n.storeCloseConfirm : l10n.storeOpenConfirm,
    destructive: closing,
    icon: closing
        ? Icons.store_mall_directory_outlined
        : Icons.storefront_rounded,
  );
  if (!ok || !context.mounted) return;
  final success = await context.read<PosController>().setGuestOrderingOpen(
        !currentlyAccepting,
      );
  if (!context.mounted) return;
  if (!success) {
    final error = context.read<PosController>().errorMessage;
    if (error != null) {
      showPosSnackBar(context, error, error: true);
    }
  }
}

/// Compact guest storefront/kiosk open-close pill (status + tap to toggle).
class PosStoreControl extends StatelessWidget {
  const PosStoreControl({super.key});

  @override
  Widget build(BuildContext context) {
    final guest = context.select(
      (PosController p) => p.bootstrap?.guestOrdering ?? const PosGuestOrdering(),
    );
    final canManage = context.select(
      (PosController p) =>
          p.bootstrap?.adminCapabilities.canManageSettings ?? false,
    );
    final l10n = context.l10n;
    final (tone, icon, label) = _statusPresentation(guest, l10n);
    final dark = PosTheme.isDark;
    final colors = switch (tone) {
      _ShiftTone.open => dark
          ? (
              bg: const Color(0xFF052E16),
              border: const Color(0xFF166534),
              fg: const Color(0xFF6EE7B7),
            )
          : (
              bg: const Color(0xFFECFDF5),
              border: const Color(0xFFA7F3D0),
              fg: const Color(0xFF047857),
            ),
      _ShiftTone.required => dark
          ? (
              bg: const Color(0xFF4C0519),
              border: const Color(0xFF9F1239),
              fg: const Color(0xFFFAA2B0),
            )
          : (
              bg: const Color(0xFFFEF2F2),
              border: const Color(0xFFFECACA),
              fg: const Color(0xFFB91C1C),
            ),
      _ShiftTone.idle => dark
          ? (
              bg: const Color(0xFF422006),
              border: const Color(0xFFB45309),
              fg: const Color(0xFFFDE68A),
            )
          : (
              bg: const Color(0xFFFFFBEB),
              border: const Color(0xFFFDE68A),
              fg: const Color(0xFFB45309),
            ),
    };

    final tooltip = canManage
        ? (guest.acceptOnlineOrders
            ? l10n.storeCloseTitle
            : l10n.storeOpenTitle)
        : label;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: canManage ? () => togglePosGuestStore(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: PosTheme.headerPx(32),
            padding: EdgeInsets.symmetric(horizontal: PosTheme.headerPx(8)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: PosTheme.headerPx(14), color: colors.fg),
                SizedBox(width: PosTheme.headerPx(4)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: PosTheme.headerPx(12),
                    fontWeight: FontWeight.w800,
                    color: colors.fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (_ShiftTone, IconData, String) _statusPresentation(
    PosGuestOrdering guest,
    AppLocalizations l10n,
  ) {
    if (guest.open) {
      return (_ShiftTone.open, Icons.storefront_rounded, l10n.storeOpen);
    }
    if (guest.isPaused || !guest.acceptOnlineOrders) {
      return (
        _ShiftTone.required,
        Icons.pause_circle_filled_rounded,
        l10n.storePaused,
      );
    }
    if (guest.isOutsideHours) {
      return (_ShiftTone.idle, Icons.schedule_rounded, l10n.storeOutsideHours);
    }
    return (
      _ShiftTone.idle,
      Icons.store_mall_directory_outlined,
      l10n.storeClosed,
    );
  }

}

/// Clock + terminal identity for the app bar title area.
class PosSessionIdentity extends StatelessWidget {
  const PosSessionIdentity({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Clock is the first thing to drop — terminal code matters more on POS.
    final showClock = MediaQuery.sizeOf(context).width >= 1180;

    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.only(right: 10),
            color: PosTheme.border,
          ),
          if (showClock) ...[
            _LiveClock(accent: accent),
            const SizedBox(width: 6),
          ],
          PosTerminalControl(accent: accent),
        ],
      ),
    );
  }
}

/// Shift open/close control (compact app-bar friendly).
class PosShiftControl extends StatelessWidget {
  const PosShiftControl({super.key});

  @override
  Widget build(BuildContext context) {
    final shift = context.select((PosController p) => p.bootstrap?.currentShift);
    final requireShift = context.select(
      (PosController p) => p.bootstrap?.requireShiftForPos ?? false,
    );
    final l10n = context.l10n;
    final dark = PosTheme.isDark;

    if (shift != null) {
      final openedClock = _formatOpenedClock(shift.openedAt);
      final sinceLabel =
          openedClock == null ? null : l10n.opsSince(openedClock);
      final tooltip = [
        l10n.opsShiftOpen,
        if (sinceLabel != null) sinceLabel,
        l10n.opsCloseShift,
      ].join(' · ');

      final bg = dark ? const Color(0xFF052E16) : const Color(0xFFECFDF5);
      final border = dark ? const Color(0xFF166534) : const Color(0xFFA7F3D0);
      final fg = dark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);

      return Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => PosCloseShiftDialog.show(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: PosTheme.headerPx(32),
              padding: EdgeInsets.fromLTRB(
                PosTheme.headerPx(10),
                0,
                PosTheme.headerPx(6),
                0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: fg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: fg.withValues(alpha: 0.45),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    l10n.opsShiftOpen,
                    style: TextStyle(
                      fontSize: PosTheme.headerPx(12),
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  if (openedClock != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 1,
                        height: 12,
                        color: fg.withValues(alpha: 0.28),
                      ),
                    ),
                    Text(
                      openedClock,
                      style: TextStyle(
                        fontSize: PosTheme.headerPx(11.5),
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Container(
                    width: PosTheme.headerPx(24),
                    height: PosTheme.headerPx(24),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF7F1D1D).withValues(alpha: 0.55)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.stop_rounded,
                      size: PosTheme.headerPx(15),
                      color: dark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final required = requireShift;
    final bg = required
        ? (dark ? const Color(0xFF4C0519) : const Color(0xFFFEF2F2))
        : (dark ? const Color(0xFF14532D) : const Color(0xFF16A34A));
    final border = required
        ? (dark ? const Color(0xFF9F1239) : const Color(0xFFFECACA))
        : (dark ? const Color(0xFF166534) : const Color(0xFF15803D));
    final fg = required
        ? (dark ? const Color(0xFFFAA2B0) : const Color(0xFFB91C1C))
        : Colors.white;
    final tooltip = required ? l10n.opsOpenToTakeOrders : l10n.opsOpenOptional;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => PosOpenShiftDialog.show(context),
          borderRadius: BorderRadius.circular(8),
            child: Container(
              height: PosTheme.headerPx(32),
              padding: EdgeInsets.symmetric(horizontal: PosTheme.headerPx(12)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  required
                      ? Icons.lock_open_rounded
                      : Icons.play_arrow_rounded,
                  size: PosTheme.headerPx(15),
                  color: fg,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.opsOpenShift,
                  style: TextStyle(
                    fontSize: PosTheme.headerPx(12),
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final _openedClock = DateFormat('h:mm a');

  static String? _formatOpenedClock(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return _openedClock.format(parsed.toLocal());
  }
}

/// Register / terminal chip.
class PosTerminalControl extends StatelessWidget {
  const PosTerminalControl({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final code = context.select(
      (PosController p) => p.selectedTerminal?.code ?? '',
    );
    final name = context.select(
      (PosController p) => p.selectedTerminal?.name.trim() ?? '',
    );
    final canChange = context.select(
      (PosController p) => (p.bootstrap?.posTerminals.length ?? 0) > 1,
    );
    final soft = posAccentSoft(accent);
    final width = MediaQuery.sizeOf(context).width;
    final showName =
        width >= 1280 && name.isNotEmpty && name.toUpperCase() != code;
    final label = code.isNotEmpty ? code : context.l10n.opsRegShort;

    return Material(
      color: soft.bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: canChange
            ? () => context.read<PosController>().changeTerminal()
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          constraints: BoxConstraints(maxWidth: showName ? 180 : 96),
          padding: EdgeInsets.fromLTRB(6, 0, canChange ? 4 : 8, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monitor_rounded, size: 13, color: soft.fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  showName ? '$label · $name' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: soft.fg,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (canChange) ...[
                Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: soft.fg.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _ShiftTone { open, required, idle }

class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.accent});

  final Color accent;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now;
  Timer? _timer;

  static final _timeFmt = DateFormat('h:mm');
  static final _periodFmt = DateFormat('a');

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Tick every second so the minute flips on time; display is still local.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = DateTime.now();
      if (next.minute != _now.minute || next.hour != _now.hour) {
        setState(() => _now = next);
      } else {
        _now = next;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(widget.accent);
    final local = _now.toLocal();
    final time = _timeFmt.format(local);
    final period = _periodFmt.format(local).toUpperCase();

    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(6, 0, 4, 0),
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: soft.fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: soft.fg),
          const SizedBox(width: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: soft.fg,
              letterSpacing: 0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: soft.fg.withValues(alpha: PosTheme.isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              period,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: soft.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
