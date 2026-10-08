import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/pos_theme.dart';

/// Equalizer shown while the microphone is open.
class PosListeningBars extends StatefulWidget {
  const PosListeningBars({
    super.key,
    required this.active,
    this.color,
    this.barCount = 5,
    this.height = 28,
  });

  final bool active;
  final Color? color;
  final int barCount;
  final double height;

  @override
  State<PosListeningBars> createState() => _PosListeningBarsState();
}

class _PosListeningBarsState extends State<PosListeningBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1680),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(PosListeningBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final thickness = (widget.height * 0.16).clamp(2.0, 3.2);
    final gap = thickness * 0.85;
    final naturalWidth =
        widget.barCount * thickness + (widget.barCount - 1) * gap;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : naturalWidth;
            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : widget.height;
            return CustomPaint(
              size: Size(width, height),
              painter: _WaveformPainter(
                t: widget.active ? _controller.value : 0,
                active: widget.active,
                color: color,
                barCount: widget.barCount,
                thickness: thickness,
                gap: gap,
                barExtent: math.min(height, widget.height),
              ),
            );
          },
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.t,
    required this.active,
    required this.color,
    required this.barCount,
    required this.thickness,
    required this.gap,
    required this.barExtent,
  });

  final double t;
  final bool active;
  final Color color;
  final int barCount;
  final double thickness;
  final double gap;
  final double barExtent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (active && size.shortestSide >= 28) {
      final pulse = (math.sin(t * math.pi * 2) + 1) / 2;
      canvas.drawCircle(
        center,
        size.shortestSide * (0.34 + pulse * 0.08),
        Paint()
          ..color = color.withValues(alpha: 0.16 * (1 - pulse * 0.35))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    final step = thickness + gap;
    final span = barCount * thickness + (barCount - 1) * gap;
    var x = center.dx - span / 2 + thickness / 2;
    for (var i = 0; i < barCount; i++) {
      final level = active ? _level(t, i, barCount) : 0.22;
      final barHeight = math.max(thickness, barExtent * level);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, center.dy),
          width: thickness,
          height: barHeight,
        ),
        const Radius.circular(99),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      x += step;
    }
  }

  /// Two overlapping waves, taller in the middle, so the mark reads as speech.
  double _level(double t, int index, int count) {
    final x = count <= 1 ? 0.5 : index / (count - 1);
    final fast = math.sin((t * 2 + x * 1.35) * math.pi * 2);
    final slow = math.sin((t * 0.85 + x * 2.1 + 0.6) * math.pi * 2);
    final mix = (fast * 0.68 + slow * 0.32 + 1) / 2;
    final middle = math.sin(x * math.pi);
    return (0.18 + 0.82 * mix * (0.42 + 0.58 * middle)).clamp(0.16, 1.0);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.active != active ||
      oldDelegate.color != color ||
      oldDelegate.barCount != barCount;
}

/// Compact “listening” strip used under search and on the AI menu screen.
class PosListeningStatus extends StatelessWidget {
  const PosListeningStatus({
    super.key,
    required this.transcript,
    required this.onStop,
    this.hint = 'Listening…',
  });

  final String transcript;
  final VoidCallback onStop;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final heard = transcript.trim();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -10),
            child: child,
          ),
        );
      },
      child: Material(
        color: PosTheme.surface,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SizedBox(
                  width: 52,
                  height: 40,
                  child: Center(
                    child: PosListeningBars(
                      active: true,
                      height: 36,
                      barCount: 5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: soft.fg,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      heard.isEmpty ? 'Say an item name' : heard,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PosTheme.ink,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Pause',
                child: Material(
                  color: accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onStop,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.pause_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
