import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../theme/pos_theme.dart';
import 'pos_overlay.dart';

class DayEndReportType {
  const DayEndReportType({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
}

List<DayEndReportType> dayEndReportTypes(AppLocalizations l10n) => [
      DayEndReportType(
        value: 'summary',
        label: l10n.reportsSalesSummary,
        description: l10n.reportsSalesSummaryDesc,
        icon: Icons.dashboard_outlined,
      ),
      DayEndReportType(
        value: 'consolidated',
        label: l10n.reportsTerminalConsolidated,
        description: l10n.reportsTerminalConsolidatedDesc,
        icon: Icons.payments_outlined,
      ),
      DayEndReportType(
        value: 'item',
        label: l10n.reportsItemWise,
        description: l10n.reportsItemWiseDesc,
        icon: Icons.list_alt_rounded,
      ),
      DayEndReportType(
        value: 'category',
        label: l10n.reportsCategoryWise,
        description: l10n.reportsCategoryWiseDesc,
        icon: Icons.folder_open_rounded,
      ),
      DayEndReportType(
        value: 'order_type',
        label: l10n.reportsOrderType,
        description: l10n.reportsOrderTypeDesc,
        icon: Icons.restaurant_rounded,
      ),
      DayEndReportType(
        value: 'channel',
        label: l10n.reportsSalesChannel,
        description: l10n.reportsSalesChannelDesc,
        icon: Icons.storefront_outlined,
      ),
      DayEndReportType(
        value: 'tax',
        label: l10n.reportsTaxSummary,
        description: l10n.reportsTaxSummaryDesc,
        icon: Icons.sell_outlined,
      ),
      DayEndReportType(
        value: 'staff',
        label: 'Staff',
        description: 'Staff sales for today',
        icon: Icons.badge_outlined,
      ),
      DayEndReportType(
        value: 'voids',
        label: 'Voids & cancellations',
        description: 'Voided and cancelled orders for today',
        icon: Icons.block_outlined,
      ),
    ];

/// Day-end reports for today’s branch sales (side panel on desktop).
class DayEndReportsSheet extends StatefulWidget {
  const DayEndReportsSheet({
    super.key,
    required this.onPrint,
    this.asSidePanel = false,
  });

  final Future<void> Function(String type) onPrint;
  final bool asSidePanel;

  static Future<void> open(
    BuildContext context, {
    required Future<void> Function(String type) onPrint,
  }) {
    final side = preferPosSidePanel(context);
    return showPosOverlay<void>(
      context: context,
      sidePanelWidth: 440,
      useSafeArea: false,
      builder: (_) => DayEndReportsSheet(
        onPrint: onPrint,
        asSidePanel: side,
      ),
    );
  }

  @override
  State<DayEndReportsSheet> createState() => _DayEndReportsSheetState();
}

class _DayEndReportsSheetState extends State<DayEndReportsSheet> {
  String? _printingType;

  Future<void> _print(DayEndReportType report) async {
    if (_printingType != null) return;
    setState(() => _printingType = report.value);
    try {
      await widget.onPrint(report.value);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _printingType = null);
    }
  }

  Widget _buildContent(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final l10n = context.l10n;
    final reports = dayEndReportTypes(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, widget.asSidePanel ? 18 : 16, 12, 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.print_rounded, color: soft.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reportsTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.reportsSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: PosTheme.inkMuted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                onPressed: _printingType == null
                    ? () => Navigator.of(context).pop()
                    : null,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final report = reports[index];
              final busy = _printingType == report.value;
              final disabled =
                  _printingType != null && _printingType != report.value;

              return Material(
                color: PosTheme.surface,
                borderRadius: BorderRadius.circular(PosTheme.radiusMd),
                child: InkWell(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMd),
                  onTap: disabled ? null : () => _print(report),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
                      border: Border.all(color: PosTheme.border),
                      boxShadow: PosTheme.cardShadow(),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(report.icon, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report.description,
                                style: TextStyle(
                                  color: PosTheme.inkMuted,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: disabled ? null : () => _print(report),
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.commonPrint),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSidePanel) {
      return PosSidePanelShell(child: _buildContent(context));
    }

    return PosMobileSheetFrame(child: _buildContent(context));
  }
}
