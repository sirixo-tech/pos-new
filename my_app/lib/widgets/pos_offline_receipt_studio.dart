import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pos_register_preferences.dart';
import '../theme/pos_theme.dart';

enum _SlipKind { customer, kitchen }

/// Customer bill and kitchen ticket for orders saved on this register.
/// Online slips do not read this screen.
class PosOfflineReceiptStudio extends StatefulWidget {
  const PosOfflineReceiptStudio({super.key, this.initialKitchen = false});

  final bool initialKitchen;

  @override
  State<PosOfflineReceiptStudio> createState() =>
      _PosOfflineReceiptStudioState();
}

class _PosOfflineReceiptStudioState extends State<PosOfflineReceiptStudio> {
  final _preview = _PreviewTick();
  late final TextEditingController _header;
  late final TextEditingController _footer;
  late final TextEditingController _billLabel;
  late final TextEditingController _dateLabel;
  late final TextEditingController _tokenLabel;
  late final TextEditingController _taxIdLabel;
  late final TextEditingController _trackPrompt;
  late final TextEditingController _kotTitle;
  late final TextEditingController _kotToken;
  late final TextEditingController _kotDate;
  late final TextEditingController _kotItemHeader;
  late String _fontSize;
  late String _paper;
  late bool _logo;
  late bool _restaurant;
  late bool _branch;
  late bool _address;
  late bool _taxId;
  late bool _token;
  late bool _datetime;
  late bool _table;
  late bool _orderType;
  late bool _customer;
  late bool _notes;
  late bool _itemHeaders;
  late bool _modifiers;
  late bool _subtotal;
  late bool _tax;
  late bool _total;
  late bool _payment;
  late bool _tracking;
  late String _kotFont;
  late String _kotPaper;
  bool _kotShowTitle = true;
  late bool _kotShowToken;
  late bool _kotShowType;
  late bool _kotShowTable;
  late bool _kotShowCustomer;
  late bool _kotShowDate;
  late bool _kotShowItemHeader;
  late bool _kotShowModifiers;
  late bool _kotShowLineNotes;
  late bool _kotShowOrderNotes;
  late _SlipKind _tab;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PosRegisterPreferences>();
    final receipt = prefs.offlineFormat ?? OfflineReceiptFormat.codeDefault;
    final kot = prefs.offlineKotFormat ?? OfflineKotFormat.codeDefault;
    _header = TextEditingController(text: receipt.headerLine);
    _footer = TextEditingController(text: receipt.footerLine);
    _billLabel = TextEditingController(text: receipt.billLabel);
    _dateLabel = TextEditingController(text: receipt.dateLabel);
    _tokenLabel = TextEditingController(text: receipt.tokenLabel);
    _taxIdLabel = TextEditingController(text: receipt.taxIdLabel);
    _trackPrompt = TextEditingController(text: receipt.trackPrompt);
    _kotTitle = TextEditingController(text: kot.title);
    _kotToken = TextEditingController(text: kot.tokenLabel);
    _kotDate = TextEditingController(text: kot.dateLabel);
    _kotItemHeader = TextEditingController(text: kot.itemHeader);
    _copyReceipt(receipt);
    _copyKot(kot);
    _tab = widget.initialKitchen ? _SlipKind.kitchen : _SlipKind.customer;
    for (final controller in _fields) {
      controller.addListener(_preview.bump);
    }
  }

  List<TextEditingController> get _fields => [
    _header,
    _footer,
    _billLabel,
    _dateLabel,
    _tokenLabel,
    _taxIdLabel,
    _trackPrompt,
    _kotTitle,
    _kotToken,
    _kotDate,
    _kotItemHeader,
  ];

  void _copyReceipt(OfflineReceiptFormat format) {
    _fontSize = switch (format.fontSize) {
      'small' || 'large' => format.fontSize,
      _ => 'medium',
    };
    _paper = format.paper == '58mm' ? '58mm' : '80mm';
    _logo = format.showLogo;
    _restaurant = format.showRestaurantName;
    _branch = format.showBranch;
    _address = format.showAddress;
    _taxId = format.showTaxId;
    _token = format.showToken;
    _datetime = format.showDatetime;
    _table = format.showTable;
    _orderType = format.showOrderType;
    _customer = format.showCustomer;
    _notes = format.showNotes;
    _itemHeaders = format.showItemHeaders;
    _modifiers = format.showModifiers;
    _subtotal = format.showSubtotal;
    _tax = format.showTax;
    _total = format.showTotal;
    _payment = format.showPayment;
    _tracking = format.showTracking;
  }

  void _copyKot(OfflineKotFormat format) {
    _kotFont = switch (format.fontSize) {
      'small' || 'large' => format.fontSize,
      _ => 'medium',
    };
    _kotPaper = format.paper == '58mm' ? '58mm' : '80mm';
    _kotShowTitle = format.showTitle;
    _kotShowToken = format.showToken;
    _kotShowType = format.showOrderType;
    _kotShowTable = format.showTable;
    _kotShowCustomer = format.showCustomer;
    _kotShowDate = format.showDate;
    _kotShowItemHeader = format.showItemHeader;
    _kotShowModifiers = format.showModifiers;
    _kotShowLineNotes = format.showLineNotes;
    _kotShowOrderNotes = format.showOrderNotes;
  }

  void _writeReceipt(OfflineReceiptFormat format) {
    _header.text = format.headerLine;
    _footer.text = format.footerLine;
    _billLabel.text = format.billLabel;
    _dateLabel.text = format.dateLabel;
    _tokenLabel.text = format.tokenLabel;
    _taxIdLabel.text = format.taxIdLabel;
    _trackPrompt.text = format.trackPrompt;
    setState(() => _copyReceipt(format));
  }

  void _writeKot(OfflineKotFormat format) {
    _kotTitle.text = format.title;
    _kotToken.text = format.tokenLabel;
    _kotDate.text = format.dateLabel;
    _kotItemHeader.text = format.itemHeader;
    setState(() => _copyKot(format));
  }

  @override
  void dispose() {
    for (final controller in _fields) {
      controller.removeListener(_preview.bump);
      controller.dispose();
    }
    _preview.dispose();
    super.dispose();
  }

  OfflineReceiptFormat _receiptFormat() {
    return OfflineReceiptFormat(
      headerLine: _header.text,
      footerLine: _footer.text,
      fontSize: _fontSize,
      paper: _paper,
      showLogo: _logo,
      showRestaurantName: _restaurant,
      showBranch: _branch,
      showAddress: _address,
      showTaxId: _taxId,
      showToken: _token,
      showDatetime: _datetime,
      showTable: _table,
      showOrderType: _orderType,
      showCustomer: _customer,
      showNotes: _notes,
      showItemHeaders: _itemHeaders,
      showModifiers: _modifiers,
      showSubtotal: _subtotal,
      showTax: _tax,
      showTotal: _total,
      showPayment: _payment,
      showTracking: _tracking,
      billLabel: _billLabel.text,
      dateLabel: _dateLabel.text,
      tokenLabel: _tokenLabel.text,
      taxIdLabel: _taxIdLabel.text,
      trackPrompt: _trackPrompt.text,
    );
  }

  OfflineKotFormat _kotFormat() {
    return OfflineKotFormat(
      title: _kotTitle.text,
      tokenLabel: _kotToken.text,
      dateLabel: _kotDate.text,
      itemHeader: _kotItemHeader.text,
      fontSize: _kotFont,
      paper: _kotPaper,
      showTitle: _kotShowTitle,
      showToken: _kotShowToken,
      showOrderType: _kotShowType,
      showTable: _kotShowTable,
      showCustomer: _kotShowCustomer,
      showDate: _kotShowDate,
      showItemHeader: _kotShowItemHeader,
      showModifiers: _kotShowModifiers,
      showLineNotes: _kotShowLineNotes,
      showOrderNotes: _kotShowOrderNotes,
    );
  }

  void _toggle(VoidCallback assign) {
    setState(assign);
    _preview.bump();
  }

  bool get _kitchen => _tab == _SlipKind.kitchen;

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final prefs = context.watch<PosRegisterPreferences>();
    final usingLocal = _kitchen
        ? prefs.hasOfflineKotFormat
        : prefs.hasOfflineFormat;
    final preview = ListenableBuilder(
      listenable: _preview,
      builder: (context, _) {
        final slip = _kitchen
            ? _KotPreview(format: _kotFormat())
            : _ReceiptPreview(format: _receiptFormat());
        return slip;
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(PosTheme.radiusLg),
      child: Material(
        color: PosTheme.canvas,
        child: Column(
          children: [
            _StudioHeader(
              kitchen: _kitchen,
              onCustomer: () => setState(() => _tab = _SlipKind.customer),
              onKitchen: () => setState(() => _tab = _SlipKind.kitchen),
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 340, child: preview),
                        Expanded(child: _editor()),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 240, child: preview),
                        Expanded(child: _editor()),
                      ],
                    ),
            ),
            _StudioFooter(
              kitchen: _kitchen,
              usingLocal: usingLocal,
              onRestore: () {
                if (_kitchen) {
                  _writeKot(OfflineKotFormat.codeDefault);
                } else {
                  _writeReceipt(OfflineReceiptFormat.codeDefault);
                }
              },
              onUseBuiltIn: usingLocal
                  ? () async {
                      final prefs = context.read<PosRegisterPreferences>();
                      if (_kitchen) {
                        await prefs.clearOfflineKotFormat();
                        if (mounted) _writeKot(OfflineKotFormat.codeDefault);
                      } else {
                        await prefs.clearOfflineFormat();
                        if (mounted) {
                          _writeReceipt(OfflineReceiptFormat.codeDefault);
                        }
                      }
                    }
                  : null,
              onSave: () async {
                final prefs = context.read<PosRegisterPreferences>();
                if (_kitchen) {
                  await prefs.saveOfflineKotFormat(_kotFormat());
                } else {
                  await prefs.saveOfflineFormat(_receiptFormat());
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor() {
    return ListView(
      key: ValueKey(_tab),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: _kitchen ? _kitchenFields() : _customerFields(),
    );
  }

  List<Widget> _customerFields() {
    return [
      const _SectionTitle(
        title: 'Paper',
        caption: 'Applies only to the customer bill printed from offline orders.',
      ),
      const SizedBox(height: 10),
      _ChoiceRow(
        label: 'Font size',
        value: _fontSize,
        options: const [
          ('small', 'Small'),
          ('medium', 'Medium'),
          ('large', 'Large'),
        ],
        onChanged: (value) => _toggle(() => _fontSize = value),
      ),
      const SizedBox(height: 8),
      _ChoiceRow(
        label: 'Width',
        value: _paper,
        options: const [
          ('58mm', '58 mm'),
          ('80mm', '80 mm'),
        ],
        onChanged: (value) => _toggle(() => _paper = value),
      ),
      const SizedBox(height: 22),
      const _SectionTitle(
        title: 'Header',
        caption: 'Top of the bill, in the same order the printer uses.',
      ),
      _lineSwitch('Logo', _logo, (v) => _logo = v),
      _lineSwitch('Restaurant name', _restaurant, (v) => _restaurant = v),
      _lineSwitch('Branch', _branch, (v) => _branch = v),
      _lineSwitch('Address', _address, (v) => _address = v),
      _labeledLine(
        title: 'Tax ID',
        on: _taxId,
        onChanged: (v) => _taxId = v,
        controller: _taxIdLabel,
        hint: 'Tax ID: ',
      ),
      _textLine(
        title: 'Header line',
        controller: _header,
        hint: 'Optional line under the restaurant',
      ),
      _labeledLine(
        title: 'Token',
        on: _token,
        onChanged: (v) => _token = v,
        controller: _tokenLabel,
        hint: 'TOKEN #',
      ),
      const SizedBox(height: 18),
      const _SectionTitle(
        title: 'Order',
        caption: 'Filled from the saved order when the slip prints.',
      ),
      _labeledLine(
        title: 'Bill number',
        on: true,
        locked: true,
        controller: _billLabel,
        hint: 'Bill No: ',
      ),
      _lineSwitch('Order type', _orderType, (v) => _orderType = v),
      _labeledLine(
        title: 'Date and time',
        on: _datetime,
        onChanged: (v) => _datetime = v,
        controller: _dateLabel,
        hint: 'Date: ',
      ),
      _lineSwitch('Table', _table, (v) => _table = v),
      _lineSwitch('Customer', _customer, (v) => _customer = v),
      _lineSwitch('Notes', _notes, (v) => _notes = v),
      const SizedBox(height: 18),
      const _SectionTitle(title: 'Items and totals'),
      _lineSwitch('Item column headers', _itemHeaders, (v) => _itemHeaders = v),
      _lineSwitch('Modifiers', _modifiers, (v) => _modifiers = v),
      _lineSwitch('Subtotal', _subtotal, (v) => _subtotal = v),
      _lineSwitch('Tax', _tax, (v) => _tax = v),
      _lineSwitch('Total', _total, (v) => _total = v),
      _lineSwitch('Payment', _payment, (v) => _payment = v),
      const SizedBox(height: 18),
      const _SectionTitle(title: 'Footer'),
      _labeledLine(
        title: 'Tracking line',
        on: _tracking,
        onChanged: (v) => _tracking = v,
        controller: _trackPrompt,
        hint: 'Scan here to track order',
      ),
      _textLine(
        title: 'Footer text',
        controller: _footer,
        hint: 'Thank you for your order!',
      ),
    ];
  }

  List<Widget> _kitchenFields() {
    return [
      const _SectionTitle(
        title: 'Paper',
        caption: 'Applies only to the kitchen ticket printed from offline orders.',
      ),
      const SizedBox(height: 10),
      _ChoiceRow(
        label: 'Font size',
        value: _kotFont,
        options: const [
          ('small', 'Small'),
          ('medium', 'Medium'),
          ('large', 'Large'),
        ],
        onChanged: (value) => _toggle(() => _kotFont = value),
      ),
      const SizedBox(height: 8),
      _ChoiceRow(
        label: 'Width',
        value: _kotPaper,
        options: const [
          ('58mm', '58 mm'),
          ('80mm', '80 mm'),
        ],
        onChanged: (value) => _toggle(() => _kotPaper = value),
      ),
      const SizedBox(height: 22),
      const _SectionTitle(
        title: 'Ticket',
        caption: 'Same lines the offline kitchen ticket already prints. No prices.',
      ),
      _labeledLine(
        title: 'Title',
        on: _kotShowTitle,
        onChanged: (value) => _kotShowTitle = value,
        controller: _kotTitle,
        hint: 'KITCHEN ORDER',
        fieldKey: const Key('kot-title'),
      ),
      _labeledLine(
        title: 'Token',
        on: _kotShowToken,
        onChanged: (v) => _kotShowToken = v,
        controller: _kotToken,
        hint: 'TOKEN #',
      ),
      _lineSwitch('Order type', _kotShowType, (v) => _kotShowType = v),
      _lineSwitch('Table', _kotShowTable, (v) => _kotShowTable = v),
      _lineSwitch('Customer', _kotShowCustomer, (v) => _kotShowCustomer = v),
      _labeledLine(
        title: 'Date',
        on: _kotShowDate,
        onChanged: (v) => _kotShowDate = v,
        controller: _kotDate,
        hint: 'Date: ',
      ),
      _labeledLine(
        title: 'Item heading',
        on: _kotShowItemHeader,
        onChanged: (v) => _kotShowItemHeader = v,
        controller: _kotItemHeader,
        hint: 'Item',
      ),
      _lineSwitch('Modifiers', _kotShowModifiers, (v) => _kotShowModifiers = v),
      _lineSwitch('Item notes', _kotShowLineNotes, (v) => _kotShowLineNotes = v),
      _lineSwitch('Order notes', _kotShowOrderNotes, (v) => _kotShowOrderNotes = v),
    ];
  }

  Widget _lineSwitch(String title, bool value, ValueChanged<bool> assign) {
    return _LineCard(
      title: title,
      value: value,
      onChanged: (next) => _toggle(() => assign(next)),
    );
  }

  Widget _textLine({
    required String title,
    required TextEditingController controller,
    required String hint,
    Key? fieldKey,
  }) {
    return _LineCard(
      title: title,
      value: true,
      locked: true,
      child: _LineField(fieldKey: fieldKey, controller: controller, hint: hint),
    );
  }

  Widget _labeledLine({
    required String title,
    required bool on,
    required TextEditingController controller,
    required String hint,
    ValueChanged<bool>? onChanged,
    bool locked = false,
    Key? fieldKey,
  }) {
    return _LineCard(
      title: title,
      value: on,
      locked: locked,
      onChanged: onChanged == null
          ? null
          : (next) => _toggle(() => onChanged(next)),
      child: _LineField(
        controller: controller,
        hint: hint,
        enabled: on,
        fieldKey: fieldKey,
      ),
    );
  }
}

class _PreviewTick extends ChangeNotifier {
  void bump() => notifyListeners();
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({
    required this.kitchen,
    required this.onCustomer,
    required this.onKitchen,
    required this.onClose,
  });

  final bool kitchen;
  final VoidCallback onCustomer;
  final VoidCallback onKitchen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(bottom: BorderSide(color: PosTheme.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PosTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: PosTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline receipts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer bill and kitchen ticket for orders saved on this register. Online slips stay on the server format.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: PosTheme.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: PosTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _TabButton(
                  label: 'Customer bill',
                  selected: !kitchen,
                  onTap: onCustomer,
                ),
                _TabButton(
                  label: 'Kitchen ticket',
                  selected: kitchen,
                  onTap: onKitchen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? PosTheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: selected ? PosTheme.ink : PosTheme.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioFooter extends StatelessWidget {
  const _StudioFooter({
    required this.kitchen,
    required this.usingLocal,
    required this.onRestore,
    required this.onUseBuiltIn,
    required this.onSave,
  });

  final bool kitchen;
  final bool usingLocal;
  final VoidCallback onRestore;
  final VoidCallback? onUseBuiltIn;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final noun = kitchen ? 'kitchen ticket' : 'customer bill';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        border: Border(top: BorderSide(color: PosTheme.border)),
      ),
      child: Row(
        children: [
          TextButton(onPressed: onRestore, child: const Text('Reset to code')),
          TextButton(
            onPressed: onUseBuiltIn,
            child: Text(usingLocal ? 'Use built-in slip' : 'Built-in slip'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: PosTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            child: Text('Save $noun'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: PosTheme.inkMuted,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: TextStyle(fontSize: 12.5, color: PosTheme.inkFaint),
          ),
        ],
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: PosTheme.ink),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: PosTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final option in options)
                  Expanded(
                    child: _ChoiceChip(
                      label: option.$2,
                      selected: value == option.$1,
                      onTap: () => onChanged(option.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PosTheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? PosTheme.ink : PosTheme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.title,
    required this.value,
    this.onChanged,
    this.child,
    this.locked = false,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? child;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: value ? PosTheme.ink : PosTheme.inkFaint,
                  ),
                ),
                if (child != null) ...[const SizedBox(height: 6), child!],
              ],
            ),
          ),
          if (!locked)
            Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: PosTheme.accent,
              onChanged: onChanged,
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: PosTheme.inkFaint,
              ),
            ),
        ],
      ),
    );
  }
}

