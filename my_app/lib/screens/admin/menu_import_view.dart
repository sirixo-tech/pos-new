import 'dart:math' as math;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

import '../../utils/pos_layout.dart';
import '../../services/menu_spreadsheet_export.dart';
import 'menu_export_section.dart';
import 'menu_import_progress.dart';

const _green = Color(0xFF009C73);

class _AiStepRail extends StatefulWidget {
  const _AiStepRail({required this.titles, required this.stage});

  final List<String> titles;
  final int stage;

  @override
  State<_AiStepRail> createState() => _AiStepRailState();
}

class _AiStepRailState extends State<_AiStepRail> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final t = _motion.value;
        return SizedBox(
          height: 48,
          child: Stack(
            children: [
              Positioned(
                left: 36,
                right: 36,
                top: 10,
                child: _AiTrace(t: t),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.titles.length; i++)
                    Expanded(child: _step(i, t)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _step(int i, double t) {
    final active = i == widget.stage;
    final done = i < widget.stage;
    final pulse = active ? 0.5 + 0.5 * math.sin(t * math.pi * 2) : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Container(
                  width: 22 + pulse * 6,
                  height: 22 + pulse * 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _green.withValues(alpha: 0.16 * (1 - pulse * 0.35)),
                  ),
                ),
              CircleAvatar(
                radius: 11,
                backgroundColor: i <= widget.stage ? _green : _border,
                child: done
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : _muted,
                        ),
                      ),
              ),
            ],
          ),
        ),
        Text(
          widget.titles[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? _ink : _muted,
          ),
        ),
      ],
    );
  }
}

class _AiTrace extends StatelessWidget {
  const _AiTrace({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final head = (t * 1.35 - 0.15).clamp(0.0, 1.0);
    var lead = (head - 0.16).clamp(0.0, 1.0);
    var mid = head;
    var tail = (head + 0.1).clamp(0.0, 1.0);
    if (mid < lead) mid = lead;
    if (tail < mid) tail = mid;
    return Container(
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: const [
            _border,
            Color(0xFFB7E6D6),
            _green,
            Color(0xFFB7E6D6),
            _border,
          ],
          stops: [0, lead, mid, tail, 1],
        ),
      ),
    );
  }
}
const _ink = Color(0xFF12253E);
const _muted = Color(0xFF71839A);
const _border = Color(0xFFE0E8F1);

class MenuImportView extends StatefulWidget {
  const MenuImportView({
    super.key,
    required this.capabilities,
    required this.import,
    required this.rows,
    required this.review,
    required this.terminal,
    required this.busy,
    required this.ai,
    required this.error,
    required this.errors,
    required this.selectedFile,
    required this.selectedBytes,
    required this.onPick,
    required this.onUpload,
    required this.onClear,
    required this.onAiChanged,
    required this.onRetry,
    required this.onSave,
    required this.onConfirm,
    required this.onCancel,
    required this.onEdit,
    required this.onImage,
    required this.onRowChanged,
    required this.onDelete,
    required this.onErrors,
    this.onExport,
    this.onTemplate,
    this.onViewMenu,
    this.onOpenPos,
    this.onAnother,
    this.onCamera,
    this.voiceSection,
    this.alternateBody,
    this.onChangeSource,
    this.stepTitles = const ['Upload', 'AI extract', 'Edit & review', 'Go live'],
    this.stepSubtitles = const [
      'Photo, PDF, or spreadsheet',
      'Build your menu catalog',
      'Quick fixes by category',
      'Publish to this branch',
    ],
  });
  final Map<String, dynamic>? capabilities, import;
  final List<Map<String, dynamic>> rows;
  final bool review, terminal, busy, ai;
  final String? error, errors;
  final XFile? selectedFile;
  final int selectedBytes;
  final VoidCallback onPick,
      onUpload,
      onClear,
      onRetry,
      onSave,
      onConfirm,
      onCancel,
      onErrors;
  final ValueChanged<bool> onAiChanged;
  final ValueChanged<int> onEdit, onImage, onDelete;
  final void Function(int, String, String) onRowChanged;
  final void Function(String, MenuExportOptions)? onExport;
  final VoidCallback? onTemplate;
  final VoidCallback? onViewMenu, onOpenPos, onAnother;
  final VoidCallback? onCamera;
  final Widget? voiceSection;
  final Widget? alternateBody;
  final VoidCallback? onChangeSource;
  final List<String> stepTitles;
  final List<String> stepSubtitles;

