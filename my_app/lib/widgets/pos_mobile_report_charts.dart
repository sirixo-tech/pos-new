import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/pos_daily_report.dart';
import '../theme/pos_theme.dart';

class PosRevenueChartCard extends StatelessWidget {
  const PosRevenueChartCard({
    super.key,
    required this.days,
    required this.loading,
    this.error,
  });

  final List<PosDayRevenue> days;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      icon: Icons.show_chart_rounded,
      title: 'Revenue (last 7 days)',
      loading: loading,
      error: days.isEmpty ? null : error,
      child: SizedBox(
        height: 210,
        child: days.isEmpty
            ? Center(
                child: Text(
                  loading
                      ? 'Loading revenue…'
                      : (error ?? 'Could not load revenue for the last 7 days.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PosTheme.inkMuted, height: 1.35),
                ),
              )
            : CustomPaint(
                painter: _RevenuePainter(
                  days: days,
                  labelColor: PosTheme.inkMuted,
                  gridColor: PosTheme.border,
                  lineColor: const Color(0xFF4F46E5),
                ),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class PosStatusChartCard extends StatelessWidget {
  const PosStatusChartCard({
    super.key,
    required this.slices,
    required this.loading,
    this.error,
  });

  final List<PosStatusCount> slices;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final visible = slices.where((slice) => slice.count > 0).toList();
    return _ChartCard(
      icon: Icons.donut_large_rounded,
      title: 'Orders by status',
      loading: loading,
      error: visible.isEmpty ? null : error,
      child: visible.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                loading
                    ? 'Loading orders…'
                    : (error ?? 'No orders in the last 7 days.'),
                style: TextStyle(color: PosTheme.inkMuted, height: 1.35),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 168,
                  child: CustomPaint(
                    painter: _DonutPainter(slices: visible),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    for (final slice in slices)
                      _LegendDot(
                        color: Color(slice.colorValue),
                        label: '${slice.label} ${slice.count}',
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.icon,
    required this.title,
    required this.loading,
    required this.child,
    this.error,
  });

  final IconData icon;
  final String title;
  final bool loading;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: PosTheme.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: PosTheme.ink,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: PosTheme.inkMuted, fontSize: 12, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PosTheme.ink,
          ),
        ),
      ],
    );
  }
}

class _RevenuePainter extends CustomPainter {
  _RevenuePainter({
    required this.days,
    required this.labelColor,
    required this.gridColor,
    required this.lineColor,
  });

  final List<PosDayRevenue> days;
  final Color labelColor;
  final Color gridColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const left = 44.0;
    const bottom = 22.0;
    final plotWidth = size.width - left - 4;
    final plotHeight = size.height - bottom - 8;
    if (plotWidth < 8 || plotHeight < 8) return;
    final plot = Rect.fromLTWH(left, 8, plotWidth, plotHeight);
    final maxAmount = days.fold<double>(0, (max, day) {
      final amount = day.amount.isFinite ? day.amount : 0.0;
      return math.max(max, amount);
    });
    final top = _niceMax(maxAmount);
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var step = 0; step <= 4; step++) {
      final t = step / 4;
      final y = plot.bottom - plot.height * t;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        _axisLabel(top * t),
        Offset(0, y - 6),
        labelColor,
        width: left - 6,
        align: TextAlign.right,
      );
    }

    final points = <Offset>[];
    for (var i = 0; i < days.length; i++) {
      final x = days.length == 1
          ? plot.center.dx
          : plot.left + plot.width * i / (days.length - 1);
      final amount = days[i].amount.isFinite ? days[i].amount : 0.0;
      final y = plot.bottom - plot.height * (amount / top);
      points.add(Offset(x, y));
      _text(
        canvas,
        reportDayLabel(days[i].day),
        Offset(x - 22, plot.bottom + 4),
        labelColor,
        width: 44,
        align: TextAlign.center,
        size: 10,
      );
    }

    final line = _curve(points);
    final fill = Path.from(line)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = lineColor.withValues(alpha: 0.14),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _curve(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }
    return path;
  }

  double _niceMax(double value) {
    if (value <= 0) return 1;
    final exponent = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final fraction = value / exponent;
    final nice = fraction <= 1
        ? 1
        : fraction <= 2
            ? 2
            : fraction <= 5
                ? 5
                : 10;
    return nice * exponent;
  }

  String _axisLabel(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) {
      final scaled = value / 1000;
      final text = scaled == scaled.roundToDouble()
          ? scaled.toStringAsFixed(0)
          : scaled.toStringAsFixed(1);
      return '${text}k';
    }
    return value.round().toString();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    required double width,
    required TextAlign align,
    double size = 11,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w500),
      ),
      textAlign: align,
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: math.max(width, 1));
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RevenuePainter oldDelegate) {
    return oldDelegate.days != days;
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<PosStatusCount> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.count);
    if (total <= 0) return;
    final side = math.min(size.width, size.height);
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: side * 0.36,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.16
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.count / total) * math.pi * 2;
      paint.color = Color(slice.colorValue);
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.slices != slices;
}
