import '../models/kitchen_models.dart';

const kitchenPollInterval = Duration(seconds: 8);
const kitchenUrgentMinutes = 10;

const kitchenTrackedStatuses = ['pending', 'confirmed', 'preparing', 'ready'];
const kitchenTerminalStatuses = ['delivered', 'cancelled'];

class KitchenLane {
  const KitchenLane({
    required this.key,
    required this.sources,
    required this.nextStatus,
    required this.actionKey,
    this.skipStatus,
    this.skipActionKey,
  });

  final String key;
  final List<String> sources;
  final String nextStatus;
  final String actionKey;
  final String? skipStatus;
  final String? skipActionKey;
}

const kitchenLanes = [
  KitchenLane(
    key: 'new',
    sources: ['pending', 'confirmed'],
    nextStatus: 'preparing',
    actionKey: 'kitchenActionStartPrep',
  ),
  KitchenLane(
    key: 'preparing',
    sources: ['preparing'],
    nextStatus: 'ready',
    actionKey: 'kitchenActionMarkReady',
  ),
  KitchenLane(
    key: 'ready',
    sources: ['ready'],
    nextStatus: 'delivered',
    actionKey: 'kitchenActionDone',
  ),
];

const kitchenQueueLanes = [
  KitchenLane(
    key: 'new',
    sources: ['pending'],
    nextStatus: 'confirmed',
    actionKey: 'kitchenActionAccept',
    skipStatus: 'preparing',
    skipActionKey: 'kitchenActionSkipToPrep',
  ),
  KitchenLane(
    key: 'confirmed',
    sources: ['confirmed'],
    nextStatus: 'preparing',
    actionKey: 'kitchenActionStartPrep',
  ),
  KitchenLane(
    key: 'preparing',
    sources: ['preparing'],
    nextStatus: 'ready',
    actionKey: 'kitchenActionMarkReady',
  ),
  KitchenLane(
    key: 'ready',
    sources: ['ready'],
    nextStatus: 'delivered',
    actionKey: 'kitchenActionDone',
  ),
];

List<KitchenLane> kitchenLanesFor(bool queueRequired) =>
    queueRequired ? kitchenQueueLanes : kitchenLanes;

String kitchenBoardCardKey(KitchenBoardOrder order) {
  if (order.kitchenTicketId > 0) {
    return 't:${order.kitchenTicketId}';
  }
  return 'o:${order.id}';
}

KitchenBoard emptyKitchenBoard() => const KitchenBoard(
      pending: [],
      confirmed: [],
      preparing: [],
      ready: [],
    );

