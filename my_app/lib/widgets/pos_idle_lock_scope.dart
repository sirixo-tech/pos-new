import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/pos_controller.dart';
import '../providers/pos_idle_lock_controller.dart';

/// Default idle timeout before the register locks (PIN required again).
const Duration kPosIdleLockTimeout = Duration(minutes: 2);

/// Watches pointer / keyboard activity and locks the POS session when idle.
///
/// Only arms while [PosController.phase] is [PosAppPhase.ready], a PIN is
/// configured, and [PosIdleLockController.enabled] is true. Wrap above the
/// [MaterialApp] navigator (via `builder`) so pushed routes like Manage still
/// reset the timer.
class PosIdleLockScope extends StatefulWidget {
  const PosIdleLockScope({
    super.key,
    required this.child,
    this.timeout = kPosIdleLockTimeout,
  });

  final Widget child;
  final Duration timeout;

  @override
  State<PosIdleLockScope> createState() => _PosIdleLockScopeState();
}

class _PosIdleLockScopeState extends State<PosIdleLockScope> {
  Timer? _timer;
  DateTime _lastBump = DateTime.fromMillisecondsSinceEpoch(0);
  PosController? _pos;
  PosIdleLockController? _idleLock;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = context.read<PosController>();
    if (!identical(_pos, pos)) {
      _pos?.removeListener(_onPosChanged);
      _pos = pos;
      _pos!.addListener(_onPosChanged);
    }
    final idleLock = context.read<PosIdleLockController>();
    if (!identical(_idleLock, idleLock)) {
      _idleLock?.removeListener(_onPosChanged);
      _idleLock = idleLock;
      _idleLock!.addListener(_onPosChanged);
    }
    _syncTimer();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _pos?.removeListener(_onPosChanged);
    _idleLock?.removeListener(_onPosChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _onPosChanged() => _syncTimer();

  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _bumpActivity();
    }
    return false;
  }

  bool get _canAutoLock {
    final pos = _pos;
    final idleLock = _idleLock;
    return pos != null &&
        idleLock != null &&
        idleLock.enabled &&
        pos.phase == PosAppPhase.ready &&
        pos.session?.hasPosPin == true;
  }

  void _syncTimer() {
    if (_canAutoLock) {
      _restartTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _bumpActivity() {
    if (!_canAutoLock) return;

    // Throttle restarts so continuous pointer moves don't thrash timers.
    final now = DateTime.now();
    if (now.difference(_lastBump) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastBump = now;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _onIdle);
  }

  void _onIdle() {
    if (!mounted || !_canAutoLock) return;
    _pos?.lockSession();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _bumpActivity(),
      onPointerMove: (_) => _bumpActivity(),
      onPointerSignal: (_) => _bumpActivity(),
      child: widget.child,
    );
  }
}
