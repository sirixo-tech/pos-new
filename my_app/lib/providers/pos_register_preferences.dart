import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pos_models.dart';
import '../models/receipt_template.dart';

const posOrderTypes = ['dine_in', 'takeaway', 'delivery'];

/// Types still offered on this register.
///
/// [serverAllowed] is the web list. A type the web turned off stays off.
/// A type the cashier hides here is removed. One type always remains.
List<String> visiblePosOrderTypes({
  required List<String> serverAllowed,
  required bool dineIn,
  required bool takeaway,
  required bool delivery,
}) {
  final base = serverAllowed.isEmpty
      ? List<String>.from(posOrderTypes)
      : List<String>.from(serverAllowed);
  bool on(String type) => switch (type) {
    'dine_in' => dineIn,
    'takeaway' => takeaway,
    'delivery' => delivery,
    _ => true,
  };
  final visible = base.where(on).toList();
  if (visible.isNotEmpty) return visible;
  return [base.first];
}

/// Cashier format for slips printed from orders saved on this device.
class OfflineReceiptFormat {
  const OfflineReceiptFormat({
    this.headerLine = '',
    this.footerLine = 'Thank you for your order!',
    this.fontSize = 'medium',
    this.paper = '80mm',
    this.showRestaurantName = true,
    this.showBranch = true,
    this.showAddress = true,
    this.showDatetime = true,
    this.showTable = true,
    this.showOrderType = true,
    this.showCustomer = true,
    this.showNotes = true,
    this.showTax = true,
    this.showSubtotal = true,
    this.showTotal = true,
    this.showLogo = true,
    this.showTaxId = true,
    this.showToken = true,
    this.showItemHeaders = true,
    this.showModifiers = true,
    this.showPayment = true,
    this.showTracking = true,
    this.billLabel = 'Bill No: ',
    this.dateLabel = 'Date: ',
    this.tokenLabel = 'TOKEN #',
    this.taxIdLabel = 'Tax ID: ',
    this.trackPrompt = 'Scan here to track order',
  });

  final String headerLine;
  final String footerLine;
  final String fontSize;
  final String paper;
  final bool showRestaurantName;
  final bool showBranch;
  final bool showAddress;
  final bool showDatetime;
  final bool showTable;
  final bool showOrderType;
  final bool showCustomer;
  final bool showNotes;
  final bool showTax;
  final bool showSubtotal;
  final bool showTotal;
  final bool showLogo;
  final bool showTaxId;
  final bool showToken;
  final bool showItemHeaders;
  final bool showModifiers;
  final bool showPayment;
  final bool showTracking;
  final String billLabel;
  final String dateLabel;
  final String tokenLabel;
  final String taxIdLabel;
  final String trackPrompt;

  /// The slip the app prints offline when no cashier format has been saved.
  static const codeDefault = OfflineReceiptFormat();

  factory OfflineReceiptFormat.fromSettings(PosReceiptSettings settings) {
    return OfflineReceiptFormat(
      headerLine: settings.headerText ?? '',
      footerLine: settings.footerText ?? 'Thank you for your order!',
      fontSize: settings.fontSize,
      paper: settings.paper == '56mm' ? '58mm' : settings.paper,
      showRestaurantName: settings.showRestaurantName,
      showBranch: settings.showBranchInfo,
      showAddress: settings.showBranchAddress,
      showDatetime: settings.showDatetime,
      showTable: settings.showTable,
      showOrderType: settings.showOrderType,
      showCustomer: settings.showCustomerName,
      showNotes: settings.showOrderNotes,
      showTax: settings.showTax,
      showSubtotal: settings.showSubtotal,
      showTotal: settings.showTotal,
      showLogo: settings.showLogo,
      showTaxId: settings.showTaxId,
      billLabel: settings.orderNumberLabel,
      dateLabel: settings.dateLabel,
    );
  }