class _LineField extends StatelessWidget {
  const _LineField({
    required this.controller,
    required this.hint,
    this.enabled = true,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: PosTheme.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.format});

  final OfflineReceiptFormat format;

  @override
  Widget build(BuildContext context) {
    final size = switch (format.fontSize) {
      'small' => 11.0,
      'large' => 16.0,
      _ => 13.0,
    };
    final lines = <_PreviewLine>[
      const _PreviewLine('OFFLINE ORDER', bold: true, center: true),
      if (format.showLogo) const _PreviewLine('LOGO', center: true, muted: true),
      if (format.showRestaurantName)
        const _PreviewLine(
          'Coffee Cafe',
          bold: true,
          center: true,
          large: true,
        ),
      if (format.showBranch) const _PreviewLine('BANGALORE', center: true),
      if (format.showAddress)
        const _PreviewLine('12 MG Road', center: true, muted: true),
      if (format.showTaxId)
        _PreviewLine(
          '${_kept(format.taxIdLabel, 'Tax ID: ')}29ABCDE1234F1Z5',
          center: true,
        ),
      if (format.headerLine.trim().isNotEmpty)
        _PreviewLine(format.headerLine.trim(), center: true),
      if (format.showToken)
        _PreviewLine(
          '${_kept(format.tokenLabel, 'TOKEN #')}12',
          bold: true,
          center: true,
          large: true,
        ),
      _PreviewLine('${_kept(format.billLabel, 'Bill No: ')}—', bold: true),
      if (format.showOrderType) const _PreviewLine('Dine in', bold: true),
      if (format.showDatetime)
        _PreviewLine(
          '${_kept(format.dateLabel, 'Date: ')}01 Nov 2026  7:40 PM',
        ),
      if (format.showTable) const _PreviewLine('Table: 4'),
      if (format.showCustomer) const _PreviewLine('Customer: Asha'),
      if (format.showNotes) const _PreviewLine('Note: Less spicy'),
      if (format.showItemHeaders)
        const _PreviewLine('Item                    Amount', bold: true),
      const _PreviewLine('1x Filter coffee           80.00'),
      if (format.showModifiers)
        const _PreviewLine('   + Extra shot', muted: true),
      const _PreviewLine('2x Masala dosa            180.00'),
      if (format.showSubtotal)
        const _PreviewLine('Subtotal                 260.00'),
      if (format.showTax) const _PreviewLine('Tax                       13.00'),
      if (format.showTotal)
        const _PreviewLine('Total                    273.00', bold: true),
      if (format.showPayment)
        const _PreviewLine('PAID · Cash', center: true, bold: true),
      if (format.showTracking)
        _PreviewLine(
          format.trackPrompt.trim().isEmpty
              ? 'Scan here to track order'
              : format.trackPrompt.trim(),
          center: true,
          bold: true,
        ),
      _PreviewLine(
        format.footerLine.trim().isEmpty
            ? 'Thank you for your order!'
            : format.footerLine.trim(),
        center: true,
      ),
    ];
    return _Paper(
      key: const Key('slip-preview'),
      caption: 'Customer bill',
      paper: format.paper,
      size: size,
      lines: lines,
    );
  }
}

