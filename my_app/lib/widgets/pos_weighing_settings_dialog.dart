import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/pos_controller.dart';
import '../services/pos_api.dart';
import '../theme/pos_theme.dart';
import '../utils/weighed_barcode.dart';
import 'pos_ui.dart';

Future<void> showPosWeighingSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _WeighingSettingsDialog(),
  );
}

class _WeighingSettingsDialog extends StatefulWidget {
  const _WeighingSettingsDialog();

  @override
  State<_WeighingSettingsDialog> createState() => _WeighingSettingsDialogState();
}

class _WeighingSettingsDialogState extends State<_WeighingSettingsDialog> {
  WeighingSettings? _draft;
  final _prefix = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = context.read<PosController>().bootstrap?.restaurant.weighing ??
        const WeighingSettings();
    _apply(current);
    _reloadFromServer();
  }

  Future<void> _reloadFromServer() async {
    final pos = context.read<PosController>();
    try {
      await pos.refreshBootstrap();
    } catch (_) {}
    if (!mounted || _dirty) return;
    setState(() {
      _apply(
        pos.bootstrap?.restaurant.weighing ?? const WeighingSettings(),
      );
    });
  }

  void _apply(WeighingSettings settings) {
    _draft = settings;
    _prefix.text = settings.prefix;
    _width.text = '${settings.labelWidthMm}';
    _height.text = '${settings.labelHeightMm}';
  }

  @override
  void dispose() {
    _prefix.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  WeighingSettings _read() {
    final current = _draft ?? const WeighingSettings();
    final width = int.tryParse(_width.text.trim());
    final height = int.tryParse(_height.text.trim());
    return current.copyWith(
      prefix: _prefix.text.trim(),
      labelWidthMm: width ?? current.labelWidthMm,
      labelHeightMm: height ?? current.labelHeightMm,
    );
  }

  String? _validate(WeighingSettings settings) {
    final prefix = settings.prefix;
    if (!RegExp(r'^\d{1,2}$').hasMatch(prefix)) {
      return 'Barcode prefix must be 1 or 2 digits, usually 20–29.';
    }
    if (settings.labelWidthMm < 30 || settings.labelWidthMm > 110) {
      return 'Label width must be from 30 to 110 mm.';
    }
    if (settings.labelHeightMm < 20 || settings.labelHeightMm > 150) {
      return 'Label height must be from 20 to 150 mm.';
    }
    return null;
  }

  Future<void> _save() async {
    final settings = _read();
    final invalid = _validate(settings);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = PosApi();
      final current = await api.fetchAdminSettings(session);
      await api.updateWeighingSettings(
        session,
        current: current,
        weighing: settings,
      );
      await pos.refreshBootstrap();
      if (!mounted) return;
      Navigator.pop(context);
      showPosSnackBar(context, 'Weighing settings saved');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _read();
    final pluDigits = draft.pluLength;
    final valueDigits = draft.valueLength;

    return PosDialogShell(
      title: 'Weighing scale & labels',
      subtitle:
          'Same restaurant settings as the web Ordering tab. Manual weight entry stays available when this is off.',
      icon: Icons.scale_rounded,
      maxWidth: 520,
      onClose: _saving ? null : () => Navigator.pop(context),
      footer: Row(
        children: [
          const Spacer(),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const _SettingIcon(Icons.scale_rounded),
              title: const Text('Enable weighing scale & labels'),
              subtitle: const Text(
                'Shows the weighing station and scale connection in the POS. Manual weight entry works even when this is off.',
              ),
              value: draft.enabled,
              onChanged: _saving
                  ? null
                  : (value) {
                      _dirty = true;
                      setState(() => _draft = draft.copyWith(enabled: value));
                    },
            ),
            if (draft.enabled) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('format-${draft.barcodeFormat}'),
                initialValue: draft.isCustom ? 'custom' : 'ean13',
                decoration: const InputDecoration(
                  labelText: 'Barcode format',
                  helperText:
                      'EAN-13 is 13 digits with a check digit. Custom is prefix, PLU, and value only.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ean13',
                    child: Text('EAN-13 (13 digits with check digit)'),
                  ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom (no check digit)'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        _dirty = true;
                        setState(
                          () => _draft = draft.copyWith(barcodeFormat: value),
                        );
                      },
              ),
              if (draft.isCustom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('plu-${draft.pluDigits}'),
                        initialValue: draft.pluDigits.clamp(1, 6),
                        decoration: const InputDecoration(labelText: 'PLU digits'),
                        items: [
                          for (var digit = 1; digit <= 6; digit++)
                            DropdownMenuItem(value: digit, child: Text('$digit')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                _dirty = true;
                                setState(
                                  () => _draft = draft.copyWith(pluDigits: value),
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('value-${draft.valueDigits}'),
                        initialValue: draft.valueDigits.clamp(4, 6),
                        decoration: const InputDecoration(
                          labelText: 'Value digits',
                        ),
                        items: [
                          for (var digit = 4; digit <= 6; digit++)
                            DropdownMenuItem(value: digit, child: Text('$digit')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                _dirty = true;
                                setState(
                                  () => _draft = draft.copyWith(valueDigits: value),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _prefix,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                maxLength: 2,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Barcode prefix',
                  counterText: '',
                  helperText: draft.isCustom
                      ? '1–2 digits at the start of every scale label.'
                      : '1–2 digits that mark scale labels (usually 20–29). Leaves $pluDigits digits for the PLU code.',
                ),
                onChanged: (_) {
                  _dirty = true;
                  setState(() => _error = null);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('payload-${draft.payload}'),
                initialValue: draft.payload,
                decoration: InputDecoration(
                  labelText: 'Barcode carries',
                  helperText:
                      'Weight lets the POS recalculate the price from the current rate. The value is limited to $valueDigits digits.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'weight',
                    child: Text('Weight in grams (recommended)'),
                  ),
                  DropdownMenuItem(value: 'price', child: Text('Price')),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        _dirty = true;
                        setState(() => _draft = draft.copyWith(payload: value));
                      },
              ),
              if (draft.payload == 'price') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('decimals-${draft.priceDecimals}'),
                  initialValue: draft.priceDecimals.clamp(0, 2),
                  decoration: const InputDecoration(labelText: 'Price decimals'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('0')),
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          _dirty = true;
                          setState(
                            () => _draft = draft.copyWith(priceDecimals: value),
                          );
                        },
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'LABEL BARCODE FORMAT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: PosTheme.inkFaint,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                draft.barcodeFormatPreview,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                draft.isCustom
                    ? 'Prefix + PLU (P) + value (V) = ${draft.barcodeLength} digits. No check digit.'
                    : 'Prefix + PLU (P) + $valueDigits-digit value (V) + check digit (C) = 13 digits.',
                style: TextStyle(fontSize: 12, color: PosTheme.inkMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _width,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Label width (mm)',
                      ),
                      onChanged: (_) {
                        _dirty = true;
                        setState(() => _error = null);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _height,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Label height (mm)',
                      ),
                      onChanged: (_) {
                        _dirty = true;
                        setState(() => _error = null);
                      },
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const _SettingIcon(Icons.storefront_outlined),
                title: const Text('Show restaurant name on label'),
                value: draft.labelShowRestaurant,
                onChanged: _saving
                    ? null
                    : (value) {
                        _dirty = true;
                        setState(
                          () => _draft = draft.copyWith(labelShowRestaurant: value),
                        );
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const _SettingIcon(Icons.calendar_today_rounded),
                title: const Text('Show packed date & time on label'),
                value: draft.labelShowDate,
                onChanged: _saving
                    ? null
                    : (value) {
                        _dirty = true;
                        setState(
                          () => _draft = draft.copyWith(labelShowDate: value),
                        );
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const _SettingIcon(Icons.print_rounded),
                title: const Text('Auto-print when weight is stable'),
                subtitle: const Text(
                  'Prints a label as soon as the scale reports a stable weight for the selected item.',
                ),
                value: draft.autoPrintOnStable,
                onChanged: _saving
                    ? null
                    : (value) {
                        _dirty = true;
                        setState(
                          () => _draft = draft.copyWith(autoPrintOnStable: value),
                        );
                      },
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: accent),
    );
  }
}
