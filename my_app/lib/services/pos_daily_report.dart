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
  if (raw is Map) {
    return parseReportAmount(raw['amount'] ?? raw['display'] ?? raw['value']);
  }
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

class PosReportSlice {
  const PosReportSlice({
    required this.label,
    required this.amount,
    this.count,
    this.tips = 0,
    this.items = 0,
  });

  final String label;
  final double amount;
  final int? count;
  final double tips;
  final double items;
}

class PosViewReportData {
  const PosViewReportData({
    required this.summary,
    required this.channels,
    required this.payments,
    required this.orderTypes,
    required this.items,
    required this.categories,
    required this.taxes,
    required this.staff,
    required this.voids,
    this.error,
  });

  final Map<String, double> summary;
  final List<PosReportSlice> channels;
  final List<PosReportSlice> payments;
  final List<PosReportSlice> orderTypes;
  final List<PosReportSlice> items;
  final List<PosReportSlice> categories;
  final List<PosReportSlice> taxes;
  final List<PosReportSlice> staff;
  final List<Map<String, dynamic>> voids;
  final String? error;
}

/// Same thermal-print types the owner reports use, plus cancelled orders
/// for voids. Reads do not set the global rate-limit flag.
Future<PosViewReportData> loadPosViewReport({
  required PosSession session,
  required String serverUrl,
  required String dateFrom,
  required String dateTo,
  required List<String> types,
  required bool includeVoids,
  bool includeStaff = false,
  String period = 'today',
  void Function(PosViewReportData data)? onPartial,
}) async {
  final client = http.Client();
  try {
    final documents = <String, Map<String, dynamic>>{};
    String? error;
    var next = 0;
    var stop = false;
    Future<void> worker() async {
      while (!stop) {
        final index = next;
        next += 1;
        if (index >= types.length) return;
        try {
          documents[types[index]] = await _fetchThermalRange(
            client: client,
            session: session,
            serverUrl: serverUrl,
            type: types[index],
            dateFrom: dateFrom,
            dateTo: dateTo,
          );
        } on _ChartRequestException catch (e) {
          error ??= e.message;
          if (e.stop) stop = true;
        } catch (_) {
          error ??= 'Could not load this report.';
        }
      }
    }

    final workers = types.isEmpty ? 0 : (types.length < 3 ? types.length : 3);
    if (workers > 0) {
      await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    }
    PosViewReportData pack({
      List<PosReportSlice> staff = const [],
      List<Map<String, dynamic>> voids = const [],
    }) {
      return PosViewReportData(
        summary: _summaryFromDocument(documents['summary']),
        channels: _mixFromDocument(documents['channel']),
        payments: _mixFromDocument(documents['consolidated']),
        orderTypes: _mixFromDocument(documents['order_type']),
        items: _mixFromDocument(documents['item']),
        categories: _mixFromDocument(documents['category']),
        taxes: _mixFromDocument(documents['tax']),
        staff: staff,
        voids: voids,
        error: documents.isEmpty && voids.isEmpty && staff.isEmpty ? error : null,
      );
    }

    if (!includeStaff && !includeVoids) return pack();
    if (types.isNotEmpty) onPartial?.call(pack());
    final voids = includeVoids
        ? await _fetchVoidOrders(
            client: client,
            session: session,
            serverUrl: serverUrl,
            period: period,
            dateFrom: dateFrom,
            dateTo: dateTo,
          )
        : const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> staffOrders = const [];
    if (includeStaff) {
      try {
        staffOrders = await _fetchSaleOrders(
          client: client,
          session: session,
          serverUrl: serverUrl,
          period: period,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
        staffOrders = await _withStaffNames(
          client: client,
          session: session,
          serverUrl: serverUrl,
          orders: staffOrders,
          onBatch: (soFar) => onPartial?.call(pack(staff: _staffSlices(soFar), voids: voids)),
        );
      } on _ChartRequestException catch (e) {
        error ??= e.message;
      } catch (_) {
        error ??= 'Could not load this report.';
      }
    }
    final staff = _staffSlices(staffOrders);
    return pack(staff: staff, voids: voids);
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>> _fetchThermalRange({
  required http.Client client,
  required PosSession session,
  required String serverUrl,
  required String type,
  required String dateFrom,
  required String dateTo,
}) async {
  final uri = Uri.parse('$serverUrl/api/v1/pos/reports/thermal-print').replace(
    queryParameters: {
      'type': type,
      'date_from': dateFrom,
      'date_to': dateTo,
    },
  );
  final response = await _reportGet(client, uri, session);
  final decoded = jsonDecode(response.body);
  final root = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  final data = root['data'] is Map
      ? Map<String, dynamic>.from(root['data'] as Map)
      : root;
  final document = data['document'] is Map
      ? Map<String, dynamic>.from(data['document'] as Map)
      : data;
  return document;
}

Map<String, double> _summaryFromDocument(Map<String, dynamic>? document) {
  if (document == null) return const {};
  final summary = <String, double>{};
  for (final row in _docRows(document)) {
    final key = _summaryKey('${row['label']}');
    if (key != null) {
      summary[key] = parseReportAmount(row['amount'] ?? row['display'] ?? row['value'] ?? row['right']);
    }
  }
  for (final row in _docRows(document, key: 'totals')) {
    final label = '${row['label']}'.toUpperCase();
    if (label.contains('TOTAL') && !label.contains('ORDER')) {
      summary['total_revenue'] = parseReportAmount(row['amount'] ?? row['display']);
    }
  }
  return summary;
}

String? _summaryKey(String label) {
  final text = label.trim().toUpperCase();
  switch (text) {
    case 'TOTAL ORDERS':
      return 'total_orders';
    case 'ITEMS SOLD':
      return 'items_sold';
    case 'AVG ORDER':
      return 'average_order';
    case 'TAX':
      return 'total_tax';
    case 'DISCOUNTS':
      return 'total_discounts';
    case 'TIPS':
      return 'total_tips';
    case 'SERVICE CHARGE':
      return 'total_service_charge';
    case 'EXTRA CHARGES':
      return 'total_extra_charges';
    default:
      break;
  }
  if (text.contains('ORDER') && !text.contains('AVG')) return 'total_orders';
  if (text.contains('ITEM') && text.contains('SOLD')) return 'items_sold';
  if (text.contains('AVG')) return 'average_order';
  if (text.contains('DISCOUNT')) return 'total_discounts';
  if (text.contains('SERVICE')) return 'total_service_charge';
  if (text.contains('EXTRA')) return 'total_extra_charges';
  if (text.contains('TIP')) return 'total_tips';
  if (text == 'TAX' || text.contains('TOTAL TAX')) return 'total_tax';
  return null;
}

List<PosReportSlice> _mixFromDocument(Map<String, dynamic>? document) {
  if (document == null) return const [];
  return [
    for (final row in _docRows(document))
      PosReportSlice(
        label: '${row['label'] ?? row['description'] ?? row['name'] ?? ''}'.trim(),
        amount: parseReportAmount(row['amount'] ?? row['display'] ?? row['value']),
        count: _ordersInDisplay(row['display']),
      ),
  ].where((row) => row.label.isNotEmpty).toList();
}

int? _ordersInDisplay(Object? display) {
  final text = '${display ?? ''}';
  final slash = text.indexOf('/');
  if (slash <= 0) return null;
  return int.tryParse(text.substring(0, slash).trim());
}

List<Map<String, dynamic>> _docRows(
  Map<String, dynamic> document, {
  String key = 'rows',
}) {
  final rows = document[key];
  if (rows is List && rows.isNotEmpty) {
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }
  if (key != 'rows') return const [];
  final commands = document['commands'];
  if (commands is! List) return const [];
  final lines = <Map<String, dynamic>>[];
  for (final command in commands) {
    if (command is! Map) continue;
    final type = '${command['type'] ?? ''}';
    if (type != 'text' && type != 'row' && type != 'columns') continue;
    final left = '${command['left'] ?? command['text'] ?? command['value'] ?? ''}'.trim();
    final right = '${command['right'] ?? ''}'.trim();
    if (left.isEmpty || right.isEmpty) continue;
    lines.add({'label': left, 'amount': right, 'display': right});
  }
  return lines;
}

Future<List<Map<String, dynamic>>> _fetchVoidOrders({
  required http.Client client,
  required PosSession session,
  required String serverUrl,
  required String period,
  required String dateFrom,
  required String dateTo,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (final status in const ['cancelled', 'abandoned']) {
    for (var page = 1; page <= 4; page++) {
      final uri = Uri.parse('$serverUrl/api/v1/pos/admin/orders').replace(
        queryParameters: {
          'status': status,
          'period': period,
          'payment': 'all',
          'page': '$page',
          'per_page': '20',
        },
      );
      try {
        final response = await _reportGet(client, uri, session);
        final batch = _orderRows(jsonDecode(response.body));
        if (batch.isEmpty) break;
        rows.addAll(_ordersInRange(batch, dateFrom, dateTo));
      } on _ChartRequestException {
        return rows;
      } catch (_) {
        break;
      }
    }
  }
  return rows;
}

bool _createdInRange(Map<String, dynamic> order, String dateFrom, String dateTo) {
  final created = DateTime.tryParse('${order['created_at']}')?.toLocal();
  if (created == null) return true;
  final day = DateTime(created.year, created.month, created.day);
  final start = DateTime.parse(dateFrom);
  final end = DateTime.parse(dateTo);
  return !day.isBefore(start) && !day.isAfter(end);
}

List<Map<String, dynamic>> _ordersInRange(
  List<Map<String, dynamic>> orders,
  String dateFrom,
  String dateTo,
) {
  return [
    for (final order in orders)
      if (_createdInRange(order, dateFrom, dateTo)) order,
  ];
}

Future<List<Map<String, dynamic>>> _fetchSaleOrders({
  required http.Client client,
  required PosSession session,
  required String serverUrl,
  required String period,
  required String dateFrom,
  required String dateTo,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var page = 1; page <= 4; page++) {
    final uri = Uri.parse('$serverUrl/api/v1/pos/admin/orders').replace(
      queryParameters: {
        'period': period,
        'payment': 'all',
        'page': '$page',
        'per_page': '20',
      },
    );
    try {
      final response = await _reportGet(client, uri, session);
      final batch = _orderRows(jsonDecode(response.body));
      if (batch.isEmpty) break;
      rows.addAll(_ordersInRange(batch, dateFrom, dateTo));
    } on _ChartRequestException {
      if (rows.isEmpty) rethrow;
      break;
    } catch (_) {
      break;
    }
  }
  return rows;
}

/// Staff names live on each order's status log, the same read the owner app uses.
Future<List<Map<String, dynamic>>> _withStaffNames({
  required http.Client client,
  required PosSession session,
  required String serverUrl,
  required List<Map<String, dynamic>> orders,
  void Function(List<Map<String, dynamic>> soFar)? onBatch,
}) async {
  const skipped = {'cancelled', 'abandoned', 'failed', 'draft', 'void', 'voided'};
  final sales = [
    for (final order in orders)
      if (!skipped.contains('${order['status']}'.toLowerCase())) order,
  ];
  final detailed = <Map<String, dynamic>>[];
  var stop = false;
  for (var i = 0; i < sales.length && !stop; i += 8) {
    final slice = sales.skip(i).take(8);
    final loaded = await Future.wait(
      slice.map(
        (order) => _decorateOrder(
          client: client,
          session: session,
          serverUrl: serverUrl,
          order: order,
        ),
      ),
    );
    for (final order in loaded) {
      if (order.remove('_stop') == true) stop = true;
      detailed.add(order);
    }
    onBatch?.call(List<Map<String, dynamic>>.from(detailed));
  }
  return detailed;
}

Future<Map<String, dynamic>> _decorateOrder({
  required http.Client client,
  required PosSession session,
  required String serverUrl,
  required Map<String, dynamic> order,
}) async {
  final copy = Map<String, dynamic>.from(order);
  final id = order['id'];
  if (id == null) {
    copy['staff_name'] = 'Unassigned / online';
    return copy;
  }
  try {
    final uri = Uri.parse('$serverUrl/api/v1/pos/admin/orders/$id');
    final response = await _reportGet(client, uri, session);
    final decoded = jsonDecode(response.body);
    final root = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    final data = root['data'];
    final full = data is Map ? Map<String, dynamic>.from(data) : root;
    copy.addAll(full);
    copy['staff_name'] = _staffName(full);
    final items = full['items'];
    copy['items_count'] = items is List
        ? items.fold<double>(0, (sum, item) {
            if (item is! Map) return sum;
            return sum + _money(item['quantity'] ?? 1);
          })
        : 0;
  } on _ChartRequestException catch (error) {
    copy['staff_name'] = 'Unassigned / online';
    copy['items_count'] = 0;
    if (error.stop) copy['_stop'] = true;
  } catch (_) {
    copy['staff_name'] = 'Unassigned / online';
    copy['items_count'] = 0;
  }
  return copy;
}

String _staffName(Map<String, dynamic> order) {
  final logs = order['status_logs'];
  if (logs is List) {
    for (final log in logs) {
      if (log is! Map) continue;
      final user = log['user'];
      if (user is Map) {
        final name = '${user['name'] ?? ''}'.trim();
        if (name.isNotEmpty) return name;
      }
    }
  }
  return 'Unassigned / online';
}

double _money(Object? raw) {
  if (raw is Map) {
    return _money(raw['amount'] ?? raw['display'] ?? raw['value']);
  }
  return parseReportAmount(raw);
}

List<PosReportSlice> _staffSlices(List<Map<String, dynamic>> orders) {
  final groups = <String, ({int orders, double revenue, double tips, double items})>{};
  for (final order in orders) {
    final name = '${order['staff_name'] ?? 'Unassigned / online'}'.trim();
    final label = name.isEmpty ? 'Unassigned / online' : name;
    final current = groups[label];
    groups[label] = (
      orders: (current?.orders ?? 0) + 1,
      revenue: (current?.revenue ?? 0) + _money(order['total']),
      tips: (current?.tips ?? 0) + _money(order['tip_total'] ?? order['tip']),
      items: (current?.items ?? 0) + _money(order['items_count']),
    );
  }
  final rows = [
    for (final entry in groups.entries)
      PosReportSlice(
        label: entry.key,
        amount: entry.value.revenue,
        count: entry.value.orders,
        tips: entry.value.tips,
        items: entry.value.items,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  return rows;
}

List<Map<String, dynamic>> _orderRows(Object? decoded) {
  if (decoded is! Map) return const [];
  final root = Map<String, dynamic>.from(decoded);
  final data = root['data'];
  final page = data is Map ? Map<String, dynamic>.from(data) : root;
  final raw = page['data'] ?? page['orders'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
}
