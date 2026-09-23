import 'package:flutter/material.dart';

/// Light motion helpers inspired by the kiosk app (staff-density friendly).
class PosSlideFade extends StatelessWidget {
  const PosSlideFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.04),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    const animMs = 420;
    final totalMs = animMs + delay.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.linear,
      builder: (context, value, child) {
        final elapsed = value * totalMs;
        final t = Curves.easeOutCubic.transform(
          ((elapsed - delay.inMilliseconds) / animMs).clamp(0.0, 1.0),
        );
        final dy = offset.dy == 0 ? 1.0 : offset.dy.abs() / 0.04;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16 * dy),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class PosPressScale extends StatefulWidget {
  const PosPressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PosPressScale> createState() => _PosPressScaleState();
}

class _PosPressScaleState extends State<PosPressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
