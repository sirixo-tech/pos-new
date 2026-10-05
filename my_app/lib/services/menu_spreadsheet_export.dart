import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

const menuExportColumns = [
  'category_name',
  'category_sort_order',
  'category_is_active',
  'item_name',
  'item_description',
  'price',
  'item_type',
  'preparation_time',
  'item_sort_order',
  'is_available',
  'variant_name',
  'variant_price',
  'variant_sort_order',
  'variant_is_available',
  'modifier_name',
  'modifier_type',
  'modifier_is_required',
  'modifier_min_selections',
  'modifier_max_selections',
  'modifier_sort_order',
  'option_name',
  'option_price_adjustment',
  'option_is_available',
];

class MenuExportOptions {
  bool inactiveCategories = true;
  bool unavailableItems = true;
  bool variants = true;
  bool modifiers = true;
  bool emptyCategories = false;
}

class MenuSpreadsheetExport {
  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
      : [];
  static bool _enabled(dynamic value) =>
      ![false, 0, '0', 'false', 'no'].contains(value);

  static List<Map<String, dynamic>> rows(
    Map<String, dynamic> menu,
    MenuExportOptions options,
  ) {
    if (menu['categories'] is! List) {
      throw const FormatException(
        'Menu response does not contain exportable categories.',
      );
    }
    final output = <Map<String, dynamic>>[];
    final modifiers = _maps(menu['modifiers']);
    final attached = <String>{};
    // A modifier attached to a filtered-out item is not a standalone modifier.
    for (final category in _maps(menu['categories'])) {
      for (final item in _maps(category['items'])) {
        attached.addAll(_maps(item['modifiers']).map((m) => '${m['id']}'));
        if (item['modifier_ids'] is List) {
          attached.addAll((item['modifier_ids'] as List).map((id) => '$id'));
        }
      }
    }
    Map<String, dynamic> modifierFields(Map<String, dynamic> m) => {
      'modifier_name': m['name'],
      'modifier_type': m['type'] ?? m['modifier_type'],
      'modifier_is_required': m['is_required'],
      'modifier_min_selections': m['min_selections'],
      'modifier_max_selections': m['max_selections'],
      'modifier_sort_order': m['sort_order'],
    };
    void addModifier(Map<String, dynamic> base, Map<String, dynamic> modifier) {
      attached.add('${modifier['id']}');
      final fields = {...base, ...modifierFields(modifier)};
      final choices = _maps(modifier['options']);
      if (choices.isEmpty) output.add(fields);
      for (final choice in choices) {
        output.add({
          ...fields,
          'option_name': choice['name'],
          'option_price_adjustment': choice['price_adjustment'],
          'option_is_available': choice['is_available'] ?? true,
        });
      }
    }

    for (final category in _maps(menu['categories'])) {
      if (!options.inactiveCategories && !_enabled(category['is_active'])) {
        continue;
      }
      final categoryFields = <String, dynamic>{
        'category_name': category['name'],
        'category_sort_order': category['sort_order'] ?? 0,
        'category_is_active': category['is_active'] ?? true,
      };
      final items = _maps(category['items'])
          .where(
            (item) =>
                options.unavailableItems || _enabled(item['is_available']),
          )
          .toList();
      if (items.isEmpty && options.emptyCategories) output.add(categoryFields);
      for (final item in items) {
        final base = {
          ...categoryFields,
          'item_name': item['name'],
          'item_description': item['description'],
          'price': item['price'],
          'item_type': item['item_type'],
          'preparation_time': item['preparation_time'],
          'item_sort_order': item['sort_order'] ?? 0,
          'is_available': item['is_available'] ?? true,
        };
        output.add(base);
        if (options.variants) {
          for (final variant in _maps(item['variants'])) {
            if (!options.unavailableItems && !_enabled(variant['is_available'])) {
              continue;
            }
            output.add({
              ...base,
              'variant_name': variant['name'],
              'variant_price': variant['price'],
              'variant_sort_order': variant['sort_order'] ?? 0,
              'variant_is_available': variant['is_available'] ?? true,
            });
          }
        }
        if (options.modifiers) {
          final linked = _maps(item['modifiers']);
          final ids = item['modifier_ids'] is List
              ? (item['modifier_ids'] as List).map((v) => '$v').toSet()
              : <String>{};
          if (linked.isEmpty) {
            linked.addAll(modifiers.where((m) => ids.contains('${m['id']}')));
          }
          for (final modifier in linked) {
            addModifier(base, modifier);
          }
        }
      }
    }
    if (options.modifiers) {
      for (final modifier in modifiers.where(
        (m) => !attached.contains('${m['id']}'),
      )) {
        addModifier({}, modifier);
      }
    }
    return output;
  }

  static List<List<dynamic>> _table(List<Map<String, dynamic>> rows) => [
    menuExportColumns,
    ...rows.map((r) => menuExportColumns.map((key) => r[key] ?? '').toList()),
  ];
  static Uint8List csv(List<Map<String, dynamic>> rows) {
    String cell(dynamic value) {
      var text = '$value';
      // Keep formula-like menu names as text when opened in spreadsheet apps.
      if (value is String &&
          RegExp(r'^\s*[=+@-]').hasMatch(text) &&
          num.tryParse(text) == null) {
        text = "'$text";
      }
      return RegExp('[",\r\n]').hasMatch(text)
          ? '"${text.replaceAll('"', '""')}"'
          : text;
    }

    return Uint8List.fromList(
      utf8.encode(
        '${_table(rows).map((r) => r.map(cell).join(',')).join('\r\n')}\r\n',
      ),
    );
  }

  static Uint8List excel(List<Map<String, dynamic>> rows) {
    String xml(String text) => text
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    final data = _table(rows);
    final sheet = StringBuffer(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
    );
    const numericColumns = {
      'category_sort_order',
      'price',
      'preparation_time',
      'item_sort_order',
      'variant_price',
      'variant_sort_order',
      'modifier_min_selections',
      'modifier_max_selections',
      'modifier_sort_order',
      'option_price_adjustment',
    };
    for (var r = 0; r < data.length; r++) {
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < data[r].length; c++) {
        final value = data[r][c];
        final ref = '${String.fromCharCode(65 + c)}${r + 1}';
        final number = r > 0 && numericColumns.contains(menuExportColumns[c])
            ? num.tryParse('$value')
            : null;
        if (number != null && number.isFinite) {
          sheet.write('<c r="$ref"><v>$number</v></c>');
        } else {
          sheet.write(
            '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${xml('$value')}</t></is></c>',
          );
        }
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData></worksheet>');
    final files = {
      '[Content_Types].xml':
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels':
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/workbook.xml':
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Worksheet" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      'xl/worksheets/sheet1.xml': sheet.toString(),
    };
    final archive = Archive();
    files.forEach((name, text) {
      final bytes = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>$text',
      );
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}
