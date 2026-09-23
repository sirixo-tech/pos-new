import '../../models/receipt_print_models.dart';
import '../../models/receipt_template.dart';
import '../../utils/format.dart';
import 'esc_pos_builder.dart';
import 'receipt_typography.dart';
import 'thermal_logo.dart';

class ReceiptTemplateRenderer {
  ReceiptTemplateRenderer({
    required this.venue,
    required this.order,
    required this.settings,
    required this.template,
    this.isDuplicateCopy = false,
  }) : _typography = ReceiptTypography(
         receiptWidth: settings.paper,
         fontSize: settings.fontSize,
       );

  final PrintVenueContext venue;
  final OfflinePrintOrder order;
  final PosReceiptSettings settings;
  final ReceiptTemplate template;
  final bool isDuplicateCopy;
  final ReceiptTypography _typography;

  String get _thermalLogoUrl {
    final printLogo = venue.printLogoUrl ?? '';
    if (printLogo.isNotEmpty) {
      return printLogo;
    }

    return venue.logoUrl ?? '';
  }

  void _renderDuplicateCopyBanner(EscPosBuilder esc) {
    final label = settings.duplicateCopyLabel.trim();
    if (label.isEmpty) {
      return;
    }

    esc.resetToBaseFont();
    esc.hr();
    _applyAlign(esc, 'center');
    esc.applyBlockStyle('large_bold');
    esc.text(label.toUpperCase());
    esc.clearBlockStyle('large_bold');
    esc.hr();
    esc.feed(1);
  }

  Future<List<int>> buildBytes({
    bool cutAtEnd = true,
    String cutMode = 'full',
  }) async {
    final esc = EscPosBuilder(
      typography: _typography,
      enableCurrencyGlyphs: settings.showCurrencySymbol,
    );
    esc.initialize();

    if (order.isOffline) {
      esc.alignCenter();
      esc.bold(true);
      esc.text('** OFFLINE ORDER **');
      esc.bold(false);
      esc.text('Will sync when online');
      esc.feed(1);
      esc.resetToBaseFont();
    }

    if (isDuplicateCopy) {
      _renderDuplicateCopyBanner(esc);
    }

    for (final block in template.blocks) {
      if (!_isVisible(block)) continue;
      await _renderBlock(esc, block);
    }

    esc.feed(2);
    if (cutAtEnd) {
      esc.cut(mode: cutMode);
    }
    return esc.build();
  }

  bool _isVisible(ReceiptTemplateBlock block) {
    if (block.enabled == false) return false;

    if (block.type != 'totals' && !_toggleEnabled(block.toggle)) return false;

    switch (block.type) {
      case 'logo':
        return settings.showLogo && _thermalLogoUrl.isNotEmpty;
      case 'field':
      case 'text':
        if (block.format == 'order_type_datetime') {
          if (!settings.showOrderType && !settings.showDatetime) {
            return false;
          }
          final line = _formatOrderTypeAndDatetimeLine();
          if (block.whenEmpty == 'hide' && line.trim().isEmpty) {
            return false;
          }
          return true;
        }
        final value = _resolveBind(block);
        if (block.whenEmpty == 'hide' && value.trim().isEmpty) {
          return false;
        }
        return true;
      case 'line_items':
        return order.items.isNotEmpty;
      case 'qr_code':
        final url = _resolveBind(block);
        return url.trim().isNotEmpty;
      default:
        return true;
    }
  }

  bool _toggleEnabled(String? toggle) {
    if (toggle == null) return true;
    switch (toggle) {
      case 'show_logo':
        return settings.showLogo;
      case 'show_restaurant_name':
        return settings.showRestaurantName;
      case 'show_branch_info':
        return settings.showBranchInfo;
      case 'show_branch_address':
        return settings.showBranchAddress;
      case 'show_tax_id':
        return settings.showTaxId;
      case 'show_datetime':
        return settings.showDatetime;
      case 'show_table':
        return settings.showTable;
      case 'show_order_type':
        return settings.showOrderType;
      case 'show_customer_name':
        return settings.showCustomerName;
      case 'show_order_notes':
        return settings.showOrderNotes;
      case 'show_tax_breakdown':
        return settings.showTaxBreakdown;
      default:
        return true;
    }
  }

