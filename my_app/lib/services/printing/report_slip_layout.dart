/// Report slips only. Long item names stay in the description column and
/// continue on the next line, instead of a clipped character printing as "?".
List<dynamic> wrapLongReportItemNames(
  Map<String, dynamic> data,
  List<dynamic> commands, {
  int? lineWidth,
}) {
  final namesByCode = _reportNamesByCode(data);
  final namesInOrder = _reportNamesInOrder(data);
  var itemIndex = 0;
  final expanded = <dynamic>[];

  for (final command in commands) {
    if (command is! Map) {
      expanded.add(command);
      continue;
    }
    final type = command['type']?.toString().toLowerCase() ?? '';
    if (type != 'text') {
      expanded.add(command);
      continue;
    }
    final text = command['text']?.toString() ?? '';
    if (lineWidth != null &&
        lineWidth <= 32 &&
        RegExp(
          r'Code\s+Description\s+Qty\s+Amount',
          caseSensitive: false,
        ).hasMatch(text)) {
      expanded.add({
        ...Map<String, dynamic>.from(command),
        'text':
            '${'Code'.padRight(5)}${'Description'.padRight(lineWidth - 17)}${'Qty'.padLeft(3)}${'Amount'.padLeft(9)}',
      });
      continue;
    }
    final parsed = _parseItemLine(text);
    if (parsed == null) {
      expanded.add(command);
      continue;
    }

    final fromCode = namesByCode[parsed.code];
    final fromOrder = itemIndex < namesInOrder.length
        ? namesInOrder[itemIndex]
        : null;
    itemIndex++;
    final full = _fullItemName(
      parsed.name,
      fromCode ?? _orderName(parsed.name, fromOrder),
    );
    if (lineWidth != null && lineWidth <= 32) {
      final width = lineWidth;
      final values = parsed.tail.trim().split(RegExp(r'\s+'));
      final qty = values.first;
      final amount = values.last;
      final codeWidth = parsed.code.length >= 5 ? parsed.code.length + 1 : 5;
      final qtyWidth = qty.length >= 3 ? qty.length + 1 : 3;
      final amountWidth = amount.length >= 9 ? amount.length + 1 : 9;
      final nameWidth = width - codeWidth - qtyWidth - amountWidth;
      final nameLines = _wrapWords(full, nameWidth > 0 ? nameWidth : 1);
      final lines = nameWidth > 0
          ? [
              '${parsed.code.padRight(codeWidth)}${nameLines.first.padRight(nameWidth)}${qty.padLeft(qtyWidth)}${amount.padLeft(amountWidth)}',
              for (final extra in nameLines.skip(1)) '${' ' * codeWidth}$extra',
            ]
          : [
              ..._wrapWords('${parsed.code} $full', width),
              ..._wrapWords('Qty: $qty Amount: $amount', width),
            ];
      for (final line in lines) {
        expanded.add({
          ...Map<String, dynamic>.from(command),
          'text': line,
          'align': 'left',
          'style': 'normal',
        });
      }
      continue;
    }
    if (full == parsed.name && full.length <= parsed.nameWidth) {
      expanded.add(command);
      continue;
    }

    for (final line in _layoutItemLines(parsed, full)) {
      expanded.add({
        ...Map<String, dynamic>.from(command),
        'type': 'text',
        'text': line,
        'align': 'left',
      });
    }
  }
  return expanded;
}

class _ItemLine {
  const _ItemLine({
    required this.raw,
    required this.code,
    required this.name,
    required this.nameAt,
    required this.nameWidth,
    required this.tail,
  });

  final String raw;
  final String code;
  final String name;
  final int nameAt;
  final int nameWidth;
  final String tail;
}

_ItemLine? _parseItemLine(String text) {
  if (text.trim().isEmpty) return null;
  final parts = text.trimRight().split(RegExp(r'\s+'));
  if (parts.length < 4) return null;
  final code = parts.first;
  final amount = parts.last;
  final qty = parts[parts.length - 2];
  if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(code)) return null;
  if (!RegExp(r'^\d+$').hasMatch(qty)) return null;
  if (!RegExp(r'^[\d,]+\.\d{2}$').hasMatch(amount)) return null;

  final amountAt = text.lastIndexOf(amount);
  if (amountAt < 0) return null;
  // Locate the complete trailing quantity/amount pair. Searching for the
  // quantity alone can match digits inside the amount (e.g. 2 in 200.00).
  final tailMatch = RegExp(r'(\d+)\s+([\d,]+\.\d{2})\s*$').firstMatch(text);
  if (tailMatch == null) return null;
  final qtyAt = tailMatch.start;
  final name = parts.sublist(1, parts.length - 2).join(' ');
  final nameAt = text.indexOf(name);
  if (nameAt < 0 || nameAt >= qtyAt) return null;
  final nameWidth = qtyAt - nameAt;
  if (nameWidth < 4) return null;
  return _ItemLine(
    raw: text,
    code: code,
    name: name,
    nameAt: nameAt,
    nameWidth: nameWidth,
    tail: text.substring(qtyAt),
  );
}