class _KotPreview extends StatelessWidget {
  const _KotPreview({required this.format});

  final OfflineKotFormat format;

  @override
  Widget build(BuildContext context) {
    final size = switch (format.fontSize) {
      'small' => 11.0,
      'large' => 16.0,
      _ => 13.0,
    };
    final title = format.title.trim();
    final lines = <_PreviewLine>[
      if (format.showTitle && title.isNotEmpty)
        _PreviewLine(title, bold: true, center: true, large: true),
      if (format.showToken)
        _PreviewLine(
          '${_kept(format.tokenLabel, 'TOKEN #')}12',
          bold: true,
          center: true,
        ),
      if (format.showOrderType)
        const _PreviewLine('Dine in', bold: true, center: true),
      if (format.showTable) const _PreviewLine('Table 4', center: true),
      if (format.showCustomer) const _PreviewLine('Asha', center: true),
      if (format.showDate)
        _PreviewLine(
          '${_kept(format.dateLabel, 'Date: ')}01 Nov 2026  7:40 PM',
          center: true,
        ),
      if (format.showItemHeader)
        _PreviewLine(
          _kept(format.itemHeader, 'Item'),
          bold: true,
          center: true,
        ),
      const _PreviewLine('1x Filter coffee', bold: true, center: true),
      if (format.showModifiers)
        const _PreviewLine('+ Extra shot', center: true, muted: true),
      if (format.showLineNotes)
        const _PreviewLine('Less sugar', center: true, muted: true),
      const _PreviewLine('2x Masala dosa', bold: true, center: true),
      if (format.showOrderNotes)
        const _PreviewLine('No onion', center: true),
    ];
    return _Paper(
      key: const Key('slip-preview'),
      caption: 'Kitchen ticket',
      paper: format.paper,
      size: size,
      lines: lines,
      warm: true,
    );
  }
}

String _kept(String value, String fallback) {
  return value.trim().isEmpty ? fallback : value;
}

class _Paper extends StatelessWidget {
  const _Paper({
    super.key,
    required this.caption,
    required this.paper,
    required this.size,
    required this.lines,
    this.warm = false,
  });

  final String caption;
  final String paper;
  final double size;
  final List<_PreviewLine> lines;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: warm ? const Color(0xFFFFF7ED) : PosTheme.surfaceMuted,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: PosTheme.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                child: Container(
                  key: ValueKey(
                    '$caption|$paper|$size|${lines.map((line) => line.text).join('|')}',
                  ),
                  width: paper == '58mm' ? 210 : 260,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF5),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            line.text,
                            textAlign: line.center
                                ? TextAlign.center
                                : TextAlign.left,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontWeight: line.bold
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              fontSize: line.large ? size + 3 : size,
                              height: 1.35,
                              color: line.muted
                                  ? const Color(0xFF78716C)
                                  : const Color(0xFF1C1917),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLine {
  const _PreviewLine(
    this.text, {
    this.bold = false,
    this.center = false,
    this.large = false,
    this.muted = false,
  });

  final String text;
  final bool bold;
  final bool center;
  final bool large;
  final bool muted;
}
