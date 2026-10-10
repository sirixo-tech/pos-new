import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/pos_controller.dart';
import '../services/pos_daily_report.dart';
import '../theme/pos_theme.dart';
import '../widgets/pos_mobile_report_charts.dart';
import '../widgets/pos_sales_insights_card.dart';

enum _ViewKind {
  overview,
  sales,
  staff,
  discounts,
  category,
  item,
  tax,
  voids,
}

class PosViewReportsPage extends StatefulWidget {
  const PosViewReportsPage({super.key});

  @override
  State<PosViewReportsPage> createState() => _PosViewReportsPageState();
}

class _CachedViewReport {
  const _CachedViewReport(this.data, this.days, this.statuses);

  final PosViewReportData data;
  final List<PosDayRevenue> days;
  final List<PosStatusCount> statuses;
}

final _viewReportCache = <String, _CachedViewReport>{};

class _PosViewReportsPageState extends State<PosViewReportsPage> {
  _ViewKind _kind = _ViewKind.overview;
  late DateTime _from;
  late DateTime _to;
  var _preset = 'today';
  var _loading = true;
  var _ticket = 0;
  PosViewReportData? _data;
  List<PosDayRevenue> _days = const [];
  List<PosStatusCount> _statuses = const [];
  var _mixTab = 0;

