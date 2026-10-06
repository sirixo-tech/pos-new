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
      duration: const Duration(milliseconds: 900),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < widget.barCount; i++)
              Container(
                width: 4,
                height: widget.active
                    ? widget.height *
                          (0.28 +
                              0.72 *
                                  _level(
                                    _controller.value,
                                    i,
                                    widget.barCount,
                                  ))
                    : widget.height * 0.28,
                margin: EdgeInsets.only(
                  right: i == widget.barCount - 1 ? 0 : 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        );
      },
    );
  }

  double _level(double t, int index, int count) {
    final phase = (t + index / count) % 1;
    final wave = (phase < 0.5 ? phase : 1 - phase) * 2;
    return wave;
  }
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: soft.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const PosListeningBars(active: true, height: 22),
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
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  heard.isEmpty ? 'Say an item name' : heard,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PosTheme.ink,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Stop',
            onPressed: onStop,
            icon: Icon(Icons.stop_circle_rounded, color: soft.fg),
          ),
        ],
      ),
    );
  }
}