  Future<void> _renderBlock(
    EscPosBuilder esc,
    ReceiptTemplateBlock block,
  ) async {
    switch (block.type) {
      case 'logo':
        await _renderLogo(esc, block.align);
        return;
      case 'field':
        _renderField(esc, block);
        return;
      case 'text':
        _renderText(esc, block);
        return;
      case 'divider':
        esc.resetToBaseFont();
        esc.hr();
        return;
      case 'space':
        esc.feed(block.lines.clamp(1, 5).toInt());
        return;
      case 'line_items':
        _renderLineItems(esc, block);
        return;
      case 'totals':
        _renderTotals(esc);
        return;
      case 'payment_status':
        _renderPaymentStatus(esc, block);
        return;
      case 'qr_code':
        _renderQrCode(esc, block);
        return;
    }
  }

  Future<void> _renderLogo(EscPosBuilder esc, String align) async {
    final raster = await ThermalLogo.rasterBytes(
      url: _thermalLogoUrl,
      maxWidthDots: _typography.logoMaxWidthDotsForReceipt(settings.logoSize),
      paperWidthDots: _typography.paperWidthDots,
    );

    _applyAlign(esc, align);
    if (raster != null) {
      esc.raw(raster);
      esc.feed(1);
      esc.ensureRupeeGlyph();
    }
    esc.resetToBaseFont();
  }

  void _renderField(EscPosBuilder esc, ReceiptTemplateBlock block) {
    late final String value;
    if (block.format == 'order_type_datetime') {
      value = _formatOrderTypeAndDatetimeLine();
      if (value.isEmpty) return;
    } else {
      final raw = _resolveBind(block);
      if (raw.isEmpty) return;
      value = block.format == 'datetime'
          ? formatReceiptDatetimeRaw(raw)
          : block.format == 'order_type'
          ? formatOrderType(raw)
          : raw;
    }

    final text = block.format == 'order_type_datetime'
        ? value
        : '${settings.resolveFieldLabel(bind: block.bind, format: block.format, label: block.label)}$value';

    _applyAlign(esc, block.align);
    esc.applyBlockStyle(block.style);
    esc.text(text);
    esc.clearBlockStyle(block.style);
  }

  void _renderText(EscPosBuilder esc, ReceiptTemplateBlock block) {
    final text = _resolveBind(block);
    if (text.isEmpty) return;

    _applyAlign(esc, block.align);
    esc.resetToBaseFont();
    esc.text(text);
  }

  void _renderQrCode(EscPosBuilder esc, ReceiptTemplateBlock block) {
    final url = _resolveBind(block);
    if (url.trim().isEmpty) return;

    _applyAlign(esc, block.align);
    esc.qrCode(url);
    esc.feed(1);
    esc.resetToBaseFont();
  }

  void _renderLineItems(EscPosBuilder esc, ReceiptTemplateBlock block) {
    esc.resetToBaseFont();
    esc.alignLeft();
    final currency = venue.currencyCode;
    final showSymbol = settings.showCurrencySymbol;
    if (block.showHeaders && order.items.isNotEmpty) {
      esc.hr();
      esc.bold(true);
      esc.row('Item', 'Amount');
      esc.bold(false);
      esc.hr();
    }
    for (final item in order.items) {
      final variant = item.variantName?.trim();
      final unitPrice = item.unitPrice > 0
          ? item.unitPrice
          : (item.quantity > 0 ? item.total / item.quantity : item.total);
      esc.row(
        '${item.quantity}x ${item.name}',
        formatMoneyThermal(item.total, currency, showSymbol: showSymbol),
      );
      if (variant != null && variant.isNotEmpty) {
        esc.text('  $variant');
      }
      esc.text(
        '  @ ${formatMoneyThermal(unitPrice, currency, showSymbol: showSymbol)} each',
      );
      if (block.showModifiers) {
        for (final mod in item.modifiers) {
          if (mod.priceAdjustment != 0) {
            esc.row(
              '  + ${mod.optionName}',
              formatMoneyThermal(
                mod.priceAdjustment,
                currency,
                showSymbol: showSymbol,
              ),
            );
          } else {
            esc.text('  + ${mod.optionName}');
          }
        }
      }
    }
  }