  @override
  State<MenuImportView> createState() => _MenuImportViewState();
}

class _MenuImportViewState extends State<MenuImportView> {
  String? _category;
  String _search = '';
  bool _removed(Map row) => row['_delete'] == true || row['deleted'] == true;
  List<Map<String, dynamic>> get _active =>
      widget.rows.where((r) => !_removed(r)).toList();
  List<String> get _categories =>
      _active.map((r) => '${r['category_name'] ?? ''}').toSet().toList();
  Widget _panel(Widget child, {bool tint = false}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(16),
      gradient: tint
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFFDF6), Colors.white, Color(0xFFF8FAFD)],
            )
          : null,
    ),
    padding: EdgeInsets.all(usePosHandheldLayout(context) ? 14 : 22),
    child: child,
  );
  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F8FC),
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11, color: _muted)),
  );
  Widget _heading(IconData icon, String title, String subtitle) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFDEF9EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _green, size: 23),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _steps() {
    final status = '${widget.import?['status'] ?? ''}';
    final stage = widget.review
        ? 2
        : widget.terminal && ['completed', 'complete'].contains(status)
        ? 3
        : widget.import != null && !widget.terminal
        ? 1
        : 0;
    return _AiStepRail(titles: widget.stepTitles, stage: stage);
  }

  Widget _uploadPanel() {
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final caps = widget.capabilities;
    final spreadsheet = [
      'csv',
      'xlsx',
    ].contains(widget.selectedFile?.name.split('.').last.toLowerCase());
    final credits = caps?['ai_credits'];
    final unlimited = credits is Map && credits['unlimited'] == true;
    final costs = caps?['ai_credit_costs'];
    final compact = usePosHandheldLayout(context);
    final fileName = widget.selectedFile?.name;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF1D4ED8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Photo, PDF, or spreadsheet',
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.2,
                    letterSpacing: -0.2,
                    color: _ink,
                  ),
                ),
              ),
              if (widget.onChangeSource != null)
                _ChangePill(onPressed: widget.busy ? null : widget.onChangeSource),
            ],
          ),
          SizedBox(height: compact ? 10 : 16),
          if (widget.voiceSection != null) ...[
            widget.voiceSection!,
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: _border, height: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'or',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: _border, height: 1)),
                ],
              ),
            ),
          ],
          InkWell(
            onTap: widget.busy || caps == null ? null : widget.onPick,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: BoxConstraints(minHeight: compact ? 92 : 168),
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: compact ? 12 : 22),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: fileName == null ? _border : _green,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: fileName == null
                          ? Colors.white
                          : const Color(0xFFDCF9EB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Icon(
                      fileName == null
                          ? Icons.upload_file_outlined
                          : Icons.check_rounded,
                      color: _green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fileName ?? 'Choose a file',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName == null
                        ? 'Photo, PDF, CSV, or Excel'
                        : '${(widget.selectedBytes / 1024).toStringAsFixed(1)} KB · Tap to replace',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: _muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['Photo', 'PDF', 'CSV', 'Excel'].map(_badge).toList(),
          ),
          SizedBox(height: compact ? 8 : 12),
          const _UploadGuide(),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              unlimited
                  ? 'Unlimited AI credits on your plan.'
                  : 'AI credits remaining: ${caps?['ai_credits_remaining'] ?? '—'}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
            if (costs is Map)
              Text(
                'Spreadsheet reading: ${costs['text']} credits · Photo or PDF: ${costs['vision_page']} credits per page',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
          ],
          const SizedBox(height: 14),
          if (mobile && widget.onCamera != null) ...[
            OutlinedButton.icon(
              onPressed: widget.busy || caps?['image_import_available'] != true
                  ? null
                  : widget.onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take photo of menu'),
            ),
            const SizedBox(height: 10),
          ],
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: _green,
            value: widget.ai,
            onChanged: widget.busy || caps?['ai_assist_available'] != true
                ? null
                : (v) => widget.onAiChanged(v!),
            title: Text(
              spreadsheet ? 'Match my column names' : 'Read items and prices',
              style: const TextStyle(fontSize: 13, color: _ink),
            ),
            subtitle: Text(
              caps?['ai_assist_available'] == true
                  ? 'You confirm every price before it is saved.'
                  : 'Reading is unavailable: ${caps?['ai_unavailable_reason'] ?? 'Checking availability'}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.busy || widget.selectedFile == null
                      ? null
                      : widget.onUpload,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                    widget.ai ? 'Read this menu' : 'Import spreadsheet',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 19),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (widget.selectedFile != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: widget.busy ? null : widget.onClear,
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stats() => LayoutBuilder(
    builder: (context, constraints) {
      final stats = [
        ('${_categories.length}', 'CATEGORIES', Icons.folder_outlined),
        ('${_active.length}', 'ITEMS', Icons.restaurant_outlined),
        (
          '${_active.where((r) => '${r['variant_name'] ?? ''}'.isNotEmpty).length}',
          'VARIANTS',
          Icons.layers_outlined,
        ),
        (
          '${_active.map((r) => '${r['modifier_name'] ?? ''}').where((s) => s.isNotEmpty).toSet().length}',
          'MODIFIERS',
          Icons.tune,
        ),
      ];
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stats
            .map(
              (s) => SizedBox(
                width:
                    (constraints.maxWidth - 24) /
                    (constraints.maxWidth < 500 ? 2 : 4),
                child: _panel(
                  Row(
                    children: [
                      Icon(s.$3, color: _green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            Text(
                              s.$2,
                              style: const TextStyle(
                                fontSize: 9,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );

  Widget _reviewPanel() {
    final categories = _categories;
    final selected = categories.contains(_category) ? _category : null;
    final indices = List.generate(widget.rows.length, (i) => i).where((i) {
      final row = widget.rows[i];
      return (selected == null || row['category_name'] == selected) &&
          '${row['item_name'] ?? ''} ${row['category_name'] ?? ''}'
              .toLowerCase()
              .contains(_search.toLowerCase());
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _badge(
                'Ready to review · ${widget.import?['filename'] ?? 'Menu file'}',
              ),
              const SizedBox(height: 14),
              _heading(
                Icons.fact_check_outlined,
                'Edit & confirm your menu',
                'Tweak names, prices, and categories — nothing goes live until you confirm.',
              ),
              const SizedBox(height: 14),
              const Text(
                'Save edits to keep your draft on this server for this branch.',
                style: TextStyle(fontSize: 11, color: _green),
              ),
            ],
          ),
          tint: true,
        ),
        const SizedBox(height: 16),
        _stats(),
        const SizedBox(height: 16),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BROWSE BY CATEGORY',
                style: TextStyle(
                  fontSize: 10,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text('All ${_active.length}'),
                    selected: selected == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  ...categories.map(
                    (category) => ChoiceChip(
                      label: Text(
                        '$category ${_active.where((r) => r['category_name'] == category).length}',
                      ),
                      selected: selected == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search items',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (indices.isEmpty) _panel(const Text('No items match this search.')),
        ...indices.map(
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ImportRow(
              key: ValueKey(
                '${widget.import?['id']}-$index-${identityHashCode(widget.rows[index])}',
              ),
              row: widget.rows[index],
              busy: widget.busy,
              deleted: _removed(widget.rows[index]),
              onChanged: (key, value) => widget.onRowChanged(index, key, value),
              onEdit: () => widget.onEdit(index),
              onImage: () => widget.onImage(index),
              onDelete: () => widget.onDelete(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBar() => SafeArea(
    top: false,
    child: Align(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C12253E),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final summary = Text(
                  '${_active.length} items ready',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                );
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: widget.busy ? null : widget.onCancel,
                      child: const Text('Discard draft'),
                    ),
                    OutlinedButton(
                      onPressed: widget.busy ? null : widget.onSave,
                      child: const Text('Save edits'),
                    ),
                    FilledButton.icon(
                      onPressed: widget.busy || _active.isEmpty
                          ? null
                          : widget.onConfirm,
                      icon: const Icon(Icons.arrow_forward, size: 17),
                      label: const Text('Confirm and go live'),
                    ),
                  ],
                );
                if (constraints.maxWidth >= 720) {
                  return Row(
                    children: [
                      Expanded(child: summary),
                      actions,
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [summary, const SizedBox(height: 8), actions],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _published() {
    final result = widget.import?['result'];
    final values = result is Map ? result : const <String, dynamic>{};
    final stats = [
      ('CREATE', values['created'] ?? values['items_created'] ?? 0, _green),
      (
        'UPDATE',
        values['updated'] ?? values['items_updated'] ?? 0,
        const Color(0xFF008ABD),
      ),
      ('SKIP', values['skipped'] ?? 0, _muted),
      (
        'ERROR',
        values['failed'] ??
            values['total_errors'] ??
            widget.import?['error_count'] ??
            0,
        const Color(0xFFD83C61),
      ),
    ];
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: _badge('Published')),
          const SizedBox(height: 12),
          _heading(
            Icons.task_alt,
            'Menu is live',
            'Items are on this branch and ready to sell. You can continue managing your menu or open the POS.',
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stats
                  .map(
                    (stat) => Container(
                      width:
                          (constraints.maxWidth -
                              (constraints.maxWidth < 450 ? 8 : 24)) /
                          (constraints.maxWidth < 450 ? 2 : 4),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: stat.$3.withValues(alpha: 0.04),
                        border: Border.all(
                          color: stat.$3.withValues(alpha: 0.25),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${stat.$2}',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: stat.$3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            stat.$1,
                            style: TextStyle(fontSize: 10, color: stat.$3),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final menu = FilledButton.icon(
                onPressed: widget.busy ? null : widget.onViewMenu,
                icon: const Icon(Icons.restaurant_menu, size: 18),
                label: const Text('View menu items'),
              );
              final pos = OutlinedButton.icon(
                onPressed: widget.busy ? null : widget.onOpenPos,
                icon: const Icon(Icons.point_of_sale, size: 18),
                label: const Text('Open POS'),
              );
              return constraints.maxWidth < 450
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [menu, const SizedBox(height: 8), pos],
                    )
                  : Row(
                      children: [
                        Expanded(child: menu),
                        const SizedBox(width: 8),
                        Expanded(child: pos),
                      ],
                    );
            },
          ),
          const SizedBox(height: 8),
          const Tooltip(
            message: 'AI enhancement requires an additional backend API.',
            child: OutlinedButton(
              onPressed: null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 16),
                  SizedBox(width: 8),
                  Text('Enhance with AI'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: widget.busy ? null : widget.onAnother,
              child: const Text('Upload another menu'),
            ),
          ),
        ],
      ),
      tint: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final caps = widget.capabilities;
    final canUpload = widget.import == null || widget.terminal;
    final maxKb = num.tryParse('${caps?['max_upload_kb']}') ?? 20480;
    final progress = num.tryParse('${widget.import?['progress']}');
    final status = '${widget.import?['status'] ?? ''}';
    final published =
        widget.terminal && ['completed', 'complete'].contains(status);
    final handheld = usePosHandheldLayout(context);
    final showBack = ModalRoute.of(context)?.settings.name == 'ai-menu';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('AI Menu Upload'),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: showBack || !handheld,
        actions: [
          if (!handheld)
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
            ),
          if (!handheld) const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: widget.review ? _actionBar() : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: EdgeInsets.fromLTRB(handheld ? 16 : 24, handheld ? 12 : 24, handheld ? 16 : 24, 24),
            children: [
              if (!handheld &&
                  !widget.review &&
                  !published &&
                  widget.alternateBody == null &&
                  widget.onChangeSource == null &&
                  (widget.import == null || widget.terminal)) ...[
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading(
                        Icons.menu_book_rounded,
                        'Add items to your menu',
                        'Upload a photo, PDF, or spreadsheet. You review every price before anything is saved.',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...['Photo', 'PDF', 'CSV / Excel'].map(_badge),
                          _badge(
                            'Max ${(maxKb / 1024).toStringAsFixed(0)} MB · PDF up to ${caps?['pdf_max_pages'] ?? 5} pages',
                          ),
                        ],
                      ),
                    ],
                  ),
                  tint: true,
                ),
                const SizedBox(height: 20),
              ],
              if (handheld) ...[
                _steps(),
                const SizedBox(height: 10),
              ],
              if (handheld && canUpload && !published) ...[
                widget.alternateBody ?? _uploadPanel(),
                const SizedBox(height: 16),
              ],
              if (!handheld) ...[
                _steps(),
                const SizedBox(height: 20),
              ],
              if (widget.busy) ...[
                const LinearProgressIndicator(color: _green),
                const SizedBox(height: 12),
              ],
              if (widget.error != null) ...[
                _panel(
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.busy ? null : widget.onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.review) _reviewPanel(),
              if (published) _published(),
              if (widget.import != null && !widget.review && !widget.terminal)
                MenuImportProgress(
                  key: ValueKey(widget.import?['id']),
                  progress: progress,
                  items: widget.rows.where((r) => !_removed(r)).length,
                  filename: '${widget.import?['filename'] ?? 'Menu file'}',
                  publishing: status == 'importing' || status == 'confirmed',
                  busy: widget.busy,
                  onRetry: widget.onRetry,
                  onCancel: widget.onCancel,
                ),
              if (widget.import != null &&
                  !widget.review &&
                  !published &&
                  widget.terminal) ...[
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading(
                        widget.terminal ? Icons.task_alt : Icons.auto_awesome,
                        switch (status) {
                          'completed' || 'complete' => 'Your menu is live',
                          'failed' => 'Import needs attention',
                          'cancelled' || 'canceled' => 'Import discarded',
                          _ =>
                            status == 'importing'
                                ? 'Publishing your menu'
                                : 'Preparing your menu',
                        },
                        '${widget.import?['filename'] ?? 'Menu file'}',
                      ),
                      if (!widget.terminal) ...[
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          color: _green,
                          value: progress == null
                              ? null
                              : (progress / 100).clamp(0, 1).toDouble(),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your file is uploaded. AI extraction may take a few minutes.',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                        TextButton.icon(
                          onPressed: widget.busy ? null : widget.onRetry,
                          icon: const Icon(Icons.refresh, size: 17),
                          label: const Text('Check status'),
                        ),
                        TextButton(
                          onPressed: widget.busy ? null : widget.onCancel,
                          child: const Text('Cancel import'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if ((num.tryParse('${widget.import?['error_count']}') ?? 0) > 0 ||
                  status == 'failed')
                TextButton(
                  onPressed: widget.busy ? null : widget.onErrors,
                  child: const Text('View import errors'),
                ),
              if (widget.errors != null) _panel(SelectableText(widget.errors!)),
              if (!handheld && canUpload && !published) ...[
                widget.alternateBody ?? _uploadPanel(),
                const SizedBox(height: 20),
                MenuExportSection(
                  busy: widget.busy,
                  onExport: widget.onExport,
                  onTemplate: widget.onTemplate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(84, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Change',
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      ),
    );
  }
}

class _UploadGuide extends StatelessWidget {
  const _UploadGuide();

  @override
  Widget build(BuildContext context) {
    return const _GuideLine(
      icon: Icons.info_outline_rounded,
      text: 'Use a clear photo, PDF, or spreadsheet.',
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.35, color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({
    super.key,
    required this.row,
    required this.busy,
    required this.deleted,
    required this.onChanged,
    required this.onEdit,
    required this.onImage,
    required this.onDelete,
  });
  final Map<String, dynamic> row;
  final bool busy, deleted;
  final void Function(String, String) onChanged;
  final VoidCallback onEdit, onImage, onDelete;
  Widget _field(String key, String label, {double? width}) => SizedBox(
    width: width,
    child: TextFormField(
      initialValue: '${row[key] ?? ''}',
      enabled: !busy && !deleted,
      onChanged: (value) => onChanged(key, value),
      keyboardType: key == 'price'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: deleted ? const Color(0xFFF0F2F5) : Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_outlined, size: 17, color: _green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${row['category_name'] ?? ''}${deleted ? ' · Removed' : ''}',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'More item details',
              onPressed: busy || deleted ? null : onEdit,
              icon: const Icon(Icons.tune, size: 18),
            ),
            IconButton(
              tooltip: deleted ? 'Restore item' : 'Remove item',
              onPressed: busy ? null : onDelete,
              icon: Icon(deleted ? Icons.undo : Icons.delete_outline, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 650;
            final name = _field('item_name', 'Item name');
            final price = _field('price', 'Price', width: wide ? 110 : null);
            final category = _field(
              'category_name',
              'Category',
              width: wide ? 160 : null,
            );
            final image = InkWell(
              onTap: busy || deleted ? null : onImage,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FC),
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(9),
                ),
                clipBehavior: Clip.antiAlias,
                child: '${row['image_url'] ?? ''}'.isEmpty
                    ? const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: _muted,
                      )
                    : Image.network(
                        '${row['image_url']}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: _muted,
                        ),
                      ),
              ),
            );
            if (wide) {
              return Row(
                children: [
                  image,
                  const SizedBox(width: 12),
                  Expanded(child: name),
                  const SizedBox(width: 10),
                  price,
                  const SizedBox(width: 10),
                  category,
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    image,
                    const SizedBox(width: 10),
                    Expanded(child: name),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: price),
                    const SizedBox(width: 10),
                    Expanded(child: category),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Type: ${row['item_type'] ?? '—'}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
            Text(
              'Available: ${row['is_available'] ?? '—'}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
            TextButton(
              onPressed: busy || deleted ? null : onEdit,
              child: const Text('Edit details', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ],
    ),
  );
}
