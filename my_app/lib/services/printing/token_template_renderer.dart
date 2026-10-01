import '../../models/receipt_print_models.dart';
import '../../models/token_template.dart';
import '../../utils/format.dart';
import 'esc_pos_builder.dart';
import 'receipt_typography.dart';
import 'thermal_logo.dart';

class TokenPrintItem {
  TokenPrintItem({
    required this.name,
    this.variantName,
    this.kitchenCounterName,
    this.kitchenName,
    required this.quantity,
    required this.total,
    required this.indexLabel,
    required this.modifiers,
    this.groupedItems,
  });

  final String name;
  final String? variantName;
  final String? kitchenCounterName;
  final String? kitchenName;
  final int quantity;
  final double total;
  final String indexLabel;
  final List<OfflinePrintModifier> modifiers;
  final List<TokenPrintItem>? groupedItems;

  List<TokenPrintItem> get itemLines =>
      groupedItems != null && groupedItems!.isNotEmpty ? groupedItems! : [this];

  String get lineLabel => '${quantity}x $name';

  String? get variantLabel {
    final value = variantName?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

class TokenTemplateRenderer {
  TokenTemplateRenderer({
    required this.venue,
    required this.order,
    required this.receiptSettings,
    required this.tokenSettings,
    required this.template,
    required this.item,
  }) : _typography = ReceiptTypography(
         receiptWidth: receiptSettings.paper,
         fontSize: tokenSettings.fontSize ?? receiptSettings.fontSize,
       );

  final PrintVenueContext venue;
  final OfflinePrintOrder order;
  final PosReceiptSettings receiptSettings;
  final PosTokenSettings tokenSettings;
  final TokenTemplate template;
  final TokenPrintItem item;
  final ReceiptTypography _typography;

  String get _thermalLogoUrl {
    final printLogo = venue.printLogoUrl ?? '';
    if (printLogo.isNotEmpty) {
      return printLogo;
    }

    return venue.logoUrl ?? '';
  }

  Future<List<int>> buildBytes({
    required bool cutAtEnd,
    String cutMode = 'full',
  }) async {
    final esc = EscPosBuilder(
      typography: _typography,
      enableCurrencyGlyphs: receiptSettings.showCurrencySymbol ? null : false,
    );
    esc.initialize();

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

  bool _isVisible(TokenTemplateBlock block) {
    if (block.enabled == false) return false;
    if (!_toggleEnabled(block.toggle)) return false;

    switch (block.type) {
      case 'logo':
        return receiptSettings.showLogo && _thermalLogoUrl.isNotEmpty;
      case 'field':
      case 'text':
        if (block.format == 'order_type_datetime') {
          if (!receiptSettings.showOrderType &&
              !receiptSettings.showDatetime &&
              !tokenSettings.showDatetime) {
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
      case 'item_modifiers':
        return item.itemLines.length == 1 && item.modifiers.isNotEmpty;
      case 'item_line':
        return item.itemLines.isNotEmpty;
      default:
        return true;
    }
  }

  bool _toggleEnabled(String? toggle) {
    if (toggle == null) return true;
    switch (toggle) {
      case 'show_logo':
        return receiptSettings.showLogo;
      case 'show_restaurant_name':
        return receiptSettings.showRestaurantName;
      case 'show_order_type':
        return receiptSettings.showOrderType;
      case 'show_datetime':
        return tokenSettings.showDatetime;
      case 'show_item_modifiers':
        return tokenSettings.showItemModifiers;
      case 'show_item_index':
        return tokenSettings.showItemIndex;
      case 'show_counter_name':
        return tokenSettings.showCounterName;
      default:
        return true;
    }
  }

  Future<void> _renderBlock(EscPosBuilder esc, TokenTemplateBlock block) async {
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
      case 'item_modifiers':
        _renderModifiers(esc);
        return;
      case 'item_line':
        _renderItemLine(esc, block);
        return;
    }
  }

  Future<void> _renderLogo(EscPosBuilder esc, String align) async {
    final raster = await ThermalLogo.rasterBytes(
      url: _thermalLogoUrl,
      maxWidthDots: _typography.logoMaxWidthDotsForToken(
        receiptLogoSize: receiptSettings.logoSize,
        tokenLogoSize: tokenSettings.logoSize,
      ),
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

  void _renderField(EscPosBuilder esc, TokenTemplateBlock block) {
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
        : _fieldDisplayText(block, value);

    _applyAlign(esc, block.align);
    esc.applyBlockStyle(block.style);
    esc.text(text);
    esc.clearBlockStyle(block.style);
  }

  void _renderText(EscPosBuilder esc, TokenTemplateBlock block) {
    final text = _resolveBind(block);
    if (text.isEmpty) return;

    _applyAlign(esc, block.align);
    esc.resetToBaseFont();
    esc.text(text);
  }

  void _renderModifiers(EscPosBuilder esc) {
    final currency = venue.currencyCode;
    final showSymbol = receiptSettings.showCurrencySymbol;
    esc.resetToBaseFont();
    esc.alignLeft();
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

  void _renderItemLine(EscPosBuilder esc, TokenTemplateBlock block) {
    final currency = venue.currencyCode;
    final showSymbol = receiptSettings.showCurrencySymbol;
    final lines = item.itemLines;

    if (block.showHeaders && lines.isNotEmpty) {
      esc.resetToBaseFont();
      esc.hr();
      esc.row('Item', 'Amount');
      esc.hr();
    }

    for (var index = 0; index < lines.length; index++) {
      final lineItem = lines[index];
      if (index > 0) {
        esc.feed(1);
      }

      final total = formatMoneyThermal(
        lineItem.total,
        currency,
        showSymbol: showSymbol,
      );
      esc.resetToBaseFont();
      _applyAlign(esc, block.align);

      if (block.align == 'center' || block.align == 'right') {
        esc.applyBlockStyle('bold');
        esc.text('${lineItem.lineLabel}  $total');
        esc.clearBlockStyle('bold');
      } else {
        esc.row(lineItem.lineLabel, total);
      }

      final variant = lineItem.variantLabel;
      if (variant != null) {
        esc.text('  $variant');
      }

      if (block.showModifiers) {
        for (final mod in lineItem.modifiers) {
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

  String _resolveBind(TokenTemplateBlock block) {
    final bind = block.bind;
    if (bind == null) return block.value ?? '';

    switch (bind) {
      case 'restaurant.name':
        return venue.restaurantName;
      case 'restaurant.tax_id':
        return venue.taxId ?? '';
      case 'branch.name':
        return venue.branchName;
      case 'settings.header_line':
        return tokenSettings.headerLine;
      case 'settings.footer_line':
        return tokenSettings.footerLine;
      case 'order.token':
        return order.token?.toString() ?? '';
      case 'order.order_number':
        return order.orderNumber;
      case 'order.type':
        return order.orderType ?? '';
      case 'order.created_at':
        return order.createdAt?.toIso8601String() ?? '';
      case 'order.table_name':
        return '';
      case 'order.customer_name':
        return order.customerName ?? '';
      case 'order.notes':
        return order.notes ?? '';
      case 'item.name':
        return item.name;
      case 'item.variant_name':
        return item.variantName ?? '';
      case 'item.quantity':
        return item.quantity.toString();
      case 'item.index_label':
        return item.indexLabel;
      case 'kitchen.counter_name':
        return item.kitchenCounterName ?? '';
      case 'kitchen.name':
        return item.kitchenName ?? '';
      default:
        return block.value ?? '';
    }
  }

  String _fieldDisplayText(TokenTemplateBlock block, String value) {
    final bind = block.bind;
    if (bind == 'kitchen.counter_name' || bind == 'kitchen.name') {
      return value;
    }

    return '${receiptSettings.resolveFieldLabel(bind: bind, format: block.format, label: block.label)}$value';
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
    if (receiptSettings.showOrderType &&
        (order.orderType ?? '').trim().isNotEmpty) {
      parts.add(formatOrderType(order.orderType));
    }
    if ((receiptSettings.showDatetime || tokenSettings.showDatetime) &&
        order.createdAt != null) {
      parts.add(formatReceiptDatetime(order.createdAt!));
    }
    return parts.join(' - ');
  }
}

List<TokenPrintItem> expandTokenPrintItems(
  OfflinePrintOrder order,
  PosTokenSettings tokenSettings,
) {
  if (tokenSettings.groupingMode == 'per_item') {
    return expandTokenPrintItemsPerItem(order, tokenSettings);
  }

  return expandTokenPrintItemsPerKitchen(order);
}

List<TokenPrintItem> expandTokenPrintItemsPerKitchen(OfflinePrintOrder order) {
  final groupOrder = <Object>[];
  final groups = <Object, _TokenKitchenGroup>{};

  for (final line in order.items) {
    final key = line.kitchenId ?? 'none';
    groups.putIfAbsent(key, () {
      groupOrder.add(key);
      return _TokenKitchenGroup(
        kitchenId: line.kitchenId,
        kitchenName: line.kitchenName,
        kitchenCounterName: line.kitchenCounterName,
      );
    });
    groups[key]!.items.add(_tokenLineFromOrderItem(line));
  }

  final total = groupOrder.length;
  final units = <TokenPrintItem>[];

  for (var index = 0; index < groupOrder.length; index++) {
    final group = groups[groupOrder[index]]!;
    final groupedItems = group.items;
    final first = groupedItems.first;
    units.add(
      TokenPrintItem(
        name: first.name,
        variantName: first.variantName,
        kitchenCounterName: group.kitchenCounterName,
        kitchenName: group.kitchenName,
        quantity: first.quantity,
        total: first.total,
        indexLabel: 'Kitchen ${index + 1} of $total',
        modifiers: first.modifiers,
        groupedItems: groupedItems,
      ),
    );
  }

  return units;
}

List<TokenPrintItem> expandTokenPrintItemsPerItem(
  OfflinePrintOrder order,
  PosTokenSettings tokenSettings,
) {
  final units = <TokenPrintItem>[];
  final total = tokenSettings.perQuantity
      ? order.items.fold<int>(0, (sum, item) => sum + item.quantity)
      : order.items.length;

  var index = 0;
  for (final line in order.items) {
    final unitTotal = line.quantity > 0
        ? line.total / line.quantity
        : line.total;
    if (tokenSettings.perQuantity) {
      for (var q = 0; q < line.quantity; q++) {
        index++;
        units.add(
          TokenPrintItem(
            name: line.name,
            variantName: line.variantName,
            kitchenCounterName: line.kitchenCounterName,
            kitchenName: line.kitchenName,
            quantity: 1,
            total: unitTotal,
            indexLabel: 'Item $index of $total',
            modifiers: line.modifiers,
          ),
        );
      }
    } else {
      index++;
      units.add(
        TokenPrintItem(
          name: line.name,
          variantName: line.variantName,
          kitchenCounterName: line.kitchenCounterName,
          kitchenName: line.kitchenName,
          quantity: line.quantity,
          total: line.total,
          indexLabel: 'Item $index of $total',
          modifiers: line.modifiers,
        ),
      );
    }
  }

  return units;
}

TokenPrintItem _tokenLineFromOrderItem(OfflinePrintItem line) {
  return TokenPrintItem(
    name: line.name,
    variantName: line.variantName,
    kitchenCounterName: line.kitchenCounterName,
    kitchenName: line.kitchenName,
    quantity: line.quantity,
    total: line.total,
    indexLabel: '',
    modifiers: line.modifiers,
  );
}

class _TokenKitchenGroup {
  _TokenKitchenGroup({
    this.kitchenId,
    this.kitchenName,
    this.kitchenCounterName,
  });

  final int? kitchenId;
  final String? kitchenName;
  final String? kitchenCounterName;
  final List<TokenPrintItem> items = [];
}