  void _renderTotals(EscPosBuilder esc) {
    final currency = venue.currencyCode;
    final showSymbol = settings.showCurrencySymbol;
    esc.resetToBaseFont();
    esc.alignLeft();

    final showCharges = settings.showSubtotal || settings.showTax;

    if (settings.showSubtotal) {
      esc.row(
        'Subtotal',
        formatMoneyThermal(order.subtotal, currency, showSymbol: showSymbol),
      );
    }
    if (settings.showTax) {
      for (final tax in order.taxBreakdown) {
        esc.row(
          '${tax.name} (${tax.rate}%)',
          formatMoneyThermal(tax.amount, currency, showSymbol: showSymbol),
        );
      }
    }
    if (showCharges) {
      for (final line in order.extraCharges) {
        if (line.amount <= 0) continue;
        esc.row(
          line.label,
          formatMoneyThermal(line.amount, currency, showSymbol: showSymbol),
        );
      }
      if (order.serviceCharge > 0) {
        esc.row(
          order.serviceChargeLabel,
          formatMoneyThermal(
            order.serviceCharge,
            currency,
            showSymbol: showSymbol,
          ),
        );
      }
    }

    if (settings.showTotal) {
      esc.resetToBaseFont();
      esc.hr();

      esc.bold(true);
      if (_typography.fontSize == 'large') {
        esc.applyBlockStyle('bold');
      }
      esc.row(
        'TOTAL',
        formatMoneyThermal(order.total, currency, showSymbol: showSymbol),
      );
      esc.clearBlockStyle('bold');
      esc.bold(false);
      esc.resetToBaseFont();
    }
  }

  void _renderPaymentStatus(EscPosBuilder esc, ReceiptTemplateBlock block) {
    esc.resetToBaseFont();
    _applyAlign(esc, block.align);

    final status = formatPaymentStatus(order.paymentStatus);
    final method = formatPaymentMethod(order.paymentMethod);
    final transactionId = (order.transactionId ?? '').trim();

    if (order.paymentStatus == 'pending') {
      esc.bold(true);
    }
    esc.text(status);
    esc.bold(false);

    if (method.isNotEmpty) {
      esc.text('Method: $method');
    }
    if (transactionId.isNotEmpty) {
      esc.text('Transaction: $transactionId');
    }

    esc.resetToBaseFont();
  }

  String _resolveBind(ReceiptTemplateBlock block) {
    final bind = block.bind;
    if (bind == null) return block.value ?? '';

    switch (bind) {
      case 'restaurant.name':
        return venue.restaurantName;
      case 'restaurant.tax_id':
        return venue.taxId ?? '';
      case 'branch.name':
        return venue.branchName;
      case 'branch.address':
        return venue.branchAddress ?? '';
      case 'settings.header_line':
        return settings.headerLine;
      case 'settings.footer_line':
        return settings.footerLine;
      case 'order.token':
        return order.token?.toString() ?? '';
      case 'order.order_number':
        return order.orderNumber;
      case 'order.type':
        return order.orderType ?? '';
      case 'order.created_at':
        return order.createdAt?.toIso8601String() ?? '';
      case 'order.table_name':
        return order.tableName ?? '';
      case 'order.customer_name':
        return order.customerName ?? '';
      case 'order.notes':
        return order.notes ?? '';
      case 'order.payment_status':
        return order.paymentStatus;
      case 'order.payment_method':
        return order.paymentMethod ?? '';
      case 'order.transaction_id':
        return order.transactionId ?? '';
      case 'order.tracking_url':
        return order.trackingUrl ?? '';
      default:
        return block.value ?? '';
    }
  }

  void _applyAlign(EscPosBuilder esc, String align) {
    switch (align) {
      case 'center':
        esc.alignCenter();
        return;
      case 'right':
        esc.alignRight();
        return;
      default:
        esc.alignLeft();
    }
  }

  String _formatOrderTypeAndDatetimeLine() {
    final parts = <String>[];
    if (settings.showOrderType && (order.orderType ?? '').trim().isNotEmpty) {
      parts.add(formatOrderType(order.orderType));
    }
    if (settings.showDatetime && order.createdAt != null) {
      parts.add(formatReceiptDatetime(order.createdAt!));
    }
    return parts.join(' - ');
  }
}