String? _orderName(String printed, String? candidate) {
  if (candidate == null || candidate.isEmpty) return null;
  final cut = printed.replaceAll(RegExp(r'(?:\.{3}|…|\?)+$'), '').trimRight();
  if (cut.isEmpty || candidate.startsWith(cut)) return candidate;
  return null;
}

String _fullItemName(String printed, String? source) {
  final cut = printed.replaceAll(RegExp(r'(?:\.{3}|…|\?)+$'), '').trimRight();
  final full = source?.trim() ?? '';
  if (full.isEmpty) return printed;
  if (full == printed) return printed;
  final clipped =
      printed.endsWith('?') || printed.endsWith('…') || printed.endsWith('...');
  if (clipped && (full.startsWith(cut) || cut.isEmpty)) return full;
  if (cut.isNotEmpty && full.startsWith(cut) && full.length > printed.length) {
    return full;
  }
  return printed;
}

List<String> _layoutItemLines(_ItemLine line, String name) {
  if (name.length <= line.nameWidth) {
    final gap = line.nameWidth - name.length;
    return [
      '${line.raw.substring(0, line.nameAt)}$name${' ' * gap}${line.tail}',
    ];
  }
  final chunks = _wrapWords(name, line.nameWidth);
  final lines = <String>[
    '${line.raw.substring(0, line.nameAt)}${chunks.first.padRight(line.nameWidth)}${line.tail}',
  ];
  for (final extra in chunks.skip(1)) {
    lines.add('${' ' * line.nameAt}$extra');
  }
  return lines;
}

List<String> _wrapWords(String value, int width) {
  final lines = <String>[];
  var remaining = value.trim();
  while (remaining.isNotEmpty) {
    if (remaining.length <= width) {
      lines.add(remaining);
      break;
    }
    final window = remaining.substring(0, width);
    final space = window.lastIndexOf(' ');
    final minBreak = (width / 3).floor();
    final take = space >= minBreak ? space : width;
    lines.add(remaining.substring(0, take).trimRight());
    remaining = remaining.substring(take).trimLeft();
  }
  return lines;
}

Map<String, dynamic> _reportDocument(Map<String, dynamic> data) {
  final document = data['document'];
  if (document is Map) return Map<String, dynamic>.from(document);
  return data;
}

Map<String, String> _reportNamesByCode(Map<String, dynamic> data) {
  final names = <String, String>{};
  for (final row in _reportItemRows(data)) {
    final code = _text(row['code'] ?? row['item_code'] ?? row['sku']);
    final name = _rowName(row);
    if (code.isNotEmpty && name.isNotEmpty) names[code] = name;
  }
  return names;
}

List<String> _reportNamesInOrder(Map<String, dynamic> data) {
  return [
    for (final row in _reportItemRows(data))
      if (_rowName(row).isNotEmpty) _rowName(row),
  ];
}

List<Map<String, dynamic>> _reportItemRows(Map<String, dynamic> data) {
  final document = _reportDocument(data);
  for (final key in const ['rows', 'lines', 'items']) {
    final raw = document[key];
    if (raw is! List) continue;
    final rows = raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => _rowName(row).isNotEmpty)
        .where(
          (row) =>
              _text(row['qty'] ?? row['quantity']).isNotEmpty ||
              _text(row['code'] ?? row['item_code']).isNotEmpty ||
              _text(row['amount'] ?? row['total']).isNotEmpty,
        )
        .toList();
    if (rows.isNotEmpty) return rows;
  }
  return const [];
}

String _rowName(Map<String, dynamic> row) {
  return _text(
    row['description'] ?? row['name'] ?? row['item_name'] ?? row['label'],
  );
}

String _text(Object? value) => value?.toString().trim() ?? '';
