import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pos_models.dart';

class PosDailyFigure {
  const PosDailyFigure({required this.label, required this.display});

  final String label;
  final String display;
}

class PosDailyReport {
  const PosDailyReport({
    required this.title,
    required this.figures,
    required this.lines,
    this.note,
  });

  final String title;
  final List<PosDailyFigure> figures;
  final List<PosDailyFigure> lines;
  final String? note;
}

/// Today's sales summary from the same thermal report the register already prints.
Future<PosDailyReport> fetchTodaySummary({
  required PosSession session,
  required String serverUrl,
  required String date,
}) async {
  final document = await _fetchThermalDocument(
    session: session,
    serverUrl: serverUrl,
    type: 'summary',
    date: date,
  );
  final note = document['amounts_note']?.toString().trim();
  return PosDailyReport(
    title: document['title']?.toString().trim().isNotEmpty == true
        ? document['title'].toString()
        : 'Today',
    figures: _figures(document['totals']),
    lines: _figures(document['rows']),
    note: note == null || note.isEmpty ? null : note,
  );
}

List<PosDailyFigure> _figures(Object? raw) {
  if (raw is! List) return const [];
  final figures = <PosDailyFigure>[];
  for (final row in raw) {
    if (row is! Map) continue;
    final label =
        (row['label'] ?? row['description'] ?? row['name'] ?? row['code'] ?? '')
            .toString()
            .trim();
    final display =
        (row['display'] ?? row['amount'] ?? row['value'] ?? row['right'] ?? '')
            .toString()
            .trim();
    if (label.isEmpty && display.isEmpty) continue;
    figures.add(
      PosDailyFigure(
        label: label.isEmpty ? 'Total' : label,
        display: display.isEmpty ? '—' : display,
      ),
    );
  }
  return figures;
}

class PosDayRevenue {
  const PosDayRevenue({required this.day, required this.amount});

  final DateTime day;
  final double amount;
}

class PosStatusCount {
  const PosStatusCount({
    required this.status,
    required this.label,
    required this.count,
    required this.colorValue,
  });

  final String status;
  final String label;
  final int count;
  final int colorValue;
}

const posReportStatusSlices = <({String status, String label, int color})>[
  (status: 'pending', label: 'Pending', color: 0xFFF5A524),
  (status: 'confirmed', label: 'Confirmed', color: 0xFF3B82F6),
  (status: 'preparing', label: 'Preparing', color: 0xFF8B5CF6),
  (status: 'ready', label: 'Ready', color: 0xFF22C55E),
  (status: 'delivered', label: 'Delivered', color: 0xFF14B8A6),
  (status: 'cancelled', label: 'Cancelled', color: 0xFFEF4444),
];

/// Seven calendar days ending today, oldest first.
List<DateTime> last7ReportDays(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var offset = 6; offset >= 0; offset--)
      today.subtract(Duration(days: offset)),
  ];
}

double parseReportAmount(Object? raw) {
  if (raw is num) return raw.isFinite ? raw.toDouble() : 0;
  final text = '${raw ?? ''}'.replaceAll(RegExp(r'[^0-9.\-]'), '');
  final value = double.tryParse(text) ?? 0;
  return value.isFinite ? value : 0;
}

const _reportMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String reportDayLabel(DateTime day) => '${_reportMonths[day.month - 1]} ${day.day}';

int reportCount(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) {
    if (!raw.isFinite) return 0;
    return raw.toInt();
  }
  return int.tryParse('${raw ?? ''}'.trim()) ?? 0;
}

/// `meta.total` from the admin orders list, including the wrapped payload.
int ordersTotalFromResponse(Object? decoded) {
  if (decoded is! Map) return 0;
  final root = Map<String, dynamic>.from(decoded);
  final pages = <Map>[root];
  final data = root['data'];
  if (data is Map) pages.add(Map<String, dynamic>.from(data));
  for (final page in pages) {
    for (final key in const ['meta', 'pagination']) {
      final meta = page[key];
      if (meta is Map && meta['total'] != null) return reportCount(meta['total']);
    }
  }
  return 0;
}

class PosReportChartData {
  const PosReportChartData({
    required this.days,
    required this.statuses,
    this.revenueError,
    this.statusError,
  });

  final List<PosDayRevenue> days;
  final List<PosStatusCount> statuses;
  final String? revenueError;
  final String? statusError;
}

/// Sales total from a thermal summary document. Order counts are skipped.
double revenueFromThermalDocument(Map<String, dynamic> document) {
  final totals = document['totals'];
  if (totals is! List) return 0;
  for (final row in totals) {
    if (row is! Map) continue;
    final label = '${row['label'] ?? row['description'] ?? ''}'.toUpperCase();
    if (label.contains('ORDER')) continue;
    if (label.contains('TOTAL') || label.contains('REVENUE') || label.contains('SALES')) {
      return parseReportAmount(
        row['amount'] ?? row['value'] ?? row['display'] ?? row['right'],
      );
    }
  }
  return 0;
}