  factory OfflineReceiptFormat.fromJson(Map<String, dynamic> json) {
    final base = OfflineReceiptFormat.fromSettings(PosReceiptSettings());
    bool flag(String key, bool fallback) => json[key] as bool? ?? fallback;
    return OfflineReceiptFormat(
      headerLine: json['header_line'] as String? ?? base.headerLine,
      footerLine: json['footer_line'] as String? ?? base.footerLine,
      fontSize: json['font_size'] as String? ?? base.fontSize,
      paper: json['paper'] as String? ?? base.paper,
      showRestaurantName: flag('show_restaurant_name', base.showRestaurantName),
      showBranch: flag('show_branch', base.showBranch),
      showAddress: flag('show_address', base.showAddress),
      showDatetime: flag('show_datetime', base.showDatetime),
      showTable: flag('show_table', base.showTable),
      showOrderType: flag('show_order_type', base.showOrderType),
      showCustomer: flag('show_customer', base.showCustomer),
      showNotes: flag('show_notes', base.showNotes),
      showTax: flag('show_tax', base.showTax),
      showSubtotal: flag('show_subtotal', base.showSubtotal),
      showTotal: flag('show_total', base.showTotal),
      showLogo: flag('show_logo', base.showLogo),
      showTaxId: flag('show_tax_id', base.showTaxId),
      showToken: flag('show_token', base.showToken),
      showItemHeaders: flag('show_item_headers', base.showItemHeaders),
      showModifiers: flag('show_modifiers', base.showModifiers),
      showPayment: flag('show_payment', base.showPayment),
      showTracking: flag('show_tracking', base.showTracking),
      billLabel: json['bill_label'] as String? ?? base.billLabel,
      dateLabel: json['date_label'] as String? ?? base.dateLabel,
      tokenLabel: json['token_label'] as String? ?? base.tokenLabel,
      taxIdLabel: json['tax_id_label'] as String? ?? base.taxIdLabel,
      trackPrompt: json['track_prompt'] as String? ?? base.trackPrompt,
    );
  }

  Map<String, dynamic> toJson() => {
    'header_line': headerLine,
    'footer_line': footerLine,
    'font_size': fontSize,
    'paper': paper,
    'show_restaurant_name': showRestaurantName,
    'show_branch': showBranch,
    'show_address': showAddress,
    'show_datetime': showDatetime,
    'show_table': showTable,
    'show_order_type': showOrderType,
    'show_customer': showCustomer,
    'show_notes': showNotes,
    'show_tax': showTax,
    'show_subtotal': showSubtotal,
    'show_total': showTotal,
    'show_logo': showLogo,
    'show_tax_id': showTaxId,
    'show_token': showToken,
    'show_item_headers': showItemHeaders,
    'show_modifiers': showModifiers,
    'show_payment': showPayment,
    'show_tracking': showTracking,
    'bill_label': billLabel,
    'date_label': dateLabel,
    'token_label': tokenLabel,
    'tax_id_label': taxIdLabel,
    'track_prompt': trackPrompt,
  };

  /// Same line order as [ReceiptTemplate.defaultBlocks], with cashier edits.
  ReceiptTemplate toCodeTemplate() {
    String label(String value, String fallback) {
      final text = value.trim();
      return text.isEmpty ? fallback : text;
    }

    return ReceiptTemplate(
      version: 1,
      blocks: [
        ReceiptTemplateBlock(
          type: 'logo',
          toggle: 'show_logo',
          align: 'center',
          enabled: showLogo,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'restaurant.name',
          toggle: 'show_restaurant_name',
          style: 'title',
          align: 'center',
          enabled: showRestaurantName,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'branch.name',
          toggle: 'show_branch_info',
          align: 'center',
          enabled: showBranch,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'branch.address',
          toggle: 'show_branch_address',
          align: 'center',
          whenEmpty: 'hide',
          enabled: showAddress,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'restaurant.tax_id',
          label: label(taxIdLabel, 'Tax ID: '),
          toggle: 'show_tax_id',
          align: 'center',
          whenEmpty: 'hide',
          enabled: showTaxId,
        ),
        ReceiptTemplateBlock(
          type: 'text',
          bind: 'settings.header_line',
          align: 'center',
          whenEmpty: 'hide',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.token',
          label: label(tokenLabel, 'TOKEN #'),
          style: 'large_bold',
          align: 'center',
          whenEmpty: 'hide',
          enabled: showToken,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.order_number',
          label: label(billLabel, 'Bill No: '),
          style: 'bold',
          align: 'left',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.type',
          format: 'order_type',
          toggle: 'show_order_type',
          style: 'bold',
          align: 'left',
          whenEmpty: 'hide',
          enabled: showOrderType,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.created_at',
          format: 'datetime',
          label: label(dateLabel, 'Date: '),
          toggle: 'show_datetime',
          align: 'left',
          whenEmpty: 'hide',
          enabled: showDatetime,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.table_name',
          label: 'Table: ',
          toggle: 'show_table',
          align: 'left',
          whenEmpty: 'hide',
          enabled: showTable,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.customer_name',
          label: 'Customer: ',
          toggle: 'show_customer_name',
          align: 'left',
          whenEmpty: 'hide',
          enabled: showCustomer,
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.notes',
          label: 'Note: ',
          toggle: 'show_order_notes',
          align: 'left',
          whenEmpty: 'hide',
          enabled: showNotes,
        ),
        ReceiptTemplateBlock(
          type: 'line_items',
          showModifiers: showModifiers,
          showHeaders: showItemHeaders,
        ),
        ReceiptTemplateBlock(type: 'divider'),
        ReceiptTemplateBlock(type: 'totals'),
        ReceiptTemplateBlock(
          type: 'payment_status',
          align: 'center',
          enabled: showPayment,
        ),
        ReceiptTemplateBlock(
          type: 'text',
          value: trackPrompt.trim().isEmpty
              ? 'Scan here to track order'
              : trackPrompt.trim(),
          align: 'center',
          style: 'bold',
          enabled: showTracking,
        ),
        ReceiptTemplateBlock(
          type: 'qr_code',
          bind: 'order.tracking_url',
          align: 'center',
          whenEmpty: 'hide',
          enabled: showTracking,
        ),
        ReceiptTemplateBlock(
          type: 'text',
          bind: 'settings.footer_line',
          align: 'center',
          whenEmpty: 'hide',
        ),
      ],
    );
  }

