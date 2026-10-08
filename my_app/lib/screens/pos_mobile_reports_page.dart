import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../theme/pos_theme.dart';
import '../widgets/day_end_reports_sheet.dart';
import 'pos_view_reports_page.dart';

/// Phone reports tab: owner-style figures, or the printable slips.
class PosMobileReportsPage extends StatefulWidget {
  const PosMobileReportsPage({super.key, required this.onPrint});

  final Future<void> Function(String type) onPrint;

  @override
  State<PosMobileReportsPage> createState() => _PosMobileReportsPageState();
}

class _PosMobileReportsPageState extends State<PosMobileReportsPage> {
  String? _printing;
  var _viewReports = true;

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
    final accent = Theme.of(context).colorScheme.primary;
    final reports = dayEndReportTypes(context.l10n);

    return ColoredBox(
      color: PosTheme.canvas,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(child: _modeButton('View reports', true, accent)),
                const SizedBox(width: 8),
                Expanded(child: _modeButton('Print reports', false, accent)),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _viewReports ? 0 : 1,
              children: [
                const PosViewReportsPage(),
                _printReports(accent, reports),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool view, Color accent) {
    final selected = _viewReports == view;
    return Material(
      color: selected ? posAccentSoft(accent).bg : PosTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _viewReports = view),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? accent.withValues(alpha: 0.35) : PosTheme.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? posAccentSoft(accent).fg : PosTheme.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _printReports(Color accent, List<DayEndReportType> reports) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final report in reports) ...[
          _printTile(report, accent),
          const SizedBox(height: 8),
        ],
      ],
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