KitchenBoard parseKitchenBoard(Map<String, dynamic>? raw) {
  if (raw == null) return emptyKitchenBoard();
  List<KitchenBoardOrder> listFor(String key) {
    final items = raw[key];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => KitchenBoardOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  return KitchenBoard(
    pending: listFor('pending'),
    confirmed: listFor('confirmed'),
    preparing: listFor('preparing'),
    ready: listFor('ready'),
  );
}

enum KitchenTicketSort { oldest, newest, priority }

int compareKitchenOrders(
  KitchenBoardOrder a,
  KitchenBoardOrder b, {
  KitchenTicketSort sort = KitchenTicketSort.priority,
}) {
  if (sort == KitchenTicketSort.priority) {
    final priority = b.kitchenPriority.compareTo(a.kitchenPriority);
    if (priority != 0) return priority;
  }

  final aCreated = a.createdAt?.millisecondsSinceEpoch ?? 0;
  final bCreated = b.createdAt?.millisecondsSinceEpoch ?? 0;
  final time = sort == KitchenTicketSort.newest
      ? bCreated.compareTo(aCreated)
      : aCreated.compareTo(bCreated);
  if (time != 0) return time;

  final round = a.kotRound.compareTo(b.kotRound);
  if (round != 0) {
    return sort == KitchenTicketSort.newest ? -round : round;
  }
  return a.kitchenTicketId.compareTo(b.kitchenTicketId);
}

List<KitchenBoardOrder> sortKitchenOrders(
  List<KitchenBoardOrder> orders, {
  KitchenTicketSort sort = KitchenTicketSort.priority,
}) {
  final copy = [...orders];
  copy.sort((a, b) => compareKitchenOrders(a, b, sort: sort));
  return copy;
}

Map<String, List<KitchenBoardOrder>> bucketBoardToLanes(
  KitchenBoard board,
  bool queueRequired, {
  KitchenTicketSort sort = KitchenTicketSort.priority,
}) {
  final lanes = <String, List<KitchenBoardOrder>>{};
  for (final lane in kitchenLanesFor(queueRequired)) {
    final merged = <KitchenBoardOrder>[];
    for (final status in lane.sources) {
      merged.addAll(board.forStatus(status));
    }
    lanes[lane.key] = sortKitchenOrders(merged, sort: sort);
  }
  return lanes;
}

KitchenBoard relocateKitchenOrder(
  KitchenBoard board,
  KitchenBoardOrder target,
  String toStatus, {
  List<KitchenBoardItem>? items,
}) {
  final next = KitchenBoard(
    pending: [...board.pending],
    confirmed: [...board.confirmed],
    preparing: [...board.preparing],
    ready: [...board.ready],
  );

  KitchenBoardOrder? moved;
  for (final status in kitchenTrackedStatuses) {
    final list = next.forStatus(status);
    final idx = list.indexWhere((o) => o.matches(target));
    if (idx != -1) {
      moved = list[idx].copyWith(status: toStatus, items: items);
      list.removeAt(idx);
      break;
    }
  }

  if (moved == null || kitchenTerminalStatuses.contains(toStatus)) {
    return next;
  }

  next.forStatus(toStatus).add(moved);
  return KitchenBoard(
    pending: sortKitchenOrders(next.pending),
    confirmed: sortKitchenOrders(next.confirmed),
    preparing: sortKitchenOrders(next.preparing),
    ready: sortKitchenOrders(next.ready),
  );
}

KitchenBoard patchKitchenBoardOrder(
  KitchenBoard board,
  KitchenBoardOrder target, {
  String? status,
  List<KitchenBoardItem>? items,
}) {
  KitchenBoardOrder? current;
  for (final lane in kitchenTrackedStatuses) {
    for (final order in board.forStatus(lane)) {
      if (order.matches(target)) {
        current = order;
        break;
      }
    }
  }
  if (current == null) return board;

  final nextStatus = status ?? current.status;
  final nextItems = items ?? current.items;
  if (nextStatus == current.status) {
    final next = KitchenBoard(
      pending: [...board.pending],
      confirmed: [...board.confirmed],
      preparing: [...board.preparing],
      ready: [...board.ready],
    );
    for (final lane in kitchenTrackedStatuses) {
      final list = next.forStatus(lane);
      final idx = list.indexWhere((o) => o.matches(target));
      if (idx != -1) {
        list[idx] = current.copyWith(status: nextStatus, items: nextItems);
        break;
      }
    }
    return next;
  }

  return relocateKitchenOrder(board, target, nextStatus, items: nextItems);
}

String aggregateKitchenTicketStatus(List<KitchenBoardItem> items) {
  if (items.isEmpty) return 'pending';
  final statuses = items
      .map((item) => (item.kitchenStatus ?? 'pending').trim())
      .map((status) => status.isEmpty ? 'pending' : status)
      .toList();

  if (statuses.every((status) => status == 'cancelled')) return 'cancelled';
  if (statuses.every((status) => status == 'delivered')) return 'delivered';

  final active = statuses
      .where((status) => kitchenTrackedStatuses.contains(status))
      .toList();
  if (active.isEmpty) {
    return statuses.contains('delivered') ? 'delivered' : 'cancelled';
  }
  if (active.every((status) => status == 'ready')) return 'ready';
  if (active.contains('ready') || active.contains('preparing')) {
    return 'preparing';
  }
  if (active.contains('confirmed')) return 'confirmed';
  return 'pending';
}

KitchenBoard applyKitchenItemStatus(
  KitchenBoard board,
  KitchenBoardOrder order,
  KitchenBoardItem item,
  String status,
) {
  final nextItems = order.items
      .map((line) => line.id == item.id ? line.copyWith(kitchenStatus: status) : line)
      .toList();
  final ticketStatus = aggregateKitchenTicketStatus(nextItems);
  return patchKitchenBoardOrder(
    board,
    order,
    status: ticketStatus,
    items: nextItems,
  );
}

/// Row tap cycle: queued → cooking → ready → cooking (undo).
/// Delivered is a separate control; tapping a delivered line undoes to ready.
String nextKitchenItemStatus(String? status) {
  final current = (status ?? 'pending').trim();
  if (current == 'cancelled') {
    return current;
  }
  if (current == 'delivered') {
    return 'ready';
  }
  if (current == 'ready') {
    return 'preparing';
  }
  if (current == 'preparing') {
    return 'ready';
  }
  return 'preparing';
}

bool isKitchenOrderUrgent(KitchenBoardOrder order, {required bool inPreparingLane}) {
  final base = inPreparingLane
      ? (order.preparingStartedAt ?? order.createdAt)
      : order.createdAt;
  if (base == null) return false;
  return DateTime.now().difference(base).inMinutes >= kitchenUrgentMinutes;
}

/// One kitchen ticket in the register dock list (order + its lane metadata).
class KitchenDockEntry {
  const KitchenDockEntry({required this.order, required this.lane});

  final KitchenBoardOrder order;
  final KitchenLane lane;
}

/// Flatten lane buckets into one cashier-friendly list.
/// Sort is global (not grouped by status) so the register can work a single queue.
List<KitchenDockEntry> kitchenDockEntries(
  Map<String, List<KitchenBoardOrder>> lanes,
  bool queueRequired, {
  KitchenTicketSort sort = KitchenTicketSort.priority,
}) {
  final laneDefs = kitchenLanesFor(queueRequired);
  final entries = <KitchenDockEntry>[];
  for (final lane in laneDefs) {
    for (final order in lanes[lane.key] ?? const []) {
      entries.add(KitchenDockEntry(order: order, lane: lane));
    }
  }
  entries.sort((a, b) => compareKitchenOrders(a.order, b.order, sort: sort));
  return entries;
}

String kitchenItemsPreview(
  KitchenBoardOrder order, {
  int maxItems = 3,
}) {
  if (order.items.isEmpty) return '';
  final visible = order.items.take(maxItems);
  final parts = visible
      .map((item) => '${item.quantity}× ${item.name}')
      .toList();
  final remaining = order.items.length - visible.length;
  if (remaining > 0) {
    parts.add('+$remaining');
  }
  return parts.join(' · ');
}

const kitchenCoreChannels = ['pos', 'kiosk', 'online'];

const kitchenKotFilterKeys = [
  'all',
  'online',
  'pos',
  'kiosk',
  'dine_in',
  'pickup',
  'delivery',
];

String kitchenOrderChannelKey(KitchenBoardOrder order) {
  final raw = (order.source ?? '').trim().toLowerCase();
  if (raw.isEmpty) return 'pos';
  if (raw == 'website' || raw == 'web') return 'online';
  if (raw == 'captain' || raw == 'waiter' || raw == 'waiter_app') {
    return 'captain';
  }
  if (raw == 'app' || raw == 'mobile' || raw == 'mobile_app') return 'app';
  return raw;
}

/// Origin chip next to dine-in / takeaway. Hidden only when source is the
/// same fulfillment type (so "Delivery" is not printed twice).
bool kitchenShouldShowSourceTag(KitchenBoardOrder order) {
  final source = kitchenOrderChannelKey(order);
  final type = kitchenOrderTypeKey(order);
  const fulfillment = {'dine_in', 'pickup', 'takeaway', 'delivery'};
  if (fulfillment.contains(source) &&
      (source == type || (source == 'takeaway' && type == 'pickup'))) {
    return false;
  }
  return source.isNotEmpty;
}

String kitchenOrderTypeKey(KitchenBoardOrder order) {
  final raw = (order.type ?? '').trim().toLowerCase();
  if (raw == 'dine_in' || raw == 'dine-in' || raw == 'dinein') return 'dine_in';
  if (raw == 'takeaway' ||
      raw == 'take_away' ||
      raw == 'take-away' ||
      raw == 'pickup' ||
      raw == 'pick_up') {
    return 'pickup';
  }
  if (raw == 'delivery') return 'delivery';
  return raw;
}

bool kitchenOrderMatchesChannel(KitchenBoardOrder order, String? channel) {
  if (channel == null || channel.isEmpty || channel == 'all') return true;
  if (channel == 'dine_in' || channel == 'pickup' || channel == 'delivery') {
    return kitchenOrderTypeKey(order) == channel;
  }
  final source = kitchenOrderChannelKey(order);
  if (channel == 'online') {
    return source == 'online' || source == 'zomato' || source == 'swiggy';
  }
  return source == channel;
}

List<KitchenBoardOrder> kitchenOrdersMatchingChannel(
  Iterable<KitchenBoardOrder> orders,
  String? channel,
) {
  if (channel == null || channel.isEmpty) {
    return orders.toList();
  }
  return orders.where((order) => kitchenOrderMatchesChannel(order, channel)).toList();
}

/// POS / kiosk / online first, then any other sources currently on the board.
List<String> kitchenChannelOptions(Iterable<KitchenBoardOrder> orders) {
  final seen = <String>{};
  for (final order in orders) {
    seen.add(kitchenOrderChannelKey(order));
  }
  final extras = seen.where((key) => !kitchenCoreChannels.contains(key)).toList()
    ..sort();
  return [...kitchenCoreChannels, ...extras];
}

int kitchenChannelCount(Iterable<KitchenBoardOrder> orders, String channel) {
  var count = 0;
  for (final order in orders) {
    if (kitchenOrderChannelKey(order) == channel) count++;
  }
  return count;
}

int kitchenKotFilterCount(Iterable<KitchenBoardOrder> orders, String key) {
  var count = 0;
  for (final order in orders) {
    if (kitchenOrderMatchesChannel(order, key)) count++;
  }
  return count;
}