  @override
  void initState() {
    super.initState();
    final today = _today();
    _from = today;
    _to = today;
    final cached = _viewReportCache[_cacheKey];
    if (cached != null) {
      _data = cached.data;
      _days = cached.days;
      _statuses = cached.statuses;
      _loading = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _fromText => DateFormat('yyyy-MM-dd').format(_from);
  String get _toText => DateFormat('yyyy-MM-dd').format(_to);
  String get _cacheKey => '${_kind.name}|$_fromText|$_toText';

  String _period() {
    final today = _today();
    final todayText = DateFormat('yyyy-MM-dd').format(today);
    final yesterday = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));
    final week = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 6)));
    if (_fromText == todayText && _toText == todayText) return 'today';
    if (_fromText == yesterday && _toText == yesterday) return 'yesterday';
    if (_fromText == week && _toText == todayText) return 'last_7_days';
    return 'all';
  }

  void _remember(PosViewReportData data) {
    _viewReportCache[_cacheKey] = _CachedViewReport(data, _days, _statuses);
  }

  Future<void> _load() async {
    final pos = context.read<PosController>();
    final session = pos.session;
    final serverUrl = pos.serverUrl;
    if (session == null || serverUrl == null || !mounted) return;
    final ticket = ++_ticket;
    final key = _cacheKey;
    final cached = _viewReportCache[key];
    if (cached != null) {
      setState(() {
        _data = cached.data;
        _days = cached.days;
        _statuses = cached.statuses;
        _loading = false;
      });
    } else {
      setState(() {
        _data = null;
        _days = const [];
        _statuses = const [];
        _loading = true;
      });
    }
    final types = switch (_kind) {
      _ViewKind.overview => ['summary', 'channel', 'order_type', 'consolidated', 'tax'],
      _ViewKind.sales => ['summary', 'channel', 'order_type', 'consolidated', 'item', 'category', 'tax'],
      _ViewKind.staff => <String>[],
      _ViewKind.discounts => ['summary'],
      _ViewKind.category => ['category', 'summary', 'tax'],
      _ViewKind.item => ['item', 'category', 'summary', 'tax'],
      _ViewKind.tax => ['tax'],
      _ViewKind.voids => <String>[],
    };
    final charts = _kind == _ViewKind.overview
        ? (
            loadReportRevenue(session: session, serverUrl: serverUrl),
            loadReportStatuses(session: session, serverUrl: serverUrl),
          )
        : null;
    try {
      final report = await loadPosViewReport(
        session: session,
        serverUrl: serverUrl,
        dateFrom: _fromText,
        dateTo: _toText,
        types: types,
        includeVoids: _kind == _ViewKind.voids,
        includeStaff: _kind == _ViewKind.staff,
        period: _period(),
        onPartial: (partial) {
          if (!mounted || ticket != _ticket) return;
          setState(() {
            _data = partial;
            _loading = false;
          });
          _remember(partial);
        },
      );
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _data = report;
        _loading = false;
      });
      _remember(report);
      if (charts != null) {
        final revenue = await charts.$1;
        final status = await charts.$2;
        if (!mounted || ticket != _ticket) return;
        setState(() {
          _days = revenue.days;
          _statuses = status.statuses;
        });
        _remember(report);
      }
    } catch (_) {
      if (!mounted || ticket != _ticket) return;
      setState(() => _loading = false);
    }
  }

  void _applyPreset(String preset) {
    final today = _today();
    late final DateTime from;
    late final DateTime to;
    switch (preset) {
      case 'yesterday':
        from = today.subtract(const Duration(days: 1));
        to = from;
      case 'last7':
        from = today.subtract(const Duration(days: 6));
        to = today;
      case 'month':
        from = DateTime(today.year, today.month, 1);
        to = today;
      default:
        from = today;
        to = today;
        preset = 'today';
    }
    setState(() {
      _preset = preset;
      _from = from;
      _to = to;
    });
    _load();
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _today(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = 'custom';
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
    _load();
  }

  String get _rangeLabel {
    switch (_preset) {
      case 'yesterday':
        return 'Yesterday';
      case 'last7':
        return '7 days';
      case 'month':
        return 'Month';
      case 'custom':
        final format = DateFormat('d MMM');
        if (_from == _to) return format.format(_from);
        return '${format.format(_from)}–${format.format(_to)}';
      default:
        return 'Today';
    }
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final data = _data;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final kind in _ViewKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _ReportKindChip(
                          label: _kindLabel(kind),
                          selected: _kind == kind,
                          onTap: () {
                            setState(() => _kind = kind);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Date range',
                onSelected: (value) {
                  if (value == 'custom') {
                    _pickCustom();
                  } else {
                    _applyPreset(value);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'today', child: Text('Today')),
                  PopupMenuItem(value: 'yesterday', child: Text('Yesterday')),
                  PopupMenuItem(value: 'last7', child: Text('Last 7 days')),
                  PopupMenuItem(value: 'month', child: Text('This month')),
                  PopupMenuItem(value: 'custom', child: Text('Custom dates')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _rangeLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      Icon(Icons.expand_more_rounded, size: 16, color: PosTheme.inkMuted),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (data?.error != null) ...[
          const SizedBox(height: 12),
          Text(data!.error!, style: const TextStyle(color: Color(0xFFEF4444))),
        ],
        const SizedBox(height: 12),
        ..._sections(data),
      ],
    );
  }

  List<Widget> _sections(PosViewReportData? data) {
    if (data == null && _loading) {
      return [
        const SizedBox(height: 24),
        Text('Loading report…', style: TextStyle(color: PosTheme.inkMuted)),
      ];
    }
    final report = data;
    if (report == null) {
      return [
        Text('Could not load this report.', style: TextStyle(color: PosTheme.inkMuted)),
      ];
    }
    switch (_kind) {
      case _ViewKind.overview:
        return [
          _kpis(report.summary, const ['total_revenue', 'total_orders', 'average_order', 'total_tax']),
          const SizedBox(height: 12),
          _Card(
            title: 'Revenue (last 7 days)',
            child: SizedBox(height: 180, child: _TrendLine(days: _days)),
          ),
          const SizedBox(height: 12),
          PosStatusChartCard(slices: _statuses, loading: _loading),
          const SizedBox(height: 12),
          _mixCard(report),
          const SizedBox(height: 12),
          const PosSalesInsightsCard(),
        ];
      case _ViewKind.sales:
        return [
          _kpis(report.summary, const ['total_revenue', 'total_orders', 'average_order']),
          const SizedBox(height: 12),
          _mixCard(report),
          const SizedBox(height: 12),
          _sliceCard('Top items', report.items),
          const SizedBox(height: 12),
          _sliceCard('Categories', report.categories),
        ];
      case _ViewKind.staff:
        return [_staff(report.staff)];
      case _ViewKind.discounts:
        return [
          _kpis(report.summary, const [
            'total_discounts',
            'total_tips',
            'total_service_charge',
            'total_extra_charges',
          ]),
        ];
      case _ViewKind.category:
        return [
          _kpis(report.summary, const ['total_revenue', 'total_tax', 'items_sold']),
          const SizedBox(height: 12),
          _sliceCard('Categories', report.categories),
        ];
      case _ViewKind.item:
        return [
          _kpis(report.summary, const ['total_revenue', 'items_sold', 'total_tax']),
          const SizedBox(height: 12),
          _sliceCard('Items', report.items),
        ];
      case _ViewKind.tax:
        return [
          _kpis(report.summary, const ['total_tax', 'total_revenue']),
          const SizedBox(height: 12),
          _sliceCard('Tax', report.taxes),
        ];
      case _ViewKind.voids:
        return [_voids(report.voids)];
    }
  }

  Widget _kpis(Map<String, double> summary, List<String> keys) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in keys)
          SizedBox(
            width: 150,
            child: _Kpi(
              label: _metricLabel(key),
              value: _metricValue(key, summary[key] ?? 0),
            ),
          ),
      ],
    );
  }

  Widget _mixCard(PosViewReportData report) {
    const labels = ['Channels', 'Order types', 'Payments'];
    final sets = [report.channels, report.orderTypes, report.payments];
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    return _Card(
      title: 'Mix',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Material(
                    color: _mixTab == i ? soft.bg : PosTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _mixTab = i),
                      child: Container(
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _mixTab == i ? accent : PosTheme.border,
                          ),
                        ),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _mixTab == i ? soft.fg : PosTheme.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _sliceBody(sets[_mixTab]),
        ],
      ),
    );
  }

  Widget _sliceBody(List<PosReportSlice> rows) {
    final visible = rows.where((row) => row.amount > 0 || (row.count ?? 0) > 0).toList();
    final maxAmount = visible.fold<double>(0, (max, row) => math.max(max, row.amount));
    if (visible.isEmpty) {
      return Text('Nothing in this range.', style: TextStyle(color: PosTheme.inkMuted));
    }
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: _ShareDonut(rows: visible.take(6).toList()),
        ),
        const SizedBox(height: 8),
        for (final row in visible.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BarRow(row: row, maxAmount: maxAmount),
          ),
      ],
    );
  }

  Widget _sliceCard(String title, List<PosReportSlice> rows) {
    return _Card(title: title, child: _sliceBody(rows));
  }

  Widget _staff(List<PosReportSlice> rows) {
    final orders = rows.fold<int>(0, (sum, row) => sum + (row.count ?? 0));
    final revenue = rows.fold<double>(0, (sum, row) => sum + row.amount);
    final tips = rows.fold<double>(0, (sum, row) => sum + row.tips);
    return Column(
      children: [
        _kpis({
          'total_revenue': revenue,
          'total_orders': orders.toDouble(),
          'total_tips': tips,
          'staff_count': rows.length.toDouble(),
        }, const ['total_revenue', 'total_orders', 'total_tips', 'staff_count']),
        const SizedBox(height: 12),
        _sliceCard('Revenue by staff', rows),
        const SizedBox(height: 12),
        _Card(
          title: 'Sales by staff',
          child: rows.isEmpty
              ? Text('No staff sales in this range.', style: TextStyle(color: PosTheme.inkMuted))
              : Column(
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(
                                    '${row.count ?? 0} orders · ${row.items.toStringAsFixed(0)} items',
                                    style: TextStyle(color: PosTheme.inkMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(_money(row.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _voids(List<Map<String, dynamic>> rows) {
    var cancelled = 0;
    var abandoned = 0;
    var lost = 0.0;
    for (final row in rows) {
      final status = '${row['status']}'.toLowerCase();
      if (status == 'abandoned') {
        abandoned += 1;
      } else {
        cancelled += 1;
      }
      lost += parseReportAmount(row['total']);
    }
    return Column(
      children: [
        _kpis({
          'cancelled': cancelled.toDouble(),
          'abandoned': abandoned.toDouble(),
          'lost': lost,
        }, const ['cancelled', 'abandoned', 'lost']),
        const SizedBox(height: 12),
        _Card(
          title: 'Recent voids',
          child: rows.isEmpty
              ? Text('No cancelled orders in this range.', style: TextStyle(color: PosTheme.inkMuted))
              : Column(
                  children: [
                    for (final row in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${row['order_number'] ?? row['id'] ?? 'Order'}'),
                        subtitle: Text('${row['status'] ?? ''} · ${row['staff_name'] ?? ''}'),
                        trailing: Text(_money(parseReportAmount(row['total']))),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReportKindChip extends StatelessWidget {
  const _ReportKindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    return Material(
      color: selected ? soft.bg : PosTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.35) : PosTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? soft.fg : PosTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

String _kindLabel(_ViewKind kind) {
  switch (kind) {
    case _ViewKind.overview:
      return 'Overview';
    case _ViewKind.sales:
      return 'Sales';
    case _ViewKind.staff:
      return 'Staff';
    case _ViewKind.discounts:
      return 'Discounts';
    case _ViewKind.category:
      return 'Category';
    case _ViewKind.item:
      return 'Item';
    case _ViewKind.tax:
      return 'Tax';
    case _ViewKind.voids:
      return 'Voids & cancellations';
  }
}

String _metricLabel(String key) {
  switch (key) {
    case 'total_revenue':
      return 'Revenue';
    case 'total_orders':
      return 'Orders';
    case 'items_sold':
      return 'Items sold';
    case 'average_order':
      return 'Avg order';
    case 'total_tax':
      return 'Tax';
    case 'total_discounts':
      return 'Discounts';
    case 'total_tips':
      return 'Tips';
    case 'total_service_charge':
      return 'Service charge';
    case 'total_extra_charges':
      return 'Extra charges';
    case 'staff_count':
      return 'Staff';
    case 'cancelled':
      return 'Cancelled';
    case 'abandoned':
      return 'Abandoned';
    case 'lost':
      return 'Lost revenue';
    default:
      return key;
  }
}

String _metricValue(String key, double value) {
  switch (key) {
    case 'total_orders':
    case 'items_sold':
    case 'staff_count':
    case 'cancelled':
    case 'abandoned':
      return value.toStringAsFixed(0);
    default:
      return _money(value);
  }
}

String _money(double value) => '₹${value.toStringAsFixed(2)}';

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: PosTheme.inkMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.row, required this.maxAmount});

  final PosReportSlice row;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxAmount <= 0 ? 0.0 : (row.amount / maxAmount).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(_money(row.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: PosTheme.border,
            color: const Color(0xFF4F46E5),
          ),
        ),
      ],
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.days});

  final List<PosDayRevenue> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Center(
        child: Text('No daily totals yet.', style: TextStyle(color: PosTheme.inkMuted)),
      );
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < days.length; i++)
                FlSpot(i.toDouble(), days[i].amount),
            ],
            isCurved: true,
            color: const Color(0xFF4F46E5),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF4F46E5).withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 450),
    );
  }
}

class _ShareDonut extends StatelessWidget {
  const _ShareDonut({required this.rows});

  final List<PosReportSlice> rows;

  static const _colors = [
    Color(0xFF4F46E5),
    Color(0xFF22C55E),
    Color(0xFFF5A524),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (sum, row) => sum + math.max(row.amount, 0));
    if (total <= 0) return const SizedBox.shrink();
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        sections: [
          for (var i = 0; i < rows.length; i++)
            PieChartSectionData(
              value: math.max(rows[i].amount, 0),
              color: _colors[i % _colors.length],
              radius: 28,
              showTitle: false,
            ),
        ],
      ),
      duration: const Duration(milliseconds: 450),
    );
  }
}
