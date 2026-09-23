import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/pos_app_info.dart';
import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/media_url.dart';
import '../utils/pos_animations.dart';
import '../widgets/pos_ui.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _loading = false;
  bool _confirmSignOutOpen = false;
  bool _signingOut = false;
  int _shakeToken = 0;
  Timer? _autoUnlockTimer;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  final FocusNode _pinFocus = FocusNode(debugLabel: 'pos_pin_unlock');

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _autoUnlockTimer?.cancel();
    _clockTimer?.cancel();
    _pinFocus.dispose();
    super.dispose();
  }

  /// Digits from the top row, numpad, or character (macOS / external keyboards).
  String? _digitFromKey(KeyEvent event) {
    final byKey = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    final fromKey = byKey[event.logicalKey];
    if (fromKey != null) return fromKey;
    final ch = event.character;
    if (ch != null && ch.length == 1 && RegExp(r'^\d$').hasMatch(ch)) {
      return ch;
    }
    return null;
  }

  KeyEventResult _onPinKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_loading) return KeyEventResult.handled;

    final digit = _digitFromKey(event);
    if (digit != null) {
      _append(digit);
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _unlock(manual: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _ensurePinFocus() {
    if (!_pinFocus.hasFocus) {
      _pinFocus.requestFocus();
    }
  }

  Future<void> _unlock({bool manual = false}) async {
    if (_pin.length < 4 || _loading) return;

    final attempted = _pin;
    setState(() => _loading = true);
    try {
      final ok = await context.read<PosController>().unlockWithPin(attempted);
      if (!mounted) return;
      if (!ok) {
        if (manual || attempted.length >= 6) {
          showPosSnackBar(
            context,
            context.read<PosController>().errorMessage ??
                context.l10n.pinIncorrect,
            error: true,
          );
          setState(() {
            _pin = '';
            _shakeToken++;
          });
          HapticFeedback.heavyImpact();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleAutoUnlock() {
    _autoUnlockTimer?.cancel();
    if (_pin.length < 6) return;
    _autoUnlockTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || _loading) return;
      _unlock(manual: true);
    });
  }

  void _append(String digit) {
    if (_loading || _pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = '$_pin$digit');
    _ensurePinFocus();
    _scheduleAutoUnlock();
  }

  void _backspace() {
    if (_loading || _pin.isEmpty) return;
    _autoUnlockTimer?.cancel();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
    _ensurePinFocus();
  }

  void _openSignOutConfirm() {
    setState(() => _confirmSignOutOpen = true);
  }

  Future<void> _performSignOut(PosController pos) async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await pos.logout();
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
          _confirmSignOutOpen = false;
        });
      }
    }
  }

  String _initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final accent = Theme.of(context).colorScheme.primary;
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final platform = pos.bootstrap?.platform ?? const PosPlatformBranding();
    final restaurant = pos.bootstrap?.restaurant;
    final branch = pos.bootstrap?.branch;
    final serverUrl = pos.session?.serverUrl;
    final platformName = platform.name.trim().isNotEmpty
        ? platform.name.trim()
        : PosAppInfo.displayName;
    final restaurantLogo = resolveMediaUrl(
      restaurant?.logoUrl,
      serverUrl: serverUrl,
    );
    final staffName = pos.session?.userName?.trim();
    final restaurantName = restaurant?.name.trim();
    final branchName = branch?.name.trim();
    final terminalLabel = pos.selectedTerminal?.name.trim().isNotEmpty == true
        ? pos.selectedTerminal!.name.trim()
        : pos.selectedTerminalCode ??
            pos.deviceBinding?.terminalName?.trim() ??
            pos.deviceBinding?.terminalCode;
    final l10n = context.l10n;
    final greeting = staffName != null && staffName.isNotEmpty
        ? l10n.lockWelcomeBackNamed(staffName.split(RegExp(r'\s+')).first)
        : l10n.lockWelcomeBack;
    final logoUrl = restaurantLogo;
    final location = [
      if (branchName != null && branchName.isNotEmpty) branchName,
      if (terminalLabel != null && terminalLabel.isNotEmpty) terminalLabel,
    ].join(' · ');

    final pinForm = _PinUnlockCard(
      wide: wide,
      restaurantName: restaurantName,
      greeting: greeting,
      accent: accent,
      pin: _pin,
      shakeToken: _shakeToken,
      loading: _loading,
      onDigit: _append,
      onBackspace: _backspace,
      onUnlock: () => _unlock(manual: true),
      onSignOut: _openSignOutConfirm,
    );

    // Lock sits above the app navigator — use an in-tree confirm, not showDialog.
    return Stack(
      fit: StackFit.expand,
      children: [
        Focus(
          focusNode: _pinFocus,
          autofocus: true,
          onKeyEvent: _onPinKey,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _ensurePinFocus,
            child: PosAuthScaffold(
              accent: accent,
              platform: platform,
              serverUrl: serverUrl,
              statusIcon: Icons.lock_rounded,
              statusLabel: l10n.lockRegisterLocked,
              logoUrl: logoUrl,
              headline: restaurantName?.isNotEmpty == true
                  ? restaurantName!
                  : platformName,
              locationLine: location.isNotEmpty ? location : null,
              personLabel: staffName != null && staffName.isNotEmpty
                  ? l10n.lockSignedInAs(staffName)
                  : null,
              personInitial: staffName != null && staffName.isNotEmpty
                  ? staffName.substring(0, 1)
                  : null,
              now: _now,
              fallbackInitials: _initials(restaurantName ?? staffName),
              fallbackIcon: Icons.lock_rounded,
              footerNote: l10n.lockUnlockWithPin,
              form: pinForm,
            ),
          ),
        ),
        if (_confirmSignOutOpen) ...[
          ModalBarrier(
            dismissible: !_signingOut,
            color: Colors.black.withValues(alpha: 0.5),
            onDismiss: _signingOut
                ? null
                : () => setState(() => _confirmSignOutOpen = false),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: PosDialogShell(
                title: l10n.authSignOutTitle,
                subtitle: l10n.confirmDestructiveSubtitle,
                icon: Icons.warning_amber_rounded,
                headerColor: const Color(0xFFB91C1C),
                onClose: _signingOut
                    ? null
                    : () => setState(() => _confirmSignOutOpen = false),
                body: Text(
                  l10n.authSignOutFromLock,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: PosTheme.ink,
                  ),
                ),
                footer: posDialogActionFooter(
                  context: context,
                  cancelLabel: l10n.commonCancel,
                  confirmLabel: l10n.commonSignOut,
                  destructive: true,
                  onCancel: _signingOut
                      ? () {}
                      : () => setState(() => _confirmSignOutOpen = false),
                  onConfirm:
                      _signingOut ? () {} : () => _performSignOut(pos),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PinUnlockCard extends StatelessWidget {
  const _PinUnlockCard({
    required this.wide,
    required this.restaurantName,
    required this.greeting,
    required this.accent,
    required this.pin,
    required this.shakeToken,
    required this.loading,
    required this.onDigit,
    required this.onBackspace,
    required this.onUnlock,
    required this.onSignOut,
  });

  final bool wide;
  final String? restaurantName;
  final String greeting;
  final Color accent;
  final String pin;
  final int shakeToken;
  final bool loading;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onUnlock;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PosSurfaceCard(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PosSlideFade(
            child: Column(
              children: [
                _LockBreathingBadge(accent: accent),
                if (!wide &&
                    restaurantName != null &&
                    restaurantName!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    restaurantName!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  greeting,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 22,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.lockEnterPin,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PosTheme.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          PosSlideFade(
            delay: const Duration(milliseconds: 80),
            child: _PinShake(
              shakeToken: shakeToken,
              child: _PinSlots(
                length: 6,
                filled: pin.length,
                accent: accent,
                error: shakeToken > 0 && pin.isEmpty,
              ),
            ),
          ),
          const SizedBox(height: 24),
          PosSlideFade(
            delay: const Duration(milliseconds: 140),
            child: _PinPad(
              accent: accent,
              enabled: !loading,
              onDigit: onDigit,
              onBackspace: onBackspace,
            ),
          ),
          const SizedBox(height: 16),
          PosSlideFade(
            delay: const Duration(milliseconds: 200),
            child: Column(
              children: [
                PosPrimaryButton(
                  label: loading
                      ? context.l10n.lockUnlocking
                      : context.l10n.lockUnlock,
                  icon: Icons.lock_open_rounded,
                  loading: loading,
                  color: accent,
                  onPressed: pin.length >= 4 ? onUnlock : null,
                ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: loading ? null : onSignOut,
                  child: Text(
                    context.l10n.commonSignOut,
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft breathing lock mark at the top of the unlock card.
class _LockBreathingBadge extends StatefulWidget {
  const _LockBreathingBadge({required this.accent});

  final Color accent;

  @override
  State<_LockBreathingBadge> createState() => _LockBreathingBadgeState();
}

class _LockBreathingBadgeState extends State<_LockBreathingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(begin: 1, end: 1.06)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  late final Animation<double> _glow = Tween<double>(begin: 0.12, end: 0.28)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(widget.accent);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: soft.bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.accent.withValues(alpha: 0.22 + _glow.value * 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: _glow.value),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Icon(
        Icons.lock_rounded,
        color: soft.fg,
        size: 24,
      ),
    );
  }
}

/// Decaying left/right shake used after an incorrect PIN.
class _PinShake extends StatelessWidget {
  const _PinShake({
    required this.shakeToken,
    required this.child,
  });

  final int shakeToken;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (shakeToken == 0) return child;

    return TweenAnimationBuilder<double>(
      key: ValueKey(shakeToken),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        final decay = 1 - t;
        final offsetX = decay * 14 * math.sin(t * math.pi * 7);
        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _PinSlots extends StatelessWidget {
  const _PinSlots({
    required this.length,
    required this.filled,
    required this.accent,
    required this.error,
  });

  final int length;
  final int filled;
  final Color accent;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    final borderColor = error ? Colors.red.shade400 : PosTheme.border;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isFilled = index < filled;
        final isActive = index == filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 42,
          height: 48,
          margin: EdgeInsets.only(right: index < length - 1 ? 8 : 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isFilled || isActive ? soft.bg : PosTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error && !isFilled
                  ? borderColor
                  : isActive
                      ? accent
                      : isFilled
                          ? accent.withValues(alpha: 0.4)
                          : borderColor,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: isFilled
                ? Container(
                    key: ValueKey('dot-$index-$filled'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: PosTheme.buttonShadow(accent),
                    ),
                  )
                : isActive
                    ? const _PinCursor(key: ValueKey('cursor'))
                    : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        );
      }),
    );
  }
}

class _PinCursor extends StatefulWidget {
  const _PinCursor({super.key});

  @override
  State<_PinCursor> createState() => _PinCursorState();
}

class _PinCursorState extends State<_PinCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 2,
        height: 20,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.accent,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final Color accent;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 64);
              }
              final isBack = key == '⌫';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _PadKey(
                  label: key,
                  isBack: isBack,
                  accent: accent,
                  enabled: enabled,
                  onTap: () => isBack ? onBackspace() : onDigit(key),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.label,
    required this.isBack,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool isBack;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Ink(
      width: 72,
      height: 64,
      decoration: BoxDecoration(
        color: isBack ? Colors.transparent : PosTheme.surfaceMuted,
        shape: BoxShape.circle,
        border: isBack
            ? null
            : Border.all(color: PosTheme.border.withValues(alpha: 0.8)),
      ),
      child: Center(
        child: isBack
            ? Icon(
                Icons.backspace_outlined,
                color: enabled ? accent : PosTheme.inkFaint,
                size: 22,
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: enabled ? PosTheme.ink : PosTheme.inkFaint,
                  height: 1,
                ),
              ),
      ),
    );

    return PosPressScale(
      scale: 0.92,
      onTap: enabled ? onTap : null,
      child: Material(
        color: Colors.transparent,
        child: content,
      ),
    );
  }
}
