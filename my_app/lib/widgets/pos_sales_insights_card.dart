import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pos_controller.dart';
import '../services/pos_api.dart';

/// AI sales and feedback summary on the reports overview.
///
/// Uses the same web route as the admin reports page:
/// `POST /ai/insights/generate`.
class PosSalesInsightsCard extends StatefulWidget {
  const PosSalesInsightsCard({super.key, this.generate});

  /// Test hook. Production calls [PosApi.generateSalesInsights].
  final Future<Map<String, dynamic>> Function(String timeframe)? generate;

  @override
  State<PosSalesInsightsCard> createState() => _PosSalesInsightsCardState();
}

class _PosSalesInsightsCardState extends State<PosSalesInsightsCard>
    with SingleTickerProviderStateMixin {
  static const _frames = <(String, String)>[
    ('week', 'Past week'),
    ('month', 'Past month'),
    ('year', 'Past year'),
  ];

  late final AnimationController _motion;
  String _timeframe = 'month';
  var _busy = false;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = widget.generate != null
          ? await widget.generate!(_timeframe)
          : await _generateFromSession();
      if (!mounted) return;
      setState(() => _report = report);
    } on PosApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Insights could not be generated. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _generateFromSession() {
    final session = context.read<PosController>().session;
    if (session == null) {
      throw PosApiException('Not signed in');
    }
    return PosApi().generateSalesInsights(session, timeframe: _timeframe);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2F7BFF),
            Color(0xFF3EE0FF),
            Color(0xFF3DDC8C),
            Color(0xFFB07CFF),
          ],
        ),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.5),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AI Sales & Feedback Insights',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Plain-language summary of sales and customer notes — no technical jargon.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                    initialValue: _timeframe,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    items: [
                      for (final frame in _frames)
                        DropdownMenuItem(value: frame.$1, child: Text(frame.$2)),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _timeframe = value);
                          },
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _generate,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F7BFF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Generate insights'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB42318), height: 1.35),
              ),
            ],
            const SizedBox(height: 16),
            if (report == null)
              _InsightEmpty(motion: _motion)
            else
              _InsightResult(report: report),
          ],
        ),
      ),
    );
  }
}

class _InsightEmpty extends StatelessWidget {
  const _InsightEmpty({required this.motion});

  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        children: [
          _InsightOrb(motion: motion),
          const SizedBox(height: 8),
          const Text(
            'No insights generated yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Click the button above to analyze your sales data and customer feedback using advanced AI.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _InsightResult extends StatelessWidget {
  const _InsightResult({required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final headline = '${report['headline'] ?? ''}'.trim();
    final stats = report['stats'] is Map
        ? Map<String, dynamic>.from(report['stats'] as Map)
        : const <String, dynamic>{};
    final sections = report['sections'] is List ? report['sections'] as List : const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFF3F7FF), Color(0xFFF7FFFB)],
            ),
            border: Border.all(color: const Color(0xFFD6E4FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (headline.isNotEmpty)
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ('${stats['timeframe_label'] ?? ''}'.trim().isNotEmpty)
                      _Stat(
                        label: 'Period',
                        value: '${stats['timeframe_label']}',
                      ),
                    if (stats['orders'] != null)
                      _Stat(label: 'Orders', value: '${stats['orders']}'),
                    if (stats['revenue'] != null)
                      _Stat(label: 'Revenue', value: '${stats['revenue']}'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < sections.length; i++)
          if (sections[i] is Map)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Section(
                index: i,
                section: Map<String, dynamic>.from(sections[i] as Map),
              ),
            ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.index, required this.section});

  final int index;
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.trending_up_rounded,
      Icons.restaurant_rounded,
      Icons.format_quote_rounded,
      Icons.lightbulb_rounded,
    ];
    const colors = [
      Color(0xFF047857),
      Color(0xFFB45309),
      Color(0xFF0369A1),
      Color(0xFF6D28D9),
    ];
    final color = colors[index % colors.length];
    final bullets = section['bullets'] is List
        ? (section['bullets'] as List)
            .map((item) => '$item'.trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : const <String>[];
    final summary = '${section['summary'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icons[index % icons.length], size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${section['title'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2F7BFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        bullet,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InsightOrb extends StatelessWidget {
  const _InsightOrb({required this.motion});

  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, _) {
          return CustomPaint(
            painter: _InsightOrbPainter(t: motion.value),
          );
        },
      ),
    );
  }
}

class _InsightOrbPainter extends CustomPainter {
  const _InsightOrbPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Offset.zero & size;
    final turn = t * math.pi * 2;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(turn),
          colors: const [
            Color(0xFF3DDC8C),
            Color(0xFF3EE0FF),
            Color(0xFF2F7BFF),
            Color(0xFFB07CFF),
            Color(0xFF3DDC8C),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius * 0.62,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF8FD4FF), Color(0xFF2F7BFF), Color(0xFF12305C)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawCircle(
      center,
      radius - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _InsightOrbPainter oldDelegate) => oldDelegate.t != t;
}
