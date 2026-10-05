import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/menu_spreadsheet_export.dart';

void main() {
  final menu = {
    'categories': [
      {
        'name': 'Breakfast',
        'is_active': true,
        'sort_order': 2,
        'items': [
          {
            'name': 'Idly-1, Vada-1',
            'price': '60.00',
            'item_type': 'veg',
            'is_available': true,
            'variants': [
              {'name': 'Large', 'price': 90, 'is_available': true},
            ],
            'modifiers': [
              {
                'id': 1,
                'name': 'Extras',
                'type': 'multiple',
                'is_required': false,
                'options': [
                  {
                    'name': 'Chutney',
                    'price_adjustment': 5,
                    'is_available': true,
                  },
                ],
              },
            ],
          },
          {'name': 'Hidden', 'price': 40, 'is_available': false},
        ],
      },
      {
        'name': 'Inactive',
        'is_active': false,
        'items': [
          {'name': 'Coffee', 'price': 20},
        ],
      },
      {'name': 'Empty', 'items': []},
    ],
  };
  test('exports all 23 sample columns and variant/modifier rows', () {
    final rows = MenuSpreadsheetExport.rows(menu, MenuExportOptions());
    expect(rows.length, 5);
    final csv = utf8.decode(MenuSpreadsheetExport.csv(rows));
    expect(csv.split('\r\n').first, menuExportColumns.join(','));
    expect(menuExportColumns.length, 23);
    expect(csv, contains('"Idly-1, Vada-1"'));
    expect(rows.any((r) => r['variant_name'] == 'Large'), isTrue);
    expect(rows.any((r) => r['option_name'] == 'Chutney'), isTrue);
  });
  test('applies every export filter', () {
    final options = MenuExportOptions()
      ..inactiveCategories = false
      ..unavailableItems = false
      ..variants = false
      ..modifiers = false
      ..emptyCategories = true;
    final rows = MenuSpreadsheetExport.rows(menu, options);
    expect(rows.length, 2);
    expect(rows.first['item_name'], 'Idly-1, Vada-1');
    expect(rows.last['category_name'], 'Empty');
  });
  test('Excel is a ZIP workbook with numeric prices and matching headers', () {
    final bytes = MenuSpreadsheetExport.excel(
      MenuSpreadsheetExport.rows(menu, MenuExportOptions()),
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    final sheet = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content,
    );
    expect(sheet, contains('<c r="F2"><v>60.0</v></c>'));
    expect(sheet, contains('category_name'));
    expect(sheet, contains('option_is_available'));
    expect(sheet, contains('Idly-1, Vada-1'));
  });
  test('CSV escapes quoted descriptions and formula-like item names', () {
    final csv = utf8.decode(
      MenuSpreadsheetExport.csv([
        {
          'item_name': '=SUM(A1)',
          'item_description': 'A "fresh" dish\nwith sauce',
        },
      ]),
    );
    expect(csv, contains("'=SUM(A1)"));
    expect(csv, contains('"A ""fresh"" dish\nwith sauce"'));
  });
}