  /// Overlay cashier fields onto the bootstrap settings. Template and token
  /// stay as they were so item rows and token slips keep their layout.
  PosReceiptSettings applyTo(PosReceiptSettings base) {
    final header = headerLine.trim();
    final footer = footerLine.trim();
    return PosReceiptSettings(
      paper: paper == '58mm' ? '58mm' : '80mm',
      fontSize: switch (fontSize) {
        'small' || 'large' => fontSize,
        _ => 'medium',
      },
      logoUrl: base.logoUrl,
      showLogo: showLogo,
      showRestaurantName: showRestaurantName,
      showTaxId: showTaxId,
      showBranchInfo: showBranch,
      showBranchAddress: showAddress,
      totalsDisplay: base.totalsDisplay,
      showTaxBreakdown: base.showTaxBreakdown,
      showSubtotal: showSubtotal,
      showTax: showTax,
      showTotal: showTotal,
      orderNumberLabel: billLabel.trim().isEmpty ? base.orderNumberLabel : billLabel,
      dateLabel: dateLabel.trim().isEmpty ? base.dateLabel : dateLabel,
      showOrderNotes: showNotes,
      showDatetime: showDatetime,
      showTable: showTable,
      showOrderType: showOrderType,
      showCustomerName: showCustomer,
      logoSize: base.logoSize,
      showCurrencySymbol: base.showCurrencySymbol,
      showPoweredBy: base.showPoweredBy,
      headerText: header.isEmpty ? null : header,
      footerText: footer.isEmpty ? null : footer,
      duplicateCopyLabel: base.duplicateCopyLabel,
      enabled: true,
      channels: base.channels.contains('pos')
          ? base.channels
          : [...base.channels, 'pos'],
      template: base.template,
      token: base.token,
    );
  }
}

/// Cashier format for the offline kitchen ticket. Null means the built-in slip.
class OfflineKotFormat {
  const OfflineKotFormat({
    this.title = 'KITCHEN ORDER',
    this.tokenLabel = 'TOKEN #',
    this.dateLabel = 'Date: ',
    this.itemHeader = 'Item',
    this.fontSize = 'medium',
    this.paper = '80mm',
    this.showTitle = true,
    this.showToken = true,
    this.showOrderType = true,
    this.showTable = true,
    this.showCustomer = true,
    this.showDate = true,
    this.showItemHeader = true,
    this.showModifiers = true,
    this.showLineNotes = true,
    this.showOrderNotes = true,
  });

  final String title;
  final String tokenLabel;
  final String dateLabel;
  final String itemHeader;
  final String fontSize;
  final String paper;
  final bool showTitle;
  final bool showToken;
  final bool showOrderType;
  final bool showTable;
  final bool showCustomer;
  final bool showDate;
  final bool showItemHeader;
  final bool showModifiers;
  final bool showLineNotes;
  final bool showOrderNotes;

  static const codeDefault = OfflineKotFormat();

