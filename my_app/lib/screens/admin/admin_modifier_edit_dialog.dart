import 'package:flutter/material.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_ui.dart';
import 'admin_chrome.dart';

class AdminModifierOptionEditResult {
  const AdminModifierOptionEditResult({
    this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
  });

  final int? id;
  final String name;
  final double price;
  final bool isAvailable;
}

class AdminModifierEditResult {
  const AdminModifierEditResult({
    required this.name,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.options,
  });

  final String name;
  final bool isRequired;
  final int minSelections;
  final int? maxSelections;
  final List<AdminModifierOptionEditResult> options;

  Map<String, dynamic> toBody() => {
        'name': name,
        'is_required': isRequired,
        'min_selections': minSelections,
        'max_selections': maxSelections,
        'options': [
          for (final o in options)
            {
              if (o.id != null) 'id': o.id,
              'name': o.name,
              'price_adjustment': o.price,
              'is_available': o.isAvailable,
            },
        ],
      };
}

Future<AdminModifierEditResult?> showAdminModifierEditDialog(
  BuildContext context, {
  AdminMenuModifier? modifier,
}) {
  return showAdminPanel<AdminModifierEditResult>(
    context: context,
    sidePanelWidth: 520,
    builder: (ctx) => _ModifierEditDialog(modifier: modifier),
  );
}

class _ModifierEditDialog extends StatefulWidget {
  const _ModifierEditDialog({this.modifier});

  final AdminMenuModifier? modifier;

  @override
  State<_ModifierEditDialog> createState() => _ModifierEditDialogState();
}

class _ModifierEditDialogState extends State<_ModifierEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late bool _isRequired;
  late List<_OptionDraft> _options;

  bool get _isCreate => widget.modifier == null;

  @override
  void initState() {
    super.initState();
    final modifier = widget.modifier;
    _nameCtrl = TextEditingController(text: modifier?.name ?? '');
    _isRequired = modifier?.isRequired ?? false;
    _minCtrl = TextEditingController(
      text: '${modifier?.minSelections ?? 0}',
    );
    _maxCtrl = TextEditingController(
      text: modifier?.maxSelections?.toString() ?? '',
    );
    _options = [
      for (final opt in modifier?.options ?? const <AdminMenuModifierOption>[])
        _OptionDraft(
          id: opt.id,
          name: opt.name,
          price: opt.priceAdjustment,
          isAvailable: opt.isAvailable,
        ),
    ];
    if (_options.isEmpty) {
      _options = [_OptionDraft()];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() => _options = [..._options, _OptionDraft()]);
  }

  void _removeOption(int index) {
    if (_options.length <= 1) return;
    setState(() {
      _options[index].dispose();
      _options = [..._options]..removeAt(index);
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showPosSnackBar(
        context,
        context.posText('adminEnterName', 'Enter a name'),
        error: true,
      );
      return;
    }

    final options = <AdminModifierOptionEditResult>[];
    for (var i = 0; i < _options.length; i++) {
      final draft = _options[i];
      final optionName = draft.nameCtrl.text.trim();
      if (optionName.isEmpty) {
        showPosSnackBar(
          context,
          context.posText(
            'adminOptionNeedsName',
            'Option {n} needs a name',
            {'n': '${i + 1}'},
          ),
          error: true,
        );
        return;
      }
      options.add(
        AdminModifierOptionEditResult(
          id: draft.id,
          name: optionName,
          price: double.tryParse(draft.priceCtrl.text.trim()) ?? 0,
          isAvailable: draft.isAvailable,
        ),
      );
    }

    final minSelections = int.tryParse(_minCtrl.text.trim()) ?? 0;
    final maxRaw = _maxCtrl.text.trim();
    final maxSelections = maxRaw.isEmpty ? null : int.tryParse(maxRaw);

    Navigator.pop(
      context,
      AdminModifierEditResult(
        name: name,
        isRequired: _isRequired,
        minSelections: minSelections,
        maxSelections: maxSelections,
        options: options,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
  }) {
    final radius = BorderRadius.circular(PosTheme.radiusSm);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      // Bright fill so fields don't read as disabled against muted chrome.
      fillColor: PosTheme.isDark ? PosTheme.surfaceMuted : Colors.white,
      labelStyle: TextStyle(color: PosTheme.inkMuted, fontWeight: FontWeight.w600),
      floatingLabelStyle: TextStyle(
        color: PosTheme.ink,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(color: PosTheme.inkFaint),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: PosTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: PosTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return PosDialogShell(
      title: _isCreate
          ? context.posText('adminNewModifier', 'New modifier')
          : context.posText('adminEditModifier', 'Edit modifier'),
      subtitle: context.posText(
        'adminModifierEditHint',
        'Group choices like size or toppings with price adjustments.',
      ),
      icon: Icons.tune_rounded,
      maxWidth: 480,
      embedded: true,
      onClose: () => Navigator.pop(context),
      body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                style: TextStyle(
                  color: PosTheme.ink,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _fieldDecoration(
                  label: context.posText('adminName', 'Name'),
                  hint: context.posText('adminModifierHint', 'Size'),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.posText('adminRequired', 'Required'),
                  style: TextStyle(
                    color: PosTheme.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  context.posText(
                    'adminRequiredHelp',
                    'Guest must choose before adding to cart',
                  ),
                  style: TextStyle(color: PosTheme.inkMuted, fontSize: 12.5),
                ),
                value: _isRequired,
                onChanged: (v) => setState(() => _isRequired = v),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: PosTheme.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _fieldDecoration(
                        label: context.posText('adminMin', 'Min'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: PosTheme.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _fieldDecoration(
                        label: context.posText('adminMax', 'Max'),
                        hint: context.posText('commonOptional', 'Optional'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.posText('adminOptions', 'Options'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: PosTheme.ink,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addOption,
                    style: TextButton.styleFrom(foregroundColor: accent),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      context.posText('adminAddOption', 'Add option'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _options.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PosTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PosTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.posText(
                                'adminOptionN',
                                'Option {n}',
                                {'n': '${i + 1}'},
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: PosTheme.ink,
                              ),
                            ),
                          ),
                          if (_options.length > 1)
                            IconButton(
                              onPressed: () => _removeOption(i),
                              icon: Icon(
                                Icons.close_rounded,
                                color: PosTheme.inkMuted,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      TextField(
                        controller: _options[i].nameCtrl,
                        style: TextStyle(
                          color: PosTheme.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _fieldDecoration(
                          label: context.posText('adminName', 'Name'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _options[i].priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        style: TextStyle(
                          color: PosTheme.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _fieldDecoration(
                          label: context.posText(
                            'adminPriceAdj',
                            'Price ±',
                          ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          context.posText('adminAvailable', 'Available'),
                          style: TextStyle(
                            color: PosTheme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: _options[i].isAvailable,
                        onChanged: (v) =>
                            setState(() => _options[i].isAvailable = v),
                      ),
                    ],
                  ),
                ),
              ],
            ],
      ),
      footer: posDialogActionFooter(
        context: context,
        confirmLabel: _isCreate
            ? context.posText('adminCreate', 'Create')
            : context.l10n.commonSave,
        onCancel: () => Navigator.pop(context),
        onConfirm: _save,
      ),
    );
  }
}

class _OptionDraft {
  _OptionDraft({
    this.id,
    String name = '',
    double price = 0,
    this.isAvailable = true,
  })  : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(
          text: price == 0 ? '0' : price.toString(),
        );

  final int? id;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  bool isAvailable;

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}
