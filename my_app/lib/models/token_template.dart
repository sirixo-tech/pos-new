class TokenTemplateBlock {
  TokenTemplateBlock({
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

  factory TokenTemplateBlock.fromJson(Map<String, dynamic> json) {
    return TokenTemplateBlock(
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
      lines: _normalizeTokenSpaceLines(json['lines']),
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

int _normalizeTokenSpaceLines(Object? lines) {
  final value = lines is int ? lines : int.tryParse('$lines') ?? 1;
  if (value < 1) {
    return 1;
  }
  if (value > 5) {
    return 5;
  }
  return value;
}

class TokenTemplate {
  TokenTemplate({
    required this.version,
    required this.blocks,
  });

  final int version;
  final List<TokenTemplateBlock> blocks;

  static List<TokenTemplateBlock> get defaultBlocks => [
        TokenTemplateBlock(type: 'logo', toggle: 'show_logo', align: 'center'),
        TokenTemplateBlock(
          type: 'field',
          bind: 'restaurant.name',
          toggle: 'show_restaurant_name',
          style: 'title',
          align: 'center',
        ),
        TokenTemplateBlock(
          type: 'text',
          bind: 'settings.header_line',
          align: 'center',
          whenEmpty: 'hide',
        ),
        TokenTemplateBlock(
          type: 'field',
          bind: 'order.token',
          label: 'TOKEN #',
          style: 'large_bold',
          align: 'center',
          whenEmpty: 'hide',
        ),
        TokenTemplateBlock(
          type: 'field',
          bind: 'order.order_number',
          label: 'Bill No: ',
          style: 'bold',
          align: 'left',
        ),
        TokenTemplateBlock(
          type: 'field',
          bind: 'order.type',
          format: 'order_type',
          toggle: 'show_order_type',
          style: 'bold',
          align: 'left',
          whenEmpty: 'hide',
        ),
        TokenTemplateBlock(
          type: 'field',
          bind: 'order.created_at',
          format: 'datetime',
          label: 'Date: ',
          toggle: 'show_datetime',
          align: 'left',
          whenEmpty: 'hide',
        ),
        TokenTemplateBlock(type: 'divider'),
        TokenTemplateBlock(
          type: 'item_line',
          toggle: 'show_item_modifiers',
          showModifiers: true,
          showHeaders: true,
          align: 'left',
        ),
        TokenTemplateBlock(type: 'divider'),
        TokenTemplateBlock(
          type: 'field',
          bind: 'item.index_label',
          toggle: 'show_item_index',
          align: 'center',
          whenEmpty: 'hide',
        ),
        TokenTemplateBlock(
          type: 'text',
          bind: 'settings.footer_line',
          align: 'center',
          whenEmpty: 'hide',
        ),
        TokenTemplateBlock(
          type: 'field',
          bind: 'kitchen.counter_name',
          toggle: 'show_counter_name',
          style: 'title',
          align: 'center',
          whenEmpty: 'hide',
        ),
      ];

  Map<String, dynamic> toJson() => {
        'version': version,
        'blocks': blocks.map((block) => block.toJson()).toList(),
      };

  factory TokenTemplate.fromJson(Map<String, dynamic>? json) {
    final blocksJson = json?['blocks'];
    if (blocksJson is! List || blocksJson.isEmpty) {
      return TokenTemplate(version: 1, blocks: defaultBlocks);
    }

    final blocks = blocksJson
        .whereType<Map<String, dynamic>>()
        .map(TokenTemplateBlock.fromJson)
        .where((block) => block.type.isNotEmpty)
        .toList();

    final merged = blocks.isEmpty
        ? defaultBlocks
        : _normalizeKitchenCounterBlocks(
            _ensureTypeDatetimeBlock(_ensureHeaderBlocks(blocks)),
          );

    return TokenTemplate(
      version: json?['version'] as int? ?? 1,
      blocks: merged,
    );
  }

  static List<TokenTemplateBlock> _ensureTypeDatetimeBlock(
    List<TokenTemplateBlock> blocks,
  ) {
    final typeBlock = TokenTemplateBlock(
      type: 'field',
      bind: 'order.type',
      format: 'order_type',
      toggle: 'show_order_type',
      style: 'bold',
      align: 'left',
      whenEmpty: 'hide',
    );
    final datetimeBlock = TokenTemplateBlock(
      type: 'field',
      bind: 'order.created_at',
      format: 'datetime',
      toggle: 'show_datetime',
      align: 'left',
      whenEmpty: 'hide',
    );

    final out = <TokenTemplateBlock>[];
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

    final toInsert = <TokenTemplateBlock>[
      if (!hasType) typeBlock,
      if (!hasDatetime) datetimeBlock,
    ];

    return [
      ...out.take(insertAt),
      ...toInsert,
      ...out.skip(insertAt),
    ];
  }

  static List<TokenTemplateBlock> _ensureHeaderBlocks(
    List<TokenTemplateBlock> blocks,
  ) {
    final binds = blocks.map((b) => b.bind).whereType<String>().toSet();
    final types = blocks.map((b) => b.type).toSet();
    final prefix = <TokenTemplateBlock>[];

    for (final block in defaultBlocks.take(3)) {
      if (block.type == 'logo') {
        if (!types.contains('logo')) {
          prefix.add(block);
        }
        continue;
      }

      final bind = block.bind;
      if (bind != null && !binds.contains(bind)) {
        prefix.add(block);
      }
    }

    if (prefix.isEmpty) {
      return blocks;
    }

    return [...prefix, ...blocks];
  }

  static List<TokenTemplateBlock> _normalizeKitchenCounterBlocks(
    List<TokenTemplateBlock> blocks,
  ) {
    return blocks.map((block) {
      final bind = block.bind;
      if (bind == 'kitchen.counter_name' || bind == 'kitchen.name') {
        return TokenTemplateBlock(
          type: block.type,
          toggle: block.toggle ?? 'show_counter_name',
          align: block.align,
          bind: block.bind,
          value: block.value,
          style: block.style,
          format: block.format,
          whenEmpty: block.whenEmpty,
          showModifiers: block.showModifiers,
          showHeaders: block.showHeaders,
          enabled: block.enabled,
        );
      }
      return block;
    }).toList();
  }
}
