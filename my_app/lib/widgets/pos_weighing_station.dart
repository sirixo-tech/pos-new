import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/pos_models.dart';
import '../providers/pos_controller.dart';
import '../services/printing/weighed_label_printer.dart';
import '../services/scale/scale_line_settings.dart';
import '../services/scale/scale_link.dart';
import '../services/scale/scale_port.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/weighed_barcode.dart';
import 'pos_ui.dart';

/// Weighing station: pick a per-kg item, read the scale or type a weight,
/// then add it to the ticket or print a barcode label.
Future<void> showPosWeighingStation(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _WeighingStation(),
  );
}

class _WeighingStation extends StatefulWidget {
  const _WeighingStation();

  @override
  State<_WeighingStation> createState() => _WeighingStationState();
}

class _WeighingStationState extends State<_WeighingStation> {
  final _search = TextEditingController();
  final _manual = TextEditingController();
  final _command = TextEditingController();
  MenuItem? _selected;
  bool _settingsOpen = false;
  bool _busy = false;
  String? _error;
  String? _autoKey;

  ScaleLink get _scale => ScaleLink.instance;

  @override
  void initState() {
    super.initState();
    _command.text = _scale.settings.command;
    _scale.addListener(_onScale);
    unawaited(_scale.load().then((_) {
      if (!mounted) return;
      if (_command.text != _scale.settings.command) {
        _command.text = _scale.settings.command;
      }
      setState(() {});
    }));
  }

  @override
  void dispose() {
    _scale.removeListener(_onScale);
    _search.dispose();
    _manual.dispose();
    _command.dispose();
    super.dispose();
  }

  void _onScale() {
    if (!mounted) return;
    setState(() {});
    unawaited(_maybeAutoPrint());
  }

  List<MenuItem> _items(PosController pos) {
    final query = _search.text.trim().toLowerCase();
    final items = pos.flatItems.where((item) => item.soldByWeight).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (query.isEmpty) return items;
    return items.where((item) {
      if (item.name.toLowerCase().contains(query)) return true;
      final plu = item.pluCode?.toLowerCase() ?? '';
      return plu.contains(query);
    }).toList(growable: false);
  }

  double? _typedKg() {
    final text = _manual.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return null;
    return WeighedBarcode.roundKg(value);
  }

  double? _resolvedKg() {
    final typed = _manual.text.trim();
    if (typed.isNotEmpty) return _typedKg();
    final live = _scale.netKg;
    if (live == null) return null;
    return WeighedBarcode.roundKg(live);
  }

