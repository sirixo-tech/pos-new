import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../services/pos_daily_report.dart';
import '../theme/pos_theme.dart';
import '../widgets/day_end_reports_sheet.dart';

/// Phone reports tab: today's figures, then the existing printable slips.
class PosMobileReportsPage extends StatefulWidget {
  const PosMobileReportsPage({super.key, required this.onPrint});

  final Future<void> Function(String type) onPrint;

  @override
  State<PosMobileReportsPage> createState() => _PosMobileReportsPageState();
}

class _PosMobileReportsPageState extends State<PosMobileReportsPage> {
  PosDailyReport? _report;
  var _loading = true;
  String? _printing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pos = context.read<PosController>();
    final session = pos.session;
    final serverUrl = pos.serverUrl;
    if (session == null || serverUrl == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final report = await fetchTodaySummary(
        session: session,
        serverUrl: serverUrl,
        date: date,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print(DayEndReportType report) async {
    if (_printing != null) return;
    setState(() => _printing = report.value);
    try {
      await widget.onPrint(report.value);
    } finally {
      if (mounted) setState(() => _printing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final orders = context.select((PosController p) => p.todayOrderCount);
    final reports = dayEndReportTypes(l10n);
    final today = DateFormat('d MMM yyyy').format(DateTime.now());
    final figures = _report?.figures ?? const <PosDailyFigure>[];
    final lines = _report?.lines ?? const <PosDailyFigure>[];

    return ColoredBox(
      color: PosTheme.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Today',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            today,
            style: TextStyle(color: PosTheme.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const LinearProgressIndicator(minHeight: 3)
          else if (figures.isEmpty && lines.isEmpty)
            _card(
              child: Text(
                orders > 0
                    ? '$orders orders so far today. Print a slip below for the full breakdown.'
                    : 'Print a slip below for today’s full breakdown.',
                style: TextStyle(color: PosTheme.inkMuted, height: 1.35),
              ),
            )
          else ...[
            if (figures.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      figures.first.label,
                      style: TextStyle(
                        color: soft.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      figures.first.display,
                      style: TextStyle(
                        color: PosTheme.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (orders > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$orders orders',
                        style: TextStyle(color: PosTheme.inkMuted, fontSize: 13),
                      ),
                    ],
                    if (figures.length > 1) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final figure in figures.skip(1))
                            _chip(figure.label, figure.display),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              _card(
                child: Column(
                  children: [
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i > 0) Divider(height: 16, color: PosTheme.border),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lines[i].label,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            lines[i].display,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_report?.note != null) ...[
              const SizedBox(height: 8),
              Text(
                _report!.note!,
                style: TextStyle(color: PosTheme.inkMuted, fontSize: 12),
              ),
            ],
          ],
          const SizedBox(height: 22),
          Text(
            l10n.reportsTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.reportsSubtitle,
            style: TextStyle(color: PosTheme.inkMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          for (final report in reports) ...[
            _printTile(report, accent),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: PosTheme.inkMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: child,
    );
  }

  Widget _printTile(DayEndReportType report, Color accent) {
    final busy = _printing == report.value;
    final disabled = _printing != null && !busy;
    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : () => _print(report),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PosTheme.border),
          ),
          child: Row(
            children: [
              Icon(report.icon, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      report.description,
                      style: TextStyle(color: PosTheme.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.print_outlined, color: PosTheme.inkMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
