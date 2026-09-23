import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../services/printing/network_printer.dart';
import '../services/printing/pos_receipt_printer.dart';
import '../services/printing/printer_paper_sensor.dart';
import '../services/printing/printer_health.dart';
import '../services/printing/printer_status_service.dart';
import '../services/printing/scan_to_print_settings.dart';
import '../theme/pos_theme.dart';
import '../utils/thermal_printer_platform.dart';
import '../widgets/pos_ui.dart';

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({
    super.key,
    this.embedded = false,
  });

  /// True when shown inside the POS overlay dialog (Selfx-style).
  final bool embedded;

  /// Opens printer setup over the register (dialog on desktop, page on phone).
  static Future<void> open(BuildContext context) async {
    final size = MediaQuery.sizeOf(context);
    final asDialog = size.width >= 700;
    if (asDialog) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (_) {
          return Dialog(
            backgroundColor: PosTheme.canvas,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusLg),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 720,
                maxHeight: size.height * 0.88,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PosTheme.radiusLg),
                child: const PrinterSetupScreen(embedded: true),
              ),
            ),
          );
        },
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PrinterSetupScreen(),
        ),
      );
    }
    if (!context.mounted) return;
    await context.read<PrinterStatusService>().refresh(allowBluetoothScan: true);
  }

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  /// 0 = USB, 1 = Network/LAN, 2 = Bluetooth, 3 = Built-in SmartPOS.
  int _tab = 0;
  List<UsbPrinterDevice> _usbPrinters = [];
  List<UsbPrinterDevice> _bluetoothPrinters = [];
  UsbPrinterConfig? _savedConfig;
  PrinterHealth? _health;
  bool _loadingUsb = true;
  bool _loadingBluetooth = false;
  bool _savingNetwork = false;
  bool _testing = false;
  bool _openingDrawer = false;
  String? _usbError;
  String? _bluetoothError;
  bool _autoPrintKotOnNewOrder = true;
  bool _clearHandoffOnScanPrint = true;

  final _networkHostController = TextEditingController();
  final _networkPortController =
      TextEditingController(text: '${NetworkPrinter.defaultPort}');
  final _networkNameController = TextEditingController();

  bool get _onNetwork => _tab == 1;
  bool get _onBluetooth => _tab == 2;
  bool get _onSmartPos => _tab == 3;
  bool get _loading =>
      _onBluetooth ? _loadingBluetooth : (_onNetwork || _onSmartPos ? false : _loadingUsb);

  @override
  void initState() {
    super.initState();
    _loadUsb();
    _loadScanSettings();
  }

  Future<void> _loadScanSettings() async {
    final autoKot = await AutoPrintKotSettings.enabled();
    final handoff = await ScanToPrintSettings.clearHandoffOnScanPrint();
    if (!mounted) return;
    setState(() {
      _autoPrintKotOnNewOrder = autoKot;
      _clearHandoffOnScanPrint = handoff;
    });
  }

  Future<void> _setAutoPrintKotOnNewOrder(bool value) async {
    setState(() => _autoPrintKotOnNewOrder = value);
    await AutoPrintKotSettings.setEnabled(value);
    if (!mounted) return;
    showPosSnackBar(
      context,
      value
          ? context.l10n.printerAutoPrintKotOnSnack
          : context.l10n.printerAutoPrintKotOffSnack,
    );
  }

  Future<void> _setClearHandoffOnScanPrint(bool value) async {
    setState(() => _clearHandoffOnScanPrint = value);
    await ScanToPrintSettings.setClearHandoffOnScanPrint(value);
    if (!mounted) return;
    showPosSnackBar(
      context,
      value
          ? 'Scan-to-print will clear the ready kitchen ticket (handoff)'
          : 'Scan-to-print will leave kitchen tickets on the board',
    );
  }

  @override
  void dispose() {
    PosReceiptPrinter.stopBluetoothScan();
    _networkHostController.dispose();
    _networkPortController.dispose();
    _networkNameController.dispose();
    super.dispose();
  }

  void _applySavedNetworkFields(UsbPrinterConfig? saved) {
    if (saved?.connection != PosPrinterConnection.network) return;
    _networkHostController.text = (saved!.host ?? '').trim();
    _networkPortController.text = '${saved.port}';
    _networkNameController.text = saved.name;
  }

  Future<void> _loadUsb() async {
    setState(() {
      _loadingUsb = true;
      _usbError = null;
    });

    try {
      final saved = await UsbPrinterStorage.load();
      final printers = await PosReceiptPrinter.listUsbPrinters();
      if (!mounted) return;
      _applySavedNetworkFields(saved);
      setState(() {
        _savedConfig = saved;
        _usbPrinters = printers;
        _loadingUsb = false;
        if (saved?.connection == PosPrinterConnection.network) {
          _tab = 1;
        } else if (saved?.connection == PosPrinterConnection.bluetooth) {
          _tab = 2;
        } else if (saved?.connection == PosPrinterConnection.smartpos) {
          _tab = 3;
        }
      });
      if (_tab == 2) {
        unawaited(_scanBluetooth());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usbError = e.toString();
        _loadingUsb = false;
      });
    }
  }

  Future<void> _scanBluetooth() async {
    setState(() {
      _loadingBluetooth = true;
      _bluetoothError = null;
    });

    try {
      final saved = await UsbPrinterStorage.load();
      final printers = await PosReceiptPrinter.listBluetoothPrinters();
      if (!mounted) return;
      setState(() {
        _savedConfig = saved;
        _bluetoothPrinters = printers;
        _loadingBluetooth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bluetoothError = e.toString();
        _loadingBluetooth = false;
      });
    }
  }

  Future<void> _refreshCurrent() async {
    if (_onBluetooth) {
      await _scanBluetooth();
    } else if (_onNetwork || _onSmartPos) {
      if (_savedConfig != null) {
        final health = await PosReceiptPrinter.probe();
        if (!mounted) return;
        setState(() => _health = health);
      }
    } else {
      await _loadUsb();
    }
  }

  void _switchTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    if (index == 2 &&
        !_loadingBluetooth &&
        _bluetoothPrinters.isEmpty &&
        _bluetoothError == null) {
      _scanBluetooth();
    }
  }

  Future<void> _selectBuiltInPrinter() async {
    final config = UsbPrinterConfig.smartpos();
    await UsbPrinterStorage.save(config);
    final health = await PosReceiptPrinter.probe();
    if (!mounted) return;
    setState(() {
      _savedConfig = config;
      _health = health;
    });
    await _showConnected(config, health);
  }

  Future<void> _showConnected(
    UsbPrinterConfig config,
    PrinterHealth health,
  ) async {
    final selected = context.l10n.printerSelectedSnack(
      config.connection.label,
      config.name,
    );
    if (health.state == PrinterHealthState.missing ||
        health.state == PrinterHealthState.none ||
        health.state == PrinterHealthState.unsupported) {
      showPosSnackBar(context, selected);
      return;
    }
    final sensor = await PosReceiptPrinter.readPaperSensor(config);
    if (!mounted) return;
    final note = switch (sensor) {
      PrinterPaperSensor.unknown =>
        'Your printer does not have the functionality to detect the roll.',
      PrinterPaperSensor.empty => 'Printer paper roll is finished.',
      PrinterPaperSensor.present => null,
    };
    showPosSnackBar(
      context,
      note == null ? selected : '$selected $note',
      error: sensor == PrinterPaperSensor.empty,
    );
  }

  Future<void> _saveNetworkPrinter() async {
    final l10n = context.l10n;
    final host = _networkHostController.text.trim();
    if (host.isEmpty) {
      showPosSnackBar(context, l10n.printerLanHostRequired, error: true);
      return;
    }
    final port = int.tryParse(_networkPortController.text.trim()) ??
        NetworkPrinter.defaultPort;
    if (port < 1 || port > 65535) {
      showPosSnackBar(context, l10n.printerLanPortInvalid, error: true);
      return;
    }

    setState(() => _savingNetwork = true);
    final config = UsbPrinterConfig.network(
      host: host,
      port: port,
      name: _networkNameController.text.trim().isEmpty
          ? null
          : _networkNameController.text.trim(),
    );
    await UsbPrinterStorage.save(config);
    final health = await PosReceiptPrinter.probe();
    if (!mounted) return;
    setState(() {
      _savedConfig = config;
      _health = health;
      _savingNetwork = false;
    });
    await _showConnected(config, health);
  }

  Future<void> _selectPrinter(UsbPrinterDevice printer) async {
    if (!printer.printable && printer.connection == PosPrinterConnection.usb) {
      showPosSnackBar(
        context,
        thermalPrinterNeedsSystemQueueMessage(),
        error: true,
      );
      return;
    }

    final config = UsbPrinterConfig(
      name: printer.name,
      address: printer.address,
      connection: printer.connection,
      source: printer.source,
    );

    await UsbPrinterStorage.save(config);

    setState(() {
      _savedConfig = config;
    });

    PrinterHealth? health;
    if (printer.connection == PosPrinterConnection.bluetooth) {
      try {
        health = await PosReceiptPrinter.probe(allowBluetoothScan: true);
        await PosReceiptPrinter.warmUp();
        if (mounted) setState(() => _health = health);
      } catch (e) {
        if (mounted) {
          showPosSnackBar(
            context,
            thermalPrinterConnectError(printer.name, bluetooth: true),
            error: true,
          );
        }
        return;
      }
    } else {
      health = await PosReceiptPrinter.probe();
      if (mounted) setState(() => _health = health);
    }

    if (mounted) {
      await _showConnected(config, health);
    }
  }

  Future<void> _testPrint() async {
    if (_testing || _savedConfig == null) return;

    final pos = context.read<PosController>();
    final bootstrap = pos.bootstrap;
    final terminal = pos.selectedTerminal;

    setState(() => _testing = true);
    final result = await PosReceiptPrinter.printTestPage(
      restaurantName: bootstrap?.restaurant.name,
      branchName: bootstrap?.branch.name,
      terminalName: terminal?.name ?? pos.selectedTerminalCode,
    );
    if (!mounted) return;
    setState(() {
      _health = result;
      _testing = false;
    });

    final l10n = context.l10n;
    if (!result.hasIssue) {
      showPosSnackBar(context, l10n.printerTestSent);
      return;
    }

    showPosSnackBar(
      context,
      result.message?.trim().isNotEmpty == true
          ? result.message!
          : l10n.printerTestFailed,
      error: true,
    );
  }

  Future<void> _openDrawer() async {
    if (_openingDrawer || _savedConfig == null) return;
    setState(() => _openingDrawer = true);
    try {
      await PosReceiptPrinter.openCashDrawer();
      if (!mounted) return;
      showPosSnackBar(context, 'Cash drawer kicked');
    } catch (e) {
      if (!mounted) return;
      showPosSnackBar(
        context,
        e.toString().replaceFirst('Bad state: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _openingDrawer = false);
    }
  }

  Future<void> _clearPrinter() async {
    await UsbPrinterStorage.save(null);
    setState(() {
      _savedConfig = null;
    });
  }

  bool _isSelected(UsbPrinterDevice printer) {
    final saved = _savedConfig;
    if (saved == null) return false;
    if (saved.connection != printer.connection) return false;
    if (saved.name != printer.name) return false;
    if (saved.address.isEmpty || printer.address.isEmpty) return true;
    return saved.address.toLowerCase() == printer.address.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? IconButton(
                tooltip: l10n.commonClose,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          widget.embedded ? 'Receipt printer' : l10n.printerSetupTitle,
        ),
        actions: [
          TextButton.icon(
            onPressed: _loading || _testing || _savingNetwork
                ? null
                : _refreshCurrent,
            icon: Icon(
              _onBluetooth
                  ? Icons.bluetooth_searching_rounded
                  : Icons.refresh_rounded,
              size: 18,
            ),
            label: Text(
              _onBluetooth ? l10n.printerScan : l10n.commonRefresh,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 720 : double.infinity),
          child: Column(
            children: [
              if (!PosReceiptPrinter.isSupported)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _SetupHero(accent: accent, soft: soft, compact: true),
                )
              else if (!widget.embedded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _SetupHero(accent: accent, soft: soft),
                ),
              if (_savedConfig != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _SelectedPrinterCard(
                    config: _savedConfig!,
                    accent: accent,
                    soft: soft,
                    health: _health,
                    testing: _testing,
                    openingDrawer: _openingDrawer,
                    onTestPrint: _testPrint,
                    onOpenDrawer: _openDrawer,
                    onClear: _clearPrinter,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ConnectionSwitcher(
                  index: _tab,
                  accent: accent,
                  showBluetooth: true,
                  onChanged: _switchTab,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pane = _onNetwork
                          ? _NetworkPrinterForm(
                              accent: accent,
                              soft: soft,
                              hostController: _networkHostController,
                              portController: _networkPortController,
                              nameController: _networkNameController,
                              saving: _savingNetwork,
                              onSave: _saveNetworkPrinter,
                            )
                          : _onSmartPos
                              ? _BuiltInPrinterCard(
                                  accent: accent,
                                  soft: soft,
                                  selected: _savedConfig?.connection ==
                                      PosPrinterConnection.smartpos,
                                  onSelect: _selectBuiltInPrinter,
                                )
                              : _PrinterListBody(
                                  accent: accent,
                                  loading: _loading,
                                  error: _onBluetooth
                                      ? _bluetoothError
                                      : _usbError,
                                  printers: _onBluetooth
                                      ? _bluetoothPrinters
                                      : _usbPrinters,
                                  bluetooth: _onBluetooth,
                                  isSelected: _isSelected,
                                  onRetry: _refreshCurrent,
                                  onSelect: _selectPrinter,
                                );
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: pane,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    _ScanToPrintOptionsCard(
                      accent: accent,
                      soft: soft,
                    ),
                    const SizedBox(height: 8),
                    _AutoPrintKotOptionsCard(
                      accent: accent,
                      soft: soft,
                      enabled: _autoPrintKotOnNewOrder,
                      onChanged: _setAutoPrintKotOnNewOrder,
                    ),
                    const SizedBox(height: 8),
                    _AutoPrintKotOptionsCard(
                      accent: accent,
                      soft: soft,
                      enabled: _clearHandoffOnScanPrint,
                      onChanged: _setClearHandoffOnScanPrint,
                      title: 'Clear kitchen ticket on scan-to-print',
                      help:
                          'When a guest scans their PWA QR at this register, print the receipt and mark the ready KDS ticket delivered (handoff).',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              if (_onBluetooth)
                _BottomScanBar(
                  accent: accent,
                  loading: _loadingBluetooth,
                  onScan: _scanBluetooth,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupHero extends StatelessWidget {
  const _SetupHero({
    required this.accent,
    required this.soft,
    this.compact = false,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        gradient: PosTheme.softCanvasGradient(accent),
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: soft.bg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PosTheme.cardShadow(accent),
            ),
            child: Icon(Icons.print_rounded, color: soft.fg, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.printerReceiptTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: PosTheme.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  thermalPrinterSetupHelp(),
                  style: TextStyle(
                    color: PosTheme.inkMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanToPrintOptionsCard extends StatelessWidget {
  const _ScanToPrintOptionsCard({
    required this.accent,
    required this.soft,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
        boxShadow: PosTheme.cardShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: soft.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 20,
              color: soft.fg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.printerScanToPrint,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: PosTheme.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.printerScanAutoHelp,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: PosTheme.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoPrintKotOptionsCard extends StatelessWidget {
  const _AutoPrintKotOptionsCard({
    required this.accent,
    required this.soft,
    required this.enabled,
    required this.onChanged,
    this.title,
    this.help,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String? title;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
        boxShadow: PosTheme.cardShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: soft.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: soft.fg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? l10n.printerAutoPrintKot,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: PosTheme.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  help ?? l10n.printerAutoPrintKotHelp,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: PosTheme.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeThumbColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SelectedPrinterCard extends StatelessWidget {
  const _SelectedPrinterCard({
    required this.config,
    required this.accent,
    required this.soft,
    required this.testing,
    required this.openingDrawer,
    required this.onTestPrint,
    required this.onOpenDrawer,
    required this.onClear,
    this.health,
  });

  final UsbPrinterConfig config;
  final Color accent;
  final ({Color bg, Color fg}) soft;
  final PrinterHealth? health;
  final bool testing;
  final bool openingDrawer;
  final VoidCallback onTestPrint;
  final VoidCallback onOpenDrawer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final connected = health?.state == PrinterHealthState.ready;
    final icon = switch (config.connection) {
      PosPrinterConnection.bluetooth => Icons.bluetooth_connected_rounded,
      PosPrinterConnection.network => Icons.lan_rounded,
      PosPrinterConnection.smartpos => Icons.print_rounded,
      PosPrinterConnection.usb => Icons.usb_rounded,
    };
    final tone = posStatusColors(connected ? 'ready' : 'failed');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: soft.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: soft.fg, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    config.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: PosTheme.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tone.bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: tone.fg.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    connected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: tone.fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: testing || openingDrawer ? null : onTestPrint,
            child: testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.printerTestPrint),
          ),
          IconButton(
            tooltip: context.l10n.commonClear,
            onPressed: testing || openingDrawer ? null : onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ConnectionSwitcher extends StatelessWidget {
  const _ConnectionSwitcher({
    required this.index,
    required this.accent,
    required this.showBluetooth,
    required this.onChanged,
  });

  final int index;
  final Color accent;
  final bool showBluetooth;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final chips = [
            _SwitchChip(
              selected: index == 0,
              icon: Icons.usb_rounded,
              label: l10n.printerTabUsb,
              accent: accent,
              compact: compact,
              onTap: () => onChanged(0),
            ),
            _SwitchChip(
              selected: index == 1,
              icon: Icons.lan_rounded,
              label: l10n.printerTabLan,
              accent: accent,
              compact: compact,
              onTap: () => onChanged(1),
            ),
            _SwitchChip(
              selected: index == 2,
              icon: Icons.bluetooth_rounded,
              label: l10n.printerTabBluetooth,
              accent: accent,
              compact: compact,
              onTap: () => onChanged(2),
            ),
            _SwitchChip(
              selected: index == 3,
              icon: Icons.print_rounded,
              label: 'Built-in',
              accent: accent,
              compact: compact,
              onTap: () => onChanged(3),
            ),
          ];
          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: chips[0]),
                    Expanded(child: chips[1]),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: chips[2]),
                    Expanded(child: chips[3]),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              for (final chip in chips) Expanded(child: chip),
            ],
          );
        },
      ),
    );
  }
}

class _BuiltInPrinterCard extends StatelessWidget {
  const _BuiltInPrinterCard({
    required this.accent,
    required this.soft,
    required this.selected,
    required this.onSelect,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(
          color: selected ? accent : PosTheme.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: PosTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.print_rounded, color: soft.fg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Built-in printer',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TVS / SmartPOS built-in printer (inner mechanism). This is not USB or LAN — select this on the terminal, then Test print.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: PosTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: selected ? null : onSelect,
            icon: Icon(
              selected ? Icons.check_rounded : Icons.print_rounded,
              size: 18,
            ),
            label: Text(selected ? 'Built-in printer selected' : 'Use built-in printer'),
          ),
        ],
      ),
    );
  }
}

class _NetworkPrinterForm extends StatelessWidget {
  const _NetworkPrinterForm({
    required this.accent,
    required this.soft,
    required this.hostController,
    required this.portController,
    required this.nameController,
    required this.saving,
    required this.onSave,
  });

  final Color accent;
  final ({Color bg, Color fg}) soft;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController nameController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
        boxShadow: PosTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: soft.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.lan_rounded, color: soft.fg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.printerLanTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.printerLanHint,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: PosTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: hostController,
            enabled: !saving,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.printerLanHost,
              hintText: '192.168.1.50',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: portController,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.printerLanPort,
                    hintText: '${NetworkPrinter.defaultPort}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: nameController,
                  enabled: !saving,
                  decoration: InputDecoration(
                    labelText: l10n.printerLanNameOptional,
                    hintText: l10n.printerLanNameHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              saving ? l10n.commonSave : l10n.printerLanSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchChip extends StatelessWidget {
  const _SwitchChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PosTheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected ? PosTheme.cardShadow() : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? accent : PosTheme.inkMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 13,
                    color: selected ? PosTheme.ink : PosTheme.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: PosTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: PosTheme.inkMuted,
                ),
              ),
            ],
          ),
        ),
        if (count > 0)
          Text(
            context.l10n.printerCountFound(count),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PosTheme.inkMuted,
            ),
          ),
      ],
    );
  }
}

class _BottomScanBar extends StatelessWidget {
  const _BottomScanBar({
    required this.accent,
    required this.loading,
    required this.onScan,
  });

  final Color accent;
  final bool loading;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(top: BorderSide(color: PosTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: PosPrimaryButton(
          label: loading ? l10n.printerScanning : l10n.printerScanBluetooth,
          icon: Icons.bluetooth_searching_rounded,
          loading: loading,
          color: accent,
          onPressed: loading ? null : onScan,
        ),
      ),
    );
  }
}

class _PrinterListBody extends StatelessWidget {
  const _PrinterListBody({
    required this.accent,
    required this.loading,
    required this.error,
    required this.printers,
    required this.bluetooth,
    required this.isSelected,
    required this.onRetry,
    required this.onSelect,
  });

  final Color accent;
  final bool loading;
  final String? error;
  final List<UsbPrinterDevice> printers;
  final bool bluetooth;
  final bool Function(UsbPrinterDevice printer) isSelected;
  final VoidCallback onRetry;
  final ValueChanged<UsbPrinterDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(PosTheme.radiusLg),
          border: Border.all(color: PosTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              bluetooth ? l10n.printerScanning : l10n.printerLooking,
              style: TextStyle(
                color: PosTheme.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return _InlineEmpty(
        icon: Icons.error_outline_rounded,
        title: l10n.printerLoadFailed,
        subtitle: error!,
        actionLabel: l10n.commonRetry,
        actionIcon: Icons.refresh_rounded,
        accent: accent,
        onAction: onRetry,
      );
    }

    if (printers.isEmpty) {
      return _InlineEmpty(
        icon: bluetooth
            ? Icons.bluetooth_disabled_rounded
            : Icons.print_disabled_rounded,
        title: bluetooth ? l10n.printerNoBluetooth : l10n.printerNoneFound,
        subtitle: thermalPrinterEmptyMessage(bluetooth: bluetooth),
        actionLabel: bluetooth ? l10n.printerScanAgain : l10n.commonRefresh,
        actionIcon: bluetooth
            ? Icons.bluetooth_searching_rounded
            : Icons.refresh_rounded,
        accent: accent,
        onAction: onRetry,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: printers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _PrinterTile(
        printer: printers[i],
        selected: isSelected(printers[i]),
        accent: accent,
        onTap: () => onSelect(printers[i]),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.accent,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final Color accent;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: soft.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: soft.fg, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: PosTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PosTheme.inkMuted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          PosPrimaryButton(
            label: actionLabel,
            icon: actionIcon,
            color: accent,
            expanded: false,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _PrinterTile extends StatelessWidget {
  const _PrinterTile({
    required this.printer,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final UsbPrinterDevice printer;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    final isBt = printer.connection == PosPrinterConnection.bluetooth;

    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(PosTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusLg),
            border: Border.all(
              color: selected ? accent : PosTheme.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? PosTheme.cardShadow(accent)
                : PosTheme.cardShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? soft.bg : PosTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isBt ? Icons.bluetooth_rounded : Icons.print_rounded,
                  color: selected ? soft.fg : PosTheme.inkMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      printer.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      printer.address.isNotEmpty
                          ? '${printer.connection.label} · ${printer.address}'
                          : printer.connection.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: PosTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: soft.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.l10n.printerSelected,
                    style: TextStyle(
                      color: soft.fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: PosTheme.inkFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