  Future<void> _connect() async {
    if (_scale.connected || _scale.connecting) {
      await _scale.disconnect();
      return;
    }
    if (_scale.promptsForPort) {
      await _scale.connectFromBrowser();
      if (!mounted) return;
      setState(() => _error = _scale.error);
      return;
    }
    setState(() => _error = null);
    if (!_scale.isSupported) {
      setState(() {
        _error =
            'Scale connection is available in Chrome, Windows, and Android. Enter the weight below on this device.';
      });
      return;
    }
    try {
      final ports = await _scale.listPorts();
      if (!mounted) return;
      if (ports.isEmpty) {
        setState(() {
          _error = 'No scale port found. Plug in the scale, then connect again.';
        });
        return;
      }
      final port = ports.length == 1
          ? ports.first
          : await _pickPort(context, ports);
      if (port == null || !mounted) return;
      await _scale.connect(port);
      if (!mounted) return;
      setState(() => _error = _scale.error);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _add() async {
    final item = _selected;
    final pos = context.read<PosController>();
    if (item == null) {
      setState(() => _error = 'Select an item.');
      return;
    }
    final kg = _resolvedKg();
    if (kg == null) {
      setState(() {
        _error = _manual.text.trim().isEmpty
            ? 'Place the item on the scale or enter a weight.'
            : 'Enter the weight in kilograms.';
      });
      return;
    }
    final range = pos.weighedWeightError(item, kg);
    if (range != null) {
      setState(() => _error = range);
      return;
    }
    pos.addToCart(
      CartLine(
        menuItem: item,
        quantity: 1,
        weightKg: kg,
        unitRate: item.price,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _print(double kg, {bool automatic = false}) async {
    final item = _selected;
    final pos = context.read<PosController>();
    if (item == null) return;
    final settings =
        pos.bootstrap?.restaurant.weighing ?? const WeighingSettings();
    if (!settings.enabled) {
      setState(() => _error = 'Label printing is turned off for this restaurant.');
      return;
    }
    if (item.pluCode == null || item.pluCode!.isEmpty) {
      setState(() => _error = 'A PLU code is required to print a label.');
      return;
    }
    final range = pos.weighedWeightError(item, kg);
    if (range != null) {
      setState(() => _error = range);
      return;
    }
    final session = pos.session;
    if (session == null) {
      setState(() => _error = 'Sign in before printing a label.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await WeighedLabelPrinter.print(
        session: session,
        item: item,
        weightKg: kg,
        settings: settings,
        restaurantName: pos.bootstrap?.restaurant.name ?? '',
        currency: pos.bootstrap?.restaurant.defaultCurrency ?? 'INR',
        online: pos.isOnline,
        terminalCode: pos.selectedTerminal?.code,
      );
      if (!mounted) return;
      showPosSnackBar(
        context,
        automatic ? 'Label printed from the stable weight' : 'Label sent to the printer',
      );
      if (!automatic) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
        if (automatic) _autoKey = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPressed() async {
    final kg = _resolvedKg();
    if (kg == null) {
      setState(() {
        _error = _manual.text.trim().isEmpty
            ? 'Place the item on the scale or enter a weight.'
            : 'Enter the weight in kilograms.';
      });
      return;
    }
    await _print(kg);
  }

  Future<void> _maybeAutoPrint() async {
    if (_busy || _manual.text.trim().isNotEmpty) return;
    final pos = context.read<PosController>();
    final settings =
        pos.bootstrap?.restaurant.weighing ?? const WeighingSettings();
    if (!settings.autoPrintOnStable || !_scale.stable) {
      if (!_scale.stable) _autoKey = null;
      return;
    }
    final item = _selected;
    final kg = _scale.netKg;
    if (item == null || kg == null || kg <= 0) return;
    final key = '${item.id}:${WeighedBarcode.formatKg(kg)}';
    if (_autoKey == key) return;
    _autoKey = key;
    await _print(kg, automatic: true);
  }

  Future<void> _saveSettings(ScaleLineSettings next) async {
    await _scale.updateSettings(next);
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final currency = pos.bootstrap?.restaurant.defaultCurrency ?? 'INR';
    final items = _items(pos);
    final item = _selected;
    final typed = _typedKg();
    final usingScale = _manual.text.trim().isEmpty;
    final kg = usingScale ? _scale.netKg : typed;
    final total = item == null || kg == null
        ? 0.0
        : WeighedBarcode.lineTotal(item.price, kg);
    final canPrint = item?.pluCode?.isNotEmpty == true;
    final accent = PosTheme.accent;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final catalog = _Catalog(
      search: _search,
      items: items,
      selected: item,
      currency: currency,
      onChanged: () => setState(() {}),
      onSelect: (next) => setState(() {
        _selected = next;
        _error = null;
        _autoKey = null;
      }),
    );
    final readout = _Readout(
      item: item,
      currency: currency,
      kilograms: kg,
      total: total,
      scale: _scale,
      settingsOpen: _settingsOpen,
      command: _command,
      manual: _manual,
      onToggleSettings: () => setState(() => _settingsOpen = !_settingsOpen),
      onConnect: _connect,
      onSettings: _saveSettings,
      onManual: () => setState(() => _error = null),
      onTare: _scale.tare,
    );

    return Dialog(
      backgroundColor: PosTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: PosTheme.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weighing station',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: PosTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Select an item, place it on the scale, and print a barcode label to scan at billing.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: PosTheme.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _IconPlate(
                    tooltip: 'Close',
                    icon: Icons.close_rounded,
                    onPressed: _busy ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 292, child: catalog),
                    const SizedBox(width: 16),
                    Expanded(child: readout),
                  ],
                )
              else ...[
                catalog,
                const SizedBox(height: 14),
                readout,
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: PosTheme.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: accent),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  _StationButton(
                    label: 'Add to ticket',
                    icon: Icons.shopping_cart_outlined,
                    onPressed: _busy || item == null ? null : _add,
                  ),
                  const SizedBox(width: 8),
                  _StationButton(
                    label: _busy ? 'Printing…' : 'Print label',
                    icon: Icons.print_outlined,
                    filled: true,
                    onPressed: _busy || item == null || !canPrint
                        ? null
                        : _printPressed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Catalog extends StatelessWidget {
  const _Catalog({
    required this.search,
    required this.items,
    required this.selected,
    required this.currency,
    required this.onChanged,
    required this.onSelect,
  });

  final TextEditingController search;
  final List<MenuItem> items;
  final MenuItem? selected;
  final String currency;
  final VoidCallback onChanged;
  final ValueChanged<MenuItem> onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = PosTheme.accent;
    final listHeight = items.isEmpty
        ? 88.0
        : (items.length * 64.0).clamp(64.0, 248.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: search,
          onChanged: (_) => onChanged(),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: PosTheme.ink,
          ),
          decoration: _stationField(
            hint: 'Search by name or PLU',
          ).copyWith(
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: PosTheme.inkMuted),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: listHeight,
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'No weighed items yet. Edit an item and set Sold by to Weight (per kg).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PosTheme.inkMuted, height: 1.35),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  padding: EdgeInsets.zero,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final active = item.id == selected?.id;
                    return Material(
                      color: active
                          ? accent.withValues(alpha: 0.1)
                          : PosTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelect(item),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? accent.withValues(alpha: 0.45)
                                  : PosTheme.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: active
                                      ? accent.withValues(alpha: 0.14)
                                      : PosTheme.surfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  active
                                      ? Icons.check_rounded
                                      : Icons.scale_outlined,
                                  color: active ? accent : PosTheme.inkMuted,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: PosTheme.ink,
                                      ),
                                    ),
                                    Text(
                                      item.pluCode == null
                                          ? 'No PLU'
                                          : 'PLU ${item.pluCode}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: PosTheme.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${formatMoney(item.price, currency)} /kg',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.item,
    required this.currency,
    required this.kilograms,
    required this.total,
    required this.scale,
    required this.settingsOpen,
    required this.command,
    required this.manual,
    required this.onToggleSettings,
    required this.onConnect,
    required this.onSettings,
    required this.onManual,
    required this.onTare,
  });

  final MenuItem? item;
  final String currency;
  final double? kilograms;
  final double total;
  final ScaleLink scale;
  final bool settingsOpen;
  final TextEditingController command;
  final TextEditingController manual;
  final VoidCallback onToggleSettings;
  final VoidCallback onConnect;
  final ValueChanged<ScaleLineSettings> onSettings;
  final VoidCallback onManual;
  final VoidCallback onTare;

  @override
  Widget build(BuildContext context) {
    final accent = PosTheme.accent;
    final kg = kilograms ?? 0;
    final live = manual.text.trim().isEmpty;
    final caption = item == null
        ? 'Select an item'
        : !live
        ? 'Using the weight you typed'
        : !scale.connected
        ? 'Place the item on the scale'
        : scale.stable && kg > 0
        ? 'Stable'
        : kg > 0
        ? 'Settling…'
        : 'Place the item on the scale';
    final chip = scale.connecting
        ? 'Connecting'
        : scale.connected
        ? 'Scale connected'
        : 'Scale not connected';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: scale.connected
                  ? const Color(0xFF16A34A)
                  : PosTheme.inkFaint,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                scale.statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: PosTheme.inkMuted,
                ),
              ),
            ),
            _IconPlate(
              tooltip: 'Scale settings',
              icon: settingsOpen ? Icons.tune_rounded : Icons.settings_outlined,
              onPressed: onToggleSettings,
            ),
            const SizedBox(width: 8),
            _StationButton(
              label: scale.connected ? 'Disconnect' : 'Connect scale',
              icon: scale.connected ? Icons.link_off_rounded : Icons.usb_rounded,
              filled: true,
              onPressed: scale.connecting ? null : onConnect,
            ),
          ],
        ),
        if (settingsOpen) ...[
          const SizedBox(height: 10),
          _SettingsPanel(
            settings: scale.settings,
            command: command,
            onChanged: onSettings,
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF141C2B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item?.name ?? 'No item selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (scale.connected) ...[
                    _StationButton(
                      label: 'Tare',
                      onPressed: onTare,
                      compact: true,
                      onDark: true,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 7,
                          color: scale.connected
                              ? const Color(0xFF4ADE80)
                              : Colors.white54,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          chip,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: WeighedBarcode.formatKg(kg),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        height: 1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                caption,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MoneyBit(
                      label: 'Rate / kg',
                      value: item == null ? '—' : formatMoney(item!.price, currency),
                    ),
                  ),
                  Expanded(
                    child: _MoneyBit(
                      label: 'Total',
                      value: formatMoney(total, currency),
                      alignEnd: true,
                      emphasize: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: manual,
          onChanged: (_) => onManual(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: PosTheme.ink,
          ),
          decoration: _stationField(
            label: 'Manual weight (kg)',
            helper: 'Leave empty to use the scale reading.',
          ).copyWith(suffixText: 'kg'),
        ),
      ],
    );
  }
}

class _MoneyBit extends StatelessWidget {
  const _MoneyBit({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool alignEnd;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final accent = PosTheme.accent;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? accent : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: emphasize ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.settings,
    required this.command,
    required this.onChanged,
  });

  final ScaleLineSettings settings;
  final TextEditingController command;
  final ValueChanged<ScaleLineSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Choice<int>(
                  label: 'Baud rate',
                  value: settings.baud,
                  values: ScaleLineSettings.baudRates,
                  labelOf: (value) => '$value',
                  onChanged: (value) => onChanged(settings.copyWith(baud: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Choice<String>(
                  label: 'Parity',
                  value: settings.parity,
                  values: ScaleLineSettings.parities,
                  labelOf: (value) => value,
                  onChanged: (value) =>
                      onChanged(settings.copyWith(parity: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Choice<int>(
                  label: 'Data bits',
                  value: settings.dataBits,
                  values: ScaleLineSettings.dataBitChoices,
                  labelOf: (value) => '$value',
                  onChanged: (value) =>
                      onChanged(settings.copyWith(dataBits: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Choice<String>(
                  label: 'Scale unit',
                  value: settings.unit,
                  values: ScaleLineSettings.units,
                  labelOf: (value) => value == 'auto' ? 'Auto-detect' : value,
                  onChanged: (value) => onChanged(settings.copyWith(unit: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: command,
            onChanged: (value) => onChanged(settings.copyWith(command: value)),
            style: TextStyle(fontWeight: FontWeight.w600, color: PosTheme.ink),
            decoration: _stationField(
              label: 'Weight request command (optional)',
              hint: r'W\r\n',
              helper:
                  'Leave empty for scales that stream weight continuously. Use \\r and \\n for line endings. Changes apply the next time you connect.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: values.contains(value) ? value : values.first,
      decoration: _stationField(label: label),
      items: [
        for (final entry in values)
          DropdownMenuItem(value: entry, child: Text(labelOf(entry))),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

InputDecoration _stationField({
  String? label,
  String? hint,
  String? helper,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: PosTheme.border),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    isDense: true,
    filled: true,
    fillColor: PosTheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: PosTheme.accent.withValues(alpha: 0.7)),
    ),
  );
}

class _IconPlate extends StatelessWidget {
  const _IconPlate({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PosTheme.border),
            ),
            child: Icon(icon, size: 18, color: PosTheme.inkMuted),
          ),
        ),
      ),
    );
  }
}

class _StationButton extends StatelessWidget {
  const _StationButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.compact = false,
    this.onDark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final accent = PosTheme.accent;
    final enabled = onPressed != null;
    final border = onDark
        ? Colors.white.withValues(alpha: 0.22)
        : PosTheme.border;
    final background = !enabled
        ? (onDark ? Colors.white.withValues(alpha: 0.06) : PosTheme.surfaceMuted)
        : filled
        ? accent
        : (onDark ? Colors.transparent : PosTheme.surface);
    final foreground = !enabled
        ? (onDark ? Colors.white38 : PosTheme.inkFaint)
        : filled
        ? Colors.white
        : (onDark ? Colors.white : PosTheme.ink);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          height: compact ? 28 : 36,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled && enabled
                  ? Colors.white.withValues(alpha: 0.28)
                  : border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<ScalePortInfo?> _pickPort(
  BuildContext context,
  List<ScalePortInfo> ports,
) {
  return showDialog<ScalePortInfo>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Choose the scale'),
      children: [
        for (final port in ports)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, port),
            child: Text(port.title),
          ),
      ],
    ),
  );
}
