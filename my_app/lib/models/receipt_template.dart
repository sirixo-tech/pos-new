class ReceiptTemplateBlock {
  ReceiptTemplateBlock({
    required this.type,
    this.toggle,
    this.align = 'left',
    this.bind,
    this.label,
    this.value,
    this.style = 'normal',
    this.format,
    this.whenEmpty,
    this.showModifiers = true,
    this.showHeaders = true,
    this.lines = 1,
    this.enabled = true,
  });

  final String type;
  final String? toggle;
  final String align;
  final String? bind;
  final String? label;
  final String? value;
  final String style;
  final String? format;
  final String? whenEmpty;
  final bool showModifiers;
  final bool showHeaders;
  final int lines;
  final bool enabled;

  factory ReceiptTemplateBlock.fromJson(Map<String, dynamic> json) {
    return ReceiptTemplateBlock(
      type: json['type'] as String? ?? '',
      toggle: json['toggle'] as String?,
      align: json['align'] as String? ?? 'left',
      bind: json['bind'] as String?,
      label: json['label'] as String?,
      value: json['value'] as String?,
      style: json['style'] as String? ?? 'normal',
      format: json['format'] as String?,
      whenEmpty: json['when_empty'] as String?,
      showModifiers: json['show_modifiers'] as bool? ?? true,
      showHeaders: json['show_headers'] as bool? ?? true,
      lines: _normalizeSpaceLines(json['lines']),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (toggle != null) 'toggle': toggle,
        'align': align,
        if (bind != null) 'bind': bind,
        if (label != null) 'label': label,
        if (value != null) 'value': value,
        'style': style,
        if (format != null) 'format': format,
        if (whenEmpty != null) 'when_empty': whenEmpty,
        'show_modifiers': showModifiers,
        'show_headers': showHeaders,
        'lines': lines,
        'enabled': enabled,
      };
}

int _normalizeSpaceLines(Object? lines) {
  final value = lines is int ? lines : int.tryParse('$lines') ?? 1;
  if (value < 1) {
    return 1;
  }
  if (value > 5) {
    return 5;
  }
  return value;
}

class ReceiptTemplate {
  ReceiptTemplate({
    required this.version,
    required this.blocks,
  });

  final int version;
  final List<ReceiptTemplateBlock> blocks;

  static List<ReceiptTemplateBlock> get defaultBlocks => [
        ReceiptTemplateBlock(type: 'logo', toggle: 'show_logo', align: 'center'),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'restaurant.name',
          toggle: 'show_restaurant_name',
          style: 'title',
          align: 'center',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'branch.name',
          toggle: 'show_branch_info',
          align: 'center',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'branch.address',
          toggle: 'show_branch_address',
          align: 'center',
          whenEmpty: 'hide',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'restaurant.tax_id',
          label: 'Tax ID: ',
          toggle: 'show_tax_id',
          align: 'center',
          whenEmpty: 'hide',
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
          label: 'TOKEN #',
          style: 'large_bold',
          align: 'center',
          whenEmpty: 'hide',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.order_number',
          label: 'Bill No: ',
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
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.created_at',
          format: 'datetime',
          label: 'Date: ',
          toggle: 'show_datetime',
          align: 'left',
          whenEmpty: 'hide',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.table_name',
          label: 'Table: ',
          toggle: 'show_table',
          align: 'left',
          whenEmpty: 'hide',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.customer_name',
          label: 'Customer: ',
          toggle: 'show_customer_name',
          align: 'left',
          whenEmpty: 'hide',
        ),
        ReceiptTemplateBlock(
          type: 'field',
          bind: 'order.notes',
          label: 'Note: ',
          toggle: 'show_order_notes',
          align: 'left',
          whenEmpty: 'hide',
        ),
        ReceiptTemplateBlock(
          type: 'line_items',
          showModifiers: true,
          showHeaders: true,
        ),
        ReceiptTemplateBlock(type: 'divider'),
        ReceiptTemplateBlock(type: 'totals'),
        ReceiptTemplateBlock(type: 'payment_status', align: 'center'),
        ReceiptTemplateBlock(
          type: 'text',
          value: 'Scan here to track order',
          align: 'center',
          style: 'bold',
        ),
        ReceiptTemplateBlock(
          type: 'qr_code',
          bind: 'order.tracking_url',
          align: 'center',
          whenEmpty: 'hide',
        ),
        ReceiptTemplateBlock(
          type: 'text',
          bind: 'settings.footer_line',
          align: 'center',
          whenEmpty: 'hide',
        ),
      ];

  Map<String, dynamic> toJson() => {
        'version': version,
        'blocks': blocks.map((block) => block.toJson()).toList(),
      };

  factory ReceiptTemplate.fromJson(Map<String, dynamic>? json) {
    final blocksJson = json?['blocks'];
    if (blocksJson is! List || blocksJson.isEmpty) {
      return ReceiptTemplate(version: 1, blocks: defaultBlocks);
    }

    final blocks = blocksJson
        .whereType<Map<String, dynamic>>()
        .map(ReceiptTemplateBlock.fromJson)
        .where((block) => block.type.isNotEmpty)
        .toList();

    final merged = blocks.isEmpty
        ? defaultBlocks
        : _ensureLineItemsSectionDividers(
            _ensureBranchAddressBlock(_ensureTypeDatetimeBlock(blocks)),
          );

    return ReceiptTemplate(
      version: json?['version'] as int? ?? 1,
      blocks: merged,
    );
  }

  static List<ReceiptTemplateBlock> _ensureLineItemsSectionDividers(
    List<ReceiptTemplateBlock> blocks,
  ) {
    // Headers draw their own top/bottom rules — drop a redundant divider above line items.
    return _insertDividerBeforeBlockType(
      _stripDividerBeforeLineItemsWithHeaders(blocks),
      'totals',
    );
  }

  static List<ReceiptTemplateBlock> _stripDividerBeforeLineItemsWithHeaders(
    List<ReceiptTemplateBlock> blocks,
  ) {
    final out = <ReceiptTemplateBlock>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final next = index + 1 < blocks.length ? blocks[index + 1] : null;
      if (block.type == 'divider' &&
          next?.type == 'line_items' &&
          next!.showHeaders) {
        continue;
      }
      out.add(block);
    }
    return out;
  }

  static List<ReceiptTemplateBlock> _insertDividerBeforeBlockType(
    List<ReceiptTemplateBlock> blocks,
    String type,
  ) {
    final index = blocks.indexWhere((block) => block.type == type);
    if (index <= 0) {
      return blocks;
    }

    if (blocks[index - 1].type == 'divider') {
      return blocks;
    }

    return [
      ...blocks.take(index),
      ReceiptTemplateBlock(type: 'divider'),
      ...blocks.skip(index),
    ];
  }

  static List<ReceiptTemplateBlock> _ensureBranchAddressBlock(
    List<ReceiptTemplateBlock> blocks,
  ) {
    if (blocks.any((block) => block.bind == 'branch.address')) {
      return blocks;
    }

    final insert = ReceiptTemplateBlock(
      type: 'field',
      bind: 'branch.address',
      toggle: 'show_branch_address',
      align: 'center',
      whenEmpty: 'hide',
    );

    final branchNameIndex =
        blocks.indexWhere((block) => block.bind == 'branch.name');
    if (branchNameIndex == -1) {
      return [insert, ...blocks];
    }

    return [
      ...blocks.take(branchNameIndex + 1),
      insert,
      ...blocks.skip(branchNameIndex + 1),
    ];
  }

  static List<ReceiptTemplateBlock> _ensureTypeDatetimeBlock(
    List<ReceiptTemplateBlock> blocks,
  ) {
    final typeBlock = ReceiptTemplateBlock(
      type: 'field',
      bind: 'order.type',
      format: 'order_type',
      toggle: 'show_order_type',
      style: 'bold',
      align: 'left',
      whenEmpty: 'hide',
    );
    final datetimeBlock = ReceiptTemplateBlock(
      type: 'field',
      bind: 'order.created_at',
      format: 'datetime',
      toggle: 'show_datetime',
      align: 'left',
      whenEmpty: 'hide',
    );

    final out = <ReceiptTemplateBlock>[];
    var hasType = false;
    var hasDatetime = false;
    int? combinedInsertAt;

    for (final block in blocks) {
      if (block.bind == 'order.type_and_datetime') {
        combinedInsertAt = out.length;
        out
          ..add(typeBlock)
          ..add(datetimeBlock);
        hasType = true;
        hasDatetime = true;
        continue;
      }

      if (block.bind == 'order.type') {
        hasType = true;
      }
      if (block.bind == 'order.created_at') {
        hasDatetime = true;
      }
      out.add(block);
    }

    if (hasType && hasDatetime) {
      return out;
    }

    var insertAt = combinedInsertAt ?? 0;
    if (combinedInsertAt == null) {
      final orderNumberIndex =
          out.indexWhere((block) => block.bind == 'order.order_number');
      insertAt = orderNumberIndex == -1 ? 0 : orderNumberIndex + 1;
    }

    final toInsert = <ReceiptTemplateBlock>[
      if (!hasType) typeBlock,
      if (!hasDatetime) datetimeBlock,
    ];

    return [
      ...out.take(insertAt),
      ...toInsert,
      ...out.skip(insertAt),
    ];
  }
}
