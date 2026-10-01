import 'receipt_template.dart';
import 'token_template.dart';

/// Venue fields needed by local template renderers (from POS bootstrap).
class PrintVenueContext {
  const PrintVenueContext({
    required this.restaurantName,
    required this.currencyCode,
    required this.branchName,
    this.taxId,
    this.logoUrl,
    this.printLogoUrl,
    this.branchAddress,
  });

  final String restaurantName;
  final String currencyCode;
  final String branchName;
  final String? taxId;
  final String? logoUrl;
  final String? printLogoUrl;
  final String? branchAddress;

  String get thermalLogoUrl {
    final printLogo = (printLogoUrl ?? '').trim();
    if (printLogo.isNotEmpty) return printLogo;
    return (logoUrl ?? '').trim();
  }
}

class OfflinePrintModifier {
  const OfflinePrintModifier({
    required this.optionName,
    required this.priceAdjustment,
  });

  final String optionName;
  final double priceAdjustment;
}

class OfflinePrintItem {
  const OfflinePrintItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.variantName,
    this.modifiers = const [],
    this.kitchenId,
    this.kitchenName,
    this.kitchenCounterName,
    this.notes,
  });

  final String name;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double total;
  final List<OfflinePrintModifier> modifiers;
  final int? kitchenId;
  final String? kitchenName;
  final String? kitchenCounterName;
  final String? notes;
}

class OfflinePrintTaxLine {
  const OfflinePrintTaxLine({
    required this.name,
    required this.rate,
    required this.amount,
    required this.included,
  });

  final String name;
  final double rate;
  final double amount;
  final bool included;
}

class OfflinePrintExtraCharge {
  const OfflinePrintExtraCharge({required this.label, required this.amount});

  final String label;
  final double amount;
}

/// Order snapshot shaped for receipt/token template rendering.
class OfflinePrintOrder {
  const OfflinePrintOrder({
    required this.orderNumber,
    required this.paymentStatus,
    required this.subtotal,
    required this.total,
    required this.items,
    this.token,
    this.orderType,
    this.createdAt,
    this.tableName,
    this.customerName,
    this.notes,
    this.paymentMethod,
    this.transactionId,
    this.trackingUrl,
    this.taxBreakdown = const [],
    this.extraCharges = const [],
    this.serviceCharge = 0,
    this.serviceChargeLabel = 'Service charge',
    this.isOffline = false,
  });

  final String orderNumber;
  final int? token;
  final String? orderType;
  final DateTime? createdAt;
  final String? tableName;
  final String? customerName;
  final String? notes;
  final String paymentStatus;
  final String? paymentMethod;
  final String? transactionId;
  final String? trackingUrl;
  final double subtotal;
  final double total;
  final List<OfflinePrintTaxLine> taxBreakdown;
  final List<OfflinePrintExtraCharge> extraCharges;
  final double serviceCharge;
  final String serviceChargeLabel;
  final List<OfflinePrintItem> items;
  final bool isOffline;
}

class PosTokenSettings {
  PosTokenSettings({
    required this.enabled,
    required this.printWithReceipt,
    required this.channels,
    required this.groupingMode,
    required this.perQuantity,
    required this.cutAfterEach,
    required this.cutMode,
    required this.showDatetime,
    required this.showItemModifiers,
    required this.showItemIndex,
    required this.showCounterName,
    this.fontSize,
    this.logoSize,
    required this.headerLine,
    required this.footerLine,
    required this.template,
  });

  static const List<String> defaultChannels = ['kiosk', 'pos', 'online'];

  final bool enabled;
  final bool printWithReceipt;
  final List<String> channels;
  final String groupingMode;
  final bool perQuantity;
  final bool cutAfterEach;
  final String cutMode;
  final bool showDatetime;
  final bool showItemModifiers;
  final bool showItemIndex;
  final bool showCounterName;
  final String? fontSize;
  final String? logoSize;
  final String headerLine;
  final String footerLine;
  final TokenTemplate template;

