import 'package:flutter/material.dart';
import '../../services/menu_spreadsheet_export.dart';

class MenuExportSection extends StatefulWidget {
  const MenuExportSection({
    super.key,
    required this.busy,
    this.onExport,
    this.onTemplate,
  });
  final bool busy;
  final void Function(String, MenuExportOptions)? onExport;
  final VoidCallback? onTemplate;
  @override
  State<MenuExportSection> createState() => _MenuExportSectionState();
}

class _MenuExportSectionState extends State<MenuExportSection> {
  final _options = MenuExportOptions();
  static const _green = Color(0xFF009C73);
  static const _border = Color(0xFFE0E8F1);
  Widget _option(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> update,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: value ? const Color(0xFFF1FDF7) : const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: value ? const Color(0xFFB2EED3) : _border),
    ),
    child: CheckboxListTile(
      value: value,
      onChanged: widget.busy ? null : (v) => setState(() => update(v!)),
      activeColor: _green,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 10, color: Color(0xFF71839A)),
      ),
    ),
  );
  Widget _download(String title, String subtitle, String format, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF71839A)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: widget.busy || widget.onExport == null
                  ? null
                  : () => widget.onExport!(format, _options),
              icon: const Icon(Icons.download, size: 16),
              label: Text(title),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(
        Icons.table_chart_outlined,
        size: 20,
        color: Color(0xFF71839A),
      ),
      title: const Text(
        'Advanced: spreadsheet import & export',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Download a template, export your menu, or import CSV / Excel with optional AI column mapping.',
        style: TextStyle(fontSize: 11, color: Color(0xFF71839A)),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: widget.busy ? null : widget.onTemplate,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download spreadsheet template'),
            style: OutlinedButton.styleFrom(foregroundColor: _green),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB2EED3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Export menu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              const Text(
                'Download your current branch menu as CSV or Excel.',
                style: TextStyle(fontSize: 12, color: Color(0xFF71839A)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Uses the same 23 columns as the import template. Barcodes, images, translations, order-type surcharges, and time slots are not included.',
                style: TextStyle(fontSize: 11, color: Color(0xFF71839A)),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final csv = _download(
                    'Download CSV',
                    'Opens in Excel, Google Sheets, or your spreadsheet app.',
                    'csv',
                    _green,
                  );
                  final excel = _download(
                    'Download Excel',
                    'Native Excel workbook with the same import columns.',
                    'xlsx',
                    const Color(0xFFFF6900),
                  );
                  return constraints.maxWidth < 500
                      ? Column(
                          children: [csv, const SizedBox(height: 10), excel],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: csv),
                            const SizedBox(width: 12),
                            Expanded(child: excel),
                          ],
                        );
                },
              ),
              const SizedBox(height: 14),
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Advanced export settings',
                  style: TextStyle(fontSize: 12),
                ),
                subtitle: const Text(
                  'Choose which menu data to include before downloading.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF71839A)),
                ),
                children: [
                  _option(
                    'Include inactive categories',
                    'Export categories marked as inactive.',
                    _options.inactiveCategories,
                    (v) => _options.inactiveCategories = v,
                  ),
                  _option(
                    'Include unavailable items',
                    'Export items that are hidden or marked unavailable.',
                    _options.unavailableItems,
                    (v) => _options.unavailableItems = v,
                  ),
                  _option(
                    'Include variants',
                    'Add variant rows for items with size or style options.',
                    _options.variants,
                    (v) => _options.variants = v,
                  ),
                  _option(
                    'Include modifiers',
                    'Add modifier and option rows, including standalone modifiers.',
                    _options.modifiers,
                    (v) => _options.modifiers = v,
                  ),
                  _option(
                    'Include empty categories',
                    'Export category rows even when they have no items.',
                    _options.emptyCategories,
                    (v) => _options.emptyCategories = v,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