  factory OfflineKotFormat.fromJson(Map<String, dynamic> json) {
    const base = OfflineKotFormat.codeDefault;
    bool flag(String key, bool fallback) => json[key] as bool? ?? fallback;
    return OfflineKotFormat(
      title: json['title'] as String? ?? base.title,
      tokenLabel: json['token_label'] as String? ?? base.tokenLabel,
      dateLabel: json['date_label'] as String? ?? base.dateLabel,
      itemHeader: json['item_header'] as String? ?? base.itemHeader,
      fontSize: json['font_size'] as String? ?? base.fontSize,
      paper: json['paper'] as String? ?? base.paper,
      showTitle: flag('show_title', base.showTitle),
      showToken: flag('show_token', base.showToken),
      showOrderType: flag('show_order_type', base.showOrderType),
      showTable: flag('show_table', base.showTable),
      showCustomer: flag('show_customer', base.showCustomer),
      showDate: flag('show_date', base.showDate),
      showItemHeader: flag('show_item_header', base.showItemHeader),
      showModifiers: flag('show_modifiers', base.showModifiers),
      showLineNotes: flag('show_line_notes', base.showLineNotes),
      showOrderNotes: flag('show_order_notes', base.showOrderNotes),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'token_label': tokenLabel,
    'date_label': dateLabel,
    'item_header': itemHeader,
    'font_size': fontSize,
    'paper': paper,
    'show_title': showTitle,
    'show_token': showToken,
    'show_order_type': showOrderType,
    'show_table': showTable,
    'show_customer': showCustomer,
    'show_date': showDate,
    'show_item_header': showItemHeader,
    'show_modifiers': showModifiers,
    'show_line_notes': showLineNotes,
    'show_order_notes': showOrderNotes,
  };
}

/// This register's order-type visibility and offline receipt format.
class PosRegisterPreferences extends ChangeNotifier {
  PosRegisterPreferences();

  static final PosRegisterPreferences instance = PosRegisterPreferences();
  static const orderTypeKey = 'pos_local_order_types';
  static const offlineReceiptKey = 'pos_offline_receipt_format';
  static const offlineKotKey = 'pos_offline_kot_format';

  bool dineIn = true;
  bool takeaway = true;
  bool delivery = true;
  OfflineReceiptFormat? offlineFormat;
  OfflineKotFormat? offlineKotFormat;
  bool _loaded = false;

  bool get hasOfflineFormat => offlineFormat != null;
  bool get hasOfflineKotFormat => offlineKotFormat != null;

  bool isOrderTypeEnabled(String type) => switch (type) {
    'dine_in' => dineIn,
    'takeaway' => takeaway,
    'delivery' => delivery,
    _ => true,
  };

  List<String> visibleOrderTypes(List<String> serverAllowed) {
    return visiblePosOrderTypes(
      serverAllowed: serverAllowed,
      dineIn: dineIn,
      takeaway: takeaway,
      delivery: delivery,
    );
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(orderTypeKey);
    if (stored != null) {
      dineIn = stored.contains('dine_in');
      takeaway = stored.contains('takeaway');
      delivery = stored.contains('delivery');
    }
    final raw = prefs.getString(offlineReceiptKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          offlineFormat = OfflineReceiptFormat.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        offlineFormat = null;
      }
    }
    final kotRaw = prefs.getString(offlineKotKey);
    if (kotRaw != null && kotRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(kotRaw);
        if (decoded is Map) {
          offlineKotFormat = OfflineKotFormat.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        offlineKotFormat = null;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setOrderTypeEnabled(String type, bool enabled) async {
    switch (type) {
      case 'dine_in':
        dineIn = enabled;
      case 'takeaway':
        takeaway = enabled;
      case 'delivery':
        delivery = enabled;
      default:
        return;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(orderTypeKey, [
      if (dineIn) 'dine_in',
      if (takeaway) 'takeaway',
      if (delivery) 'delivery',
    ]);
  }

  Future<void> saveOfflineFormat(OfflineReceiptFormat format) async {
    offlineFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(offlineReceiptKey, jsonEncode(format.toJson()));
  }

  Future<void> clearOfflineFormat() async {
    offlineFormat = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(offlineReceiptKey);
  }

  Future<void> saveOfflineKotFormat(OfflineKotFormat format) async {
    offlineKotFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(offlineKotKey, jsonEncode(format.toJson()));
  }

  Future<void> clearOfflineKotFormat() async {
    offlineKotFormat = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(offlineKotKey);
  }
}