  bool enabledForChannel(String channel) {
    if (!enabled) return false;
    final key = switch (channel) {
      'kiosk' => 'kiosk',
      'pos' => 'pos',
      _ => 'online',
    };
    return channels.contains(key);
  }

  factory PosTokenSettings.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    final channels = _normalizeChannels(
      data['channels'],
      fallback: defaultChannels,
      allowEmpty: true,
    );

    return PosTokenSettings(
      enabled: data['enabled'] as bool? ?? false,
      printWithReceipt: data['print_with_receipt'] as bool? ?? true,
      channels: channels,
      groupingMode: data['grouping_mode'] as String? ?? 'per_kitchen',
      perQuantity: data['per_quantity'] as bool? ?? false,
      cutAfterEach: data['cut_after_each'] as bool? ?? true,
      cutMode: data['cut_mode'] as String? ?? 'partial',
      showDatetime: data['show_datetime'] as bool? ?? true,
      showItemModifiers: data['show_item_modifiers'] as bool? ?? true,
      showItemIndex: data['show_item_index'] as bool? ?? true,
      showCounterName: data['show_counter_name'] as bool? ?? true,
      fontSize: data['font_size'] as String?,
      logoSize: data['logo_size'] as String?,
      headerLine: data['header_line'] as String? ?? '',
      footerLine: data['footer_line'] as String? ?? '',
      template: TokenTemplate.fromJson(
        data['template'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'print_with_receipt': printWithReceipt,
    'channels': channels,
    'grouping_mode': groupingMode,
    'per_quantity': perQuantity,
    'cut_after_each': cutAfterEach,
    'cut_mode': cutMode,
    'show_datetime': showDatetime,
    'show_item_modifiers': showItemModifiers,
    'show_item_index': showItemIndex,
    'show_counter_name': showCounterName,
    if (fontSize != null) 'font_size': fontSize,
    if (logoSize != null) 'logo_size': logoSize,
    'header_line': headerLine,
    'footer_line': footerLine,
    'template': template.toJson(),
  };
}

List<String> _normalizeChannels(
  dynamic raw, {
  required List<String> fallback,
  required bool allowEmpty,
}) {
  if (raw == null) return List<String>.from(fallback);
  if (raw is! List) return List<String>.from(fallback);

  final channels = <String>[];
  for (final value in raw) {
    if (value is! String) continue;
    final key = switch (value) {
      'kiosk' => 'kiosk',
      'pos' => 'pos',
      'online' || 'default' || 'storefront' || 'web' => 'online',
      _ => null,
    };
    if (key != null && !channels.contains(key)) {
      channels.add(key);
    }
  }

  if (channels.isEmpty && !allowEmpty) {
    return List<String>.from(fallback);
  }
  return channels;
}

/// Full receipt settings from POS bootstrap (templates + channel gates).
class PosReceiptSettings {
  PosReceiptSettings({
    this.paper = '80mm',
    this.fontSize = 'medium',
    this.logoUrl,
    this.showLogo = true,
    this.showRestaurantName = true,
    this.showTaxId = true,
    this.showBranchInfo = true,
    this.showBranchAddress = true,
    this.totalsDisplay = 'detailed',
    this.showTaxBreakdown = true,
    this.showSubtotal = true,
    this.showTax = true,
    this.showTotal = true,
    this.orderNumberLabel = 'Bill No: ',
    this.dateLabel = 'Date: ',
    this.showOrderNotes = true,
    this.showDatetime = true,
    this.showTable = true,
    this.showOrderType = true,
    this.showCustomerName = true,
    this.logoSize = 'medium',
    this.showCurrencySymbol = true,
    this.showPoweredBy = true,
    this.headerText,
    this.footerText,
    this.duplicateCopyLabel = 'Duplicate Copy',
    this.enabled = true,
    List<String>? channels,
    ReceiptTemplate? template,
    PosTokenSettings? token,
  }) : channels = channels ?? const ['kiosk', 'pos', 'online'],
       template = template ?? ReceiptTemplate.fromJson(null),
       token = token ?? PosTokenSettings.fromJson(null);

  static const List<String> defaultChannels = ['kiosk', 'pos', 'online'];
  static const String defaultOrderNumberLabel = 'Bill No: ';
  static const String defaultDateLabel = 'Date: ';

  final String paper;
  final String fontSize;
  final String? logoUrl;
  final bool showLogo;
  final bool showRestaurantName;
  final bool showTaxId;
  final bool showBranchInfo;
  final bool showBranchAddress;
  final String totalsDisplay;
  final bool showTaxBreakdown;
  final bool showSubtotal;
  final bool showTax;
  final bool showTotal;
  final String orderNumberLabel;
  final String dateLabel;
  final bool showOrderNotes;
  final bool showDatetime;
  final bool showTable;
  final bool showOrderType;
  final bool showCustomerName;
  final String logoSize;
  final bool showCurrencySymbol;
  final bool showPoweredBy;
  final String? headerText;
  final String? footerText;
  final String duplicateCopyLabel;
  final bool enabled;
  final List<String> channels;
  final ReceiptTemplate template;
  final PosTokenSettings token;

  String get receiptWidth => paper;
  String get headerLine => headerText ?? '';
  String get footerLine => (footerText ?? '').trim().isEmpty
      ? 'Thank you for your order!'
      : footerText!.trim();

  bool enabledForChannel(String channel) {
    if (!enabled) return false;
    final key = switch (channel) {
      'kiosk' => 'kiosk',
      'pos' => 'pos',
      _ => 'online',
    };
    return channels.contains(key);
  }

  /// Settings override template defaults for bill number / date labels.
  String resolveFieldLabel({
    required String? bind,
    String? format,
    String? label,
  }) {
    if (bind == 'order.order_number') {
      return orderNumberLabel;
    }
    if (bind == 'order.created_at' && format == 'datetime') {
      return dateLabel;
    }
    return label ?? '';
  }

  factory PosReceiptSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PosReceiptSettings();
    final header =
        (json['header_line'] as String? ?? json['header_text'] as String?)
            ?.trim();
    final footer =
        (json['footer_line'] as String? ?? json['footer_text'] as String?)
            ?.trim();
    final rowVisibility = _normalizeRowVisibility(json);
    final channels = _normalizeChannels(
      json['channels'],
      fallback: defaultChannels,
      allowEmpty: true,
    );

    return PosReceiptSettings(
      paper: _normalizeReceiptPaper(
        json['receipt_width']?.toString() ?? json['paper']?.toString(),
      ),
      fontSize: json['font_size'] as String? ?? 'medium',
      logoUrl: json['logo_url'] as String?,
      showLogo: json['show_logo'] as bool? ?? true,
      showRestaurantName: json['show_restaurant_name'] as bool? ?? true,
      showTaxId: json['show_tax_id'] as bool? ?? true,
      showBranchInfo: json['show_branch_info'] as bool? ?? true,
      showBranchAddress: json['show_branch_address'] as bool? ?? true,
      totalsDisplay: rowVisibility.totalsDisplay,
      showTaxBreakdown: rowVisibility.showTaxBreakdown,
      showSubtotal: rowVisibility.showSubtotal,
      showTax: rowVisibility.showTax,
      showTotal: rowVisibility.showTotal,
      orderNumberLabel: _sanitizeLabel(
        json['order_number_label'] as String?,
        defaultOrderNumberLabel,
      ),
      dateLabel: _sanitizeLabel(
        json['date_label'] as String?,
        defaultDateLabel,
      ),
      showOrderNotes: json['show_order_notes'] as bool? ?? true,
      showDatetime: json['show_datetime'] as bool? ?? true,
      showTable: json['show_table'] as bool? ?? true,
      showOrderType: json['show_order_type'] as bool? ?? true,
      showCustomerName: json['show_customer_name'] as bool? ?? true,
      logoSize: json['logo_size'] as String? ?? 'medium',
      showCurrencySymbol: json['show_currency_symbol'] as bool? ?? true,
      showPoweredBy: json['show_powered_by'] as bool? ?? true,
      headerText: header != null && header.isNotEmpty ? header : null,
      footerText: footer != null && footer.isNotEmpty ? footer : null,
      duplicateCopyLabel: () {
        final label =
            (json['duplicate_copy_label'] as String? ?? 'Duplicate Copy')
                .trim();
        return label.isEmpty ? 'Duplicate Copy' : label;
      }(),
      enabled: json['enabled'] as bool? ?? true,
      channels: channels,
      template: ReceiptTemplate.fromJson(
        json['template'] as Map<String, dynamic>?,
      ),
      token: PosTokenSettings.fromJson(json['token'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
    'receipt_width': paper,
    'paper': paper,
    'font_size': fontSize,
    if (logoUrl != null) 'logo_url': logoUrl,
    'show_logo': showLogo,
    'show_restaurant_name': showRestaurantName,
    'show_tax_id': showTaxId,
    'show_branch_info': showBranchInfo,
    'show_branch_address': showBranchAddress,
    'totals_display': totalsDisplay,
    'show_tax_breakdown': showTaxBreakdown,
    'show_subtotal': showSubtotal,
    'show_tax': showTax,
    'show_total': showTotal,
    'order_number_label': orderNumberLabel,
    'date_label': dateLabel,
    'show_order_notes': showOrderNotes,
    'show_datetime': showDatetime,
    'show_table': showTable,
    'show_order_type': showOrderType,
    'show_customer_name': showCustomerName,
    'logo_size': logoSize,
    'show_currency_symbol': showCurrencySymbol,
    'show_powered_by': showPoweredBy,
    'duplicate_copy_label': duplicateCopyLabel,
    'enabled': enabled,
    'channels': channels,
    if (headerText != null) ...{
      'header_line': headerText,
      'header_text': headerText,
    },
    if (footerText != null) ...{
      'footer_line': footerText,
      'footer_text': footerText,
    },
    'template': template.toJson(),
    'token': token.toJson(),
  };

  static ({
    bool showSubtotal,
    bool showTax,
    bool showTotal,
    String totalsDisplay,
    bool showTaxBreakdown,
  })
  _normalizeRowVisibility(Map<String, dynamic> data) {
    final hasGranular =
        data.containsKey('show_subtotal') ||
        data.containsKey('show_tax') ||
        data.containsKey('show_total');

    late final bool showSubtotal;
    late final bool showTax;
    late final bool showTotal;

    if (hasGranular) {
      showSubtotal = data['show_subtotal'] as bool? ?? true;
      showTax = data['show_tax'] as bool? ?? true;
      showTotal = data['show_total'] as bool? ?? true;
    } else {
      final detailed = _legacyTotalsShowsBreakdown(data);
      showSubtotal = detailed;
      showTax = detailed;
      showTotal = true;
    }

    final totalsDisplay = (showSubtotal || showTax) ? 'detailed' : 'total_only';

    return (
      showSubtotal: showSubtotal,
      showTax: showTax,
      showTotal: showTotal,
      totalsDisplay: totalsDisplay,
      showTaxBreakdown: showSubtotal || showTax,
    );
  }

  static bool _legacyTotalsShowsBreakdown(Map<String, dynamic> data) {
    final raw = data['totals_display'] as String?;
    if (raw == 'total_only' || raw == 'detailed') {
      return raw == 'detailed';
    }
    return data['show_tax_breakdown'] as bool? ?? true;
  }

  static String _sanitizeLabel(String? value, String fallback) {
    if (value == null) return fallback;
    var normalized = value.trim();
    if (normalized.isEmpty) return fallback;
    if (RegExp(r'[:#]$').hasMatch(normalized)) {
      normalized = '$normalized ';
    }
    return normalized.length > 40 ? normalized.substring(0, 40) : normalized;
  }

  static String _normalizeReceiptPaper(String? width) {
    switch ((width ?? '').trim().toLowerCase().replaceAll(' ', '')) {
      case '56':
      case '58':
      case '56mm':
      case '58mm':
        return '56mm';
      case '72':
      case '72mm':
        return '72mm';
      case '112':
      case '112mm':
      case 'full':
        return '112mm';
      default:
        return '80mm';
    }
  }
}