/// Daily sales totals. A few days are in flight together so the line does not
/// wait on seven full round trips, without bursting every report call at once.
Future<PosReportChartData> loadReportRevenue({
  required PosSession session,
  required String serverUrl,
  DateTime? now,
  http.Client? client,
}) async {
  final ownClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final days = last7ReportDays(now ?? DateTime.now());
    final amounts = List<double?>.filled(days.length, null);
    String? revenueError;
    var failures = 0;
    var stop = false;
    var next = 0;

    Future<void> worker() async {
      while (!stop) {
        final index = next;
        next += 1;
        if (index >= days.length) return;
        try {
          final document = await _fetchThermalDocument(
            session: session,
            serverUrl: serverUrl,
            type: 'summary',
            date: _reportDate(days[index]),
            client: httpClient,
          );
          amounts[index] = revenueFromThermalDocument(document);
        } on _ChartRequestException catch (error) {
          failures += 1;
          amounts[index] = 0;
          if (error.stop) {
            stop = true;
            revenueError = error.message;
          }
        } catch (_) {
          failures += 1;
          amounts[index] = 0;
        }
      }
    }

    final width = days.length < 3 ? days.length : 3;
    await Future.wait([for (var i = 0; i < width; i++) worker()]);
    if (revenueError == null && failures == days.length) {
      revenueError = 'Could not load revenue for the last 7 days.';
    }
    return PosReportChartData(
      days: [
        for (var i = 0; i < days.length; i++)
          PosDayRevenue(day: days[i], amount: amounts[i] ?? 0),
      ],
      statuses: const [],
      revenueError: revenueError,
    );
  } finally {
    if (ownClient) httpClient.close();
  }
}

/// One orders-list total per status, together. Same query the orders screen uses.
Future<PosReportChartData> loadReportStatuses({
  required PosSession session,
  required String serverUrl,
  http.Client? client,
}) async {
  final ownClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    String? statusError;
    var failures = 0;
    var rateLimited = false;
    final counts = await Future.wait(posReportStatusSlices.map((slice) async {
      try {
        final total = await _fetchStatusTotal(
          session: session,
          serverUrl: serverUrl,
          status: slice.status,
          client: httpClient,
        );
        return total;
      } on _ChartRequestException catch (error) {
        failures += 1;
        if (error.stop) rateLimited = true;
        return 0;
      } catch (_) {
        failures += 1;
        return 0;
      }
    }));
    if (rateLimited) {
      statusError = 'Too many attempts. Wait a moment, then try again.';
    } else if (failures == posReportStatusSlices.length) {
      statusError = 'Could not load orders by status.';
    }
    return PosReportChartData(
      days: const [],
      statuses: [
        for (var i = 0; i < posReportStatusSlices.length; i++)
          PosStatusCount(
            status: posReportStatusSlices[i].status,
            label: posReportStatusSlices[i].label,
            count: counts[i],
            colorValue: posReportStatusSlices[i].color,
          ),
      ],
      statusError: statusError,
    );
  } finally {
    if (ownClient) httpClient.close();
  }
}

String _reportDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

Future<int> _fetchStatusTotal({
  required PosSession session,
  required String serverUrl,
  required String status,
  required http.Client client,
}) async {
  final uri = Uri.parse('$serverUrl/api/v1/pos/admin/orders').replace(
    queryParameters: {
      'status': status,
      'period': 'last_7_days',
      'payment': 'all',
      'page': '1',
    },
  );
  final response = await _reportGet(client, uri, session);
  return ordersTotalFromResponse(jsonDecode(response.body));
}

class _ChartRequestException implements Exception {
  _ChartRequestException(this.message, {required this.stop});

  final String message;
  final bool stop;
}

Map<String, String> _reportHeaders(PosSession session) => {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${session.token}',
      'X-Restaurant-Id': '${session.restaurantId}',
      'X-Branch-Id': '${session.branchId}',
    };

Future<http.Response> _reportGet(
  http.Client client,
  Uri uri,
  PosSession session,
) async {
  final response = await client
      .get(uri, headers: _reportHeaders(session))
      .timeout(const Duration(seconds: 20));
  if (response.statusCode == 429) {
    throw _ChartRequestException(
      'Too many attempts. Wait a moment, then try again.',
      stop: true,
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _ChartRequestException('Could not load this chart.', stop: false);
  }
  return response;
}

Future<Map<String, dynamic>> _fetchThermalDocument({
  required PosSession session,
  required String serverUrl,
  required String type,
  required String date,
  http.Client? client,
}) async {
  final uri = Uri.parse('$serverUrl/api/v1/pos/reports/thermal-print').replace(
    queryParameters: {'type': type, 'date_from': date, 'date_to': date},
  );
  final http.Response response;
  if (client == null) {
    response = await http
        .get(uri, headers: _reportHeaders(session))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Summary unavailable');
    }
  } else {
    response = await _reportGet(client, uri, session);
  }
  final decoded = jsonDecode(response.body);
  final root = decoded is Map
      ? Map<String, dynamic>.from(decoded)
      : <String, dynamic>{};
  final data = root['data'] is Map
      ? Map<String, dynamic>.from(root['data'] as Map)
      : root;
  final document = data['document'] is Map
      ? Map<String, dynamic>.from(data['document'] as Map)
      : data;
  return document;
}
