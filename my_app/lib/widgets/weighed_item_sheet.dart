import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/weighed_barcode.dart';

/// Keypad weight entry for one item. Matches the register popup: type or tap
/// the weight, then add that weighing to the ticket.
Future<void> showWeighedItemSheet(
  BuildContext context, {
  required PosController pos,
  required MenuItem item,
  CartLine? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _WeighedItemSheet(
      pos: pos,
      item: item,
      existing: existing,
    ),
  );
}

class _WeighedItemSheet extends StatefulWidget {
  const _WeighedItemSheet({
    required this.pos,
    required this.item,
    this.existing,
  });

  final PosController pos;
  final MenuItem item;
  final CartLine? existing;

  @override
  State<_WeighedItemSheet> createState() => _WeighedItemSheetState();
}

class _WeighedItemSheetState extends State<_WeighedItemSheet> {
  late String _text;
  bool _grams = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final kg = widget.existing?.weightKg;
    _text = kg == null ? '' : _trim(kg, grams: false);
  }

  double? get _kilograms {
    final raw = double.tryParse(_text.replaceAll(',', '.'));
    if (raw == null) return null;
    return WeighedBarcode.roundKg(_grams ? raw / 1000 : raw);
  }

  void _append(String value) {
    if (value == '.' && _text.contains('.')) return;
    if (_text.length >= 8) return;
    if (value == '.' && _text.isEmpty) {
      setState(() {
        _text = '0.';
        _error = null;
      });
      return;
    }
    setState(() {
      _text += value;
      _error = null;
    });
  }

  void _backspace() {
    if (_text.isEmpty) return;
    setState(() {
      _text = _text.substring(0, _text.length - 1);
      _error = null;
    });
  }

  void _setGrams(bool grams) {
    if (grams == _grams) return;
    final raw = double.tryParse(_text.replaceAll(',', '.'));
    var next = _text;
    if (raw != null) {
      final converted = grams ? raw * 1000 : raw / 1000;
      next = _trim(converted, grams: grams);
    }
    setState(() {
      _grams = grams;
      _text = next;
      _error = null;
    });
  }

  String _trim(double value, {required bool grams}) {
    final text = value.toStringAsFixed(grams ? 0 : 3);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _add() {
    final kg = _kilograms;
    if (kg == null) {
      setState(() => _error = 'Enter the weight.');
      return;
    }
    final range = widget.pos.weighedWeightError(widget.item, kg);
    if (range != null) {
      setState(() => _error = range);
      return;
    }
    final existing = widget.existing;
    if (existing != null) {
      final error = widget.pos.updateWeighedCartLine(existing, weightKg: kg);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      Navigator.pop(context);
      return;
    }
    widget.pos.addToCart(
      CartLine(
        menuItem: widget.item,
        quantity: 1,
        weightKg: kg,
        unitRate: widget.item.price,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.pos.bootstrap?.restaurant.defaultCurrency ?? 'INR';
    final kg = _kilograms ?? 0;
    final rate = widget.existing?.ratePerKg ?? widget.item.price;
    final total = WeighedBarcode.lineTotal(rate, kg);
    final accent = PosTheme.accent;
    final shown = _text.isEmpty ? '0' : _text;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _add,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _add,
        const SingleActivator(LogicalKeyboardKey.backspace): _backspace,
        const SingleActivator(LogicalKeyboardKey.keyK): () => _setGrams(false),
        const SingleActivator(LogicalKeyboardKey.keyG): () => _setGrams(true),
        const SingleActivator(LogicalKeyboardKey.period): () => _append('.'),
        const SingleActivator(LogicalKeyboardKey.numpadDecimal): () =>
            _append('.'),
        for (var digit = 0; digit <= 9; digit++) ...{
          SingleActivator(LogicalKeyboardKey(0x30 + digit)): () =>
              _append('$digit'),
          SingleActivator(
            LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + digit),
          ): () => _append('$digit'),
        },
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    'Enter the weight to price this item at ${formatMoney(rate, currency)} per kg.',
                    style: TextStyle(color: PosTheme.inkMuted, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'WEIGHT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                      const Spacer(),
                      SegmentedButton<bool>(
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return accent;
                            }
                            return PosTheme.surfaceMuted;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return PosTheme.ink;
                          }),
                        ),
                        segments: const [
                          ButtonSegment(value: false, label: Text('kg')),
                          ButtonSegment(value: true, label: Text('g')),
                        ],
                        selected: {_grams},
                        onSelectionChanged: (value) => _setGrams(value.first),
                        showSelectedIcon: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: shown,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: _grams ? ' g' : ' kg',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PosTheme.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Keypad(onKey: _append, onBackspace: _backspace),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${WeighedBarcode.formatKg(kg)} kg × ${formatMoney(rate, currency)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          formatMoney(total, currency),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _editing
                        ? 'Type the weight on your keyboard. Enter to update. K or G to switch units.'
                        : 'Type the weight on your keyboard. Enter to add. K or G to switch units.',
                    style: TextStyle(color: PosTheme.inkMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _add,
                        child: Text(_editing ? 'Update weight' : 'Add to ticket'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, required this.onBackspace});

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: [
        for (final key in keys)
          OutlinedButton(
            onPressed: key == '⌫' ? onBackspace : () => onKey(key),
            style: OutlinedButton.styleFrom(
              foregroundColor: PosTheme.ink,
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            child: Text(key),
          ),
      ],
    );
  }
}
