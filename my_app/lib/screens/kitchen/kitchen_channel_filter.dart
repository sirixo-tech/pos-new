import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/kitchen_models.dart';
import '../../providers/kitchen_kot_filter_order.dart';
import '../../providers/pos_controller.dart';
import '../../theme/pos_theme.dart';
import '../../utils/kitchen_board.dart';
import 'kitchen_theme.dart';

const _allChannel = '__all__';

class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  const _MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.mouse,
      };
}

/// Horizontal filter row with mouse-drag scrolling and overflow chevrons.
class KitchenFilterCarousel extends StatefulWidget {
  const KitchenFilterCarousel({
    super.key,
    required this.child,
    this.compact = false,
  });

  final Widget child;
  final bool compact;

  @override
  State<KitchenFilterCarousel> createState() => _KitchenFilterCarouselState();
}

class _KitchenFilterCarouselState extends State<KitchenFilterCarousel> {
  final _controller = ScrollController();
  bool _showStart = false;
  bool _showEnd = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncChevrons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncChevrons());
  }

  @override
  void didUpdateWidget(covariant KitchenFilterCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncChevrons());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncChevrons);
    _controller.dispose();
    super.dispose();
  }

  void _syncChevrons() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final start = position.pixels > 4;
    final end = position.maxScrollExtent > 4 &&
        position.pixels < position.maxScrollExtent - 4;
    if (start == _showStart && end == _showEnd) return;
    setState(() {
      _showStart = start;
      _showEnd = end;
    });
  }

  Future<void> _nudge(bool forward) async {
    if (!_controller.hasClients) return;
    final delta = (widget.compact ? 140.0 : 180.0) * (forward ? 1 : -1);
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _chevron({required bool forward}) {
    return SizedBox(
      width: widget.compact ? 28 : 32,
      height: widget.compact ? 28 : 32,
      child: IconButton(
        tooltip: forward ? 'More filters' : 'Previous filters',
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: () {
          _nudge(forward);
        },
        icon: Icon(
          forward
              ? Icons.chevron_right_rounded
              : Icons.chevron_left_rounded,
          size: widget.compact ? 20 : 22,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        children: [
          if (_hovered && _showStart) _chevron(forward: false),
          Expanded(
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _syncChevrons());
                return false;
              },
              child: SizeChangedLayoutNotifier(
                child: ScrollConfiguration(
                  behavior: const _MouseDragScrollBehavior(),
                  child: SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
          if (_hovered && _showEnd) _chevron(forward: true),
        ],
      ),
    );
  }
}

class KitchenKotFilterChips extends StatelessWidget {
  const KitchenKotFilterChips({
    super.key,
    required this.orders,
    required this.selectedChannel,
    required this.onChanged,
    this.compact = false,
  });

  final List<KitchenBoardOrder> orders;
  final String? selectedChannel;
  final ValueChanged<String?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final allowDelivery =
        context.select((PosController p) => p.bootstrap?.allowsPosDelivery ?? true);
    final keys = context.watch<KitchenKotFilterOrder>().visibleKeys(
          allowDelivery: allowDelivery,
        );
    if (selectedChannel == 'delivery' && !allowDelivery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChanged(null);
      });
    }
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 5 : 6),
          _kotFilterChip(
            context,
            key: keys[i],
          ),
        ],
      ],
    );
  }

  Widget _kotFilterChip(BuildContext context, {required String key}) {
    final selected = key == 'all'
        ? selectedChannel == null || selectedChannel == 'all'
        : selectedChannel == key;
    final count = kitchenKotFilterCount(orders, key);
    final color = kitchenKotFilterColor(key);
    final label = kitchenKotFilterLabel(context, key);
    final tone = posTintedChip(color, selected: selected);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(key == 'all' ? null : key),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 10,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: tone.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tone.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 6 : 7,
                height: compact ? 6 : 7,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w800,
                  color: tone.fg,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    color: tone.fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class KitchenChannelMenu extends StatelessWidget {
  const KitchenChannelMenu({
    super.key,
    required this.orders,
    required this.selectedChannel,
    required this.onChanged,
    this.compact = false,
  });

  final List<KitchenBoardOrder> orders;
  final String? selectedChannel;
  final ValueChanged<String?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final channels = kitchenChannelOptions(orders);
    final selected = selectedChannel != null;
    final color = selected
        ? kitchenChannelColor(selectedChannel!)
        : PosTheme.ink;
    final label = selected
        ? kitchenChannelLabel(context, selectedChannel!)
        : context.posText('kitchenChannelLabel', 'Channel');

    return PopupMenuButton<String>(
      tooltip: context.posText('kitchenChannelLabel', 'Channel'),
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      onSelected: (value) =>
          onChanged(value == _allChannel ? null : value),
      itemBuilder: (context) => [
        _menuItem(
          value: _allChannel,
          label: context.posText('kitchenChannelAll', 'All'),
          count: orders.length,
          color: PosTheme.ink,
          selected: selectedChannel == null,
        ),
        for (final channel in channels)
          _menuItem(
            value: channel,
            label: kitchenChannelLabel(context, channel),
            count: kitchenChannelCount(orders, channel),
            color: kitchenChannelColor(channel),
            selected: selectedChannel == channel,
          ),
      ],
      child: _CompactSelectChip(
        label: label,
        color: color,
        compact: compact,
        active: selected,
      ),
    );
  }
}

