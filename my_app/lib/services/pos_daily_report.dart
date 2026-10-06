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
  final uri = Uri.parse('$serverUrl/api/v1/pos/reports/thermal-print').replace(
    queryParameters: {'type': 'summary', 'date_from': date, 'date_to': date},
  );
  final response = await http
      .get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${session.token}',
          'X-Restaurant-Id': '${session.restaurantId}',
          'X-Branch-Id': '${session.branchId}',
        },
      )
      .timeout(const Duration(seconds: 20));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Summary unavailable');
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