class KitchenSortMenu extends StatelessWidget {
  const KitchenSortMenu({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final KitchenTicketSort selected;
  final ValueChanged<KitchenTicketSort> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final options = _sortOptions(context);
    final current = options.firstWhere((option) => option.sort == selected);

    return PopupMenuButton<KitchenTicketSort>(
      tooltip: context.posText('kitchenSortLabel', 'Sort'),
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options)
          _menuItem(
            value: option.sort,
            label: option.label,
            count: 0,
            color: option.color,
            selected: selected == option.sort,
          ),
      ],
      child: _CompactSelectChip(
        label: current.label,
        color: current.color,
        compact: compact,
        active: true,
      ),
    );
  }
}

class KitchenStationMenu extends StatelessWidget {
  const KitchenStationMenu({
    super.key,
    required this.stations,
    required this.selectedId,
    required this.onChanged,
    this.compact = false,
  });

  final List<KitchenStation> stations;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) return const SizedBox.shrink();

    final current =
        stations.where((station) => station.id == selectedId).firstOrNull;
    final selected = current != null;
    final label = current?.label ??
        context.posText('kitchenStationLabel', 'Station');

    return PopupMenuButton<String>(
      tooltip: context.posText('kitchenStationLabel', 'Station'),
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      onSelected: (value) =>
          onChanged(value == _allChannel ? null : int.tryParse(value)),
      itemBuilder: (context) => [
        _menuItem(
          value: _allChannel,
          label: context.posText('kitchenFilterAllStations', 'All stations'),
          count: 0,
          color: PosTheme.ink,
          selected: selectedId == null,
        ),
        for (final station in stations)
          _menuItem(
            value: '${station.id}',
            label: station.label,
            count: 0,
            color: Colors.teal.shade700,
            selected: selectedId == station.id,
          ),
      ],
      child: _CompactSelectChip(
        label: label,
        color: selected ? Colors.teal.shade700 : PosTheme.ink,
        compact: compact,
        active: selected,
      ),
    );
  }
}

List<({KitchenTicketSort sort, String label, Color color})> _sortOptions(
  BuildContext context,
) {
  return [
    (
      sort: KitchenTicketSort.oldest,
      label: context.posText('kitchenSortOldest', 'Oldest'),
      color: Colors.orange.shade700,
    ),
    (
      sort: KitchenTicketSort.newest,
      label: context.posText('kitchenSortNewest', 'Newest'),
      color: Colors.blue.shade700,
    ),
    (
      sort: KitchenTicketSort.priority,
      label: context.posText('kitchenSortPriority', 'Priority'),
      color: Colors.red.shade600,
    ),
  ];
}

PopupMenuItem<T> _menuItem<T>({
  required T value,
  required String label,
  required int count,
  required Color color,
  required bool selected,
}) {
  return PopupMenuItem<T>(
    value: value,
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        if (count > 0)
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        if (selected) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_rounded, size: 16, color: color),
        ],
      ],
    ),
  );
}

class _CompactSelectChip extends StatelessWidget {
  const _CompactSelectChip({
    required this.label,
    required this.color,
    required this.compact,
    required this.active,
  });

  final String label;
  final Color color;
  final bool compact;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tone = posTintedChip(color, selected: active);
    final bg = tone.bg;
    final border = tone.border;
    final fg = tone.fg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.fromLTRB(
        compact ? 7 : 10,
        compact ? 4 : 6,
        compact ? 4 : 6,
        compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: compact ? 14 : 16,
            color: fg,
          ),
        ],
      ),
    );
  }
}

Color kitchenKotFilterColor(String key) {
  return switch (key) {
    'dine_in' => const Color(0xFF7C3AED),
    'pickup' => const Color(0xFF059669),
    'kiosk' => const Color(0xFF0D9488),
    'online' => const Color(0xFF2563EB),
    'delivery' => const Color(0xFFFF6518),
    'pos' => const Color(0xFF475569),
    _ => const Color(0xFF64748B),
  };
}

IconData kitchenKotFilterIcon(String key) {
  return switch (key) {
    'all' => Icons.grid_view_rounded,
    'online' => Icons.language_rounded,
    'pos' => Icons.point_of_sale_rounded,
    'kiosk' => Icons.tablet_mac_rounded,
    'dine_in' => Icons.restaurant_rounded,
    'pickup' => Icons.takeout_dining_rounded,
    'delivery' => Icons.delivery_dining_rounded,
    _ => Icons.filter_alt_rounded,
  };
}

String kitchenKotFilterLabel(BuildContext context, String key) {
  return switch (key) {
    'all' => context.posText('kitchenChannelAll', 'All'),
    'online' => context.posText('kitchenChannelOnline', 'Online'),
    'pos' => context.posText('kitchenChannelPos', 'POS'),
    'kiosk' => context.posText('kitchenChannelKiosk', 'Kiosk'),
    'dine_in' => context.posText('kitchenTypeDineIn', 'Dine In'),
    'pickup' => context.posText('kitchenTypeTakeaway', 'Take away'),
    'delivery' => context.posText('kitchenTypeDelivery', 'Delivery'),
    _ => key,
  };
}

String kitchenKotFilterDescription(BuildContext context, String key) {
  return switch (key) {
    'all' => context.posText(
        'kotFilterDescAll',
        'All incoming orders across channels',
      ),
    'online' => context.posText(
        'kotFilterDescOnline',
        'Swiggy, Zomato and website orders',
      ),
    'pos' => context.posText(
        'kotFilterDescPos',
        'Cashier POS counter orders',
      ),
    'kiosk' => context.posText(
        'kotFilterDescKiosk',
        'Self-ordering kiosk tickets',
      ),
    'dine_in' => context.posText(
        'kotFilterDescDineIn',
        'Table service dine-in tickets',
      ),
    'pickup' => context.posText(
        'kotFilterDescPickup',
        'Takeaway and pickup tickets',
      ),
    'delivery' => context.posText(
        'kotFilterDescDelivery',
        'Delivery channel tickets',
      ),
    _ => key,
  };
}
