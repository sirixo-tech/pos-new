import 'package:flutter/material.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/kitchen_models.dart';
import '../../theme/pos_theme.dart';
import '../../utils/kitchen_board.dart';

/// Shared lane styling for kitchen / KOT views.
class KitchenLaneStyle {
  const KitchenLaneStyle({
    required this.color,
    required this.icon,
  });

  final Color color;
  final IconData icon;
}

KitchenLaneStyle kitchenLaneStyle(String laneKey, BuildContext context) {
  return switch (laneKey) {
    'new' => KitchenLaneStyle(
        color: Colors.amber.shade700,
        icon: Icons.notifications_active_outlined,
      ),
    'confirmed' => KitchenLaneStyle(
        color: Colors.lightBlue.shade700,
        icon: Icons.format_list_numbered,
      ),
    'preparing' => KitchenLaneStyle(
        color: Colors.deepPurple.shade500,
        icon: Icons.local_fire_department_outlined,
      ),
    'ready' => KitchenLaneStyle(
        color: Colors.green.shade600,
        icon: Icons.restaurant_outlined,
      ),
    _ => KitchenLaneStyle(
        color: Theme.of(context).colorScheme.primary,
        icon: Icons.receipt_long_outlined,
      ),
  };
}

String kitchenLaneTitle(BuildContext context, KitchenLane lane) =>
    kitchenLaneTitleForKey(context, lane.key);

String kitchenLaneTitleForKey(BuildContext context, String laneKey) {
  final key = switch (laneKey) {
    'new' => 'kitchenColNew',
    'confirmed' => 'kitchenColQueued',
    'preparing' => 'kitchenColCooking',
    'ready' => 'kitchenColReady',
    _ => 'kitchenColNew',
  };
  return context.posText(key, laneKey);
}

String kitchenLaneActionLabel(
  BuildContext context,
  KitchenLane lane, {
  required bool queueRequired,
  required String orderStatus,
}) {
  return context.posText(
    lane.actionKey,
    switch (lane.actionKey) {
      'kitchenActionAccept' => 'Accept',
      'kitchenActionSkipToPrep' => 'Start cooking now',
      'kitchenActionStartPrep' => 'Start cooking',
      'kitchenActionMarkReady' => 'Food is ready',
      'kitchenActionDone' => 'Delivered',
      'kitchenActionMoveToReady' => 'Food is ready',
      'kitchenActionMarkDone' => 'Done',
      _ => 'Next',
    },
  );
}

bool kitchenShowsMarkAsReady(KitchenLane lane, KitchenBoardOrder order) {
  final status = order.status;
  if (status == 'ready' || status == 'delivered' || status == 'cancelled') {
    return false;
  }
  if (lane.key == 'ready' || lane.nextStatus == 'ready') {
    return false;
  }
  return true;
}

bool kitchenShowsMarkDone(KitchenLane lane, KitchenBoardOrder order) {
  final status = order.status;
  if (status == 'delivered' || status == 'cancelled') {
    return false;
  }
  if (lane.key == 'ready' || lane.nextStatus == 'delivered') {
    return false;
  }
  return true;
}

String kitchenMoveToReadyLabel(BuildContext context) =>
    context.posText('kitchenActionMoveToReady', 'Food is ready');

String kitchenMarkDoneLabel(BuildContext context) =>
    context.posText('kitchenActionMarkDone', 'Done');

Color kitchenOrderTypeColor(String? type) {
  if (PosTheme.isDark) {
    return switch (type) {
      'dine_in' => const Color(0xFFC4B5FD),
      'delivery' => const Color(0xFFFDBA74),
      'takeaway' || 'pickup' => const Color(0xFF7DD3FC),
      _ => const Color(0xFFCBD5E1),
    };
  }
  return switch (type) {
    'dine_in' => Colors.deepPurple.shade700,
    'delivery' => Colors.orange.shade700,
    'takeaway' || 'pickup' => Colors.lightBlue.shade700,
    _ => Colors.blueGrey.shade800,
  };
}

IconData kitchenOrderTypeIcon(String? type) => switch (type) {
      'dine_in' => Icons.table_restaurant_rounded,
      'delivery' => Icons.delivery_dining_rounded,
      'takeaway' || 'pickup' => Icons.shopping_bag_outlined,
      _ => Icons.receipt_long_rounded,
    };

String kitchenOrderTypeLabel(BuildContext context, String? type) =>
    switch (type) {
      'dine_in' => context.posText('kitchenTypeDineIn', 'Dine in'),
      'delivery' => context.posText('kitchenTypeDelivery', 'Delivery'),
      'takeaway' || 'pickup' =>
        context.posText('kitchenTypeTakeaway', 'Takeaway'),
      _ => context.posText('kitchenTitle', 'Kitchen'),
    };

String kitchenChannelLabel(BuildContext context, String channel) {
  return switch (channel) {
    'pos' => context.posText('kitchenChannelPos', 'POS'),
    'kiosk' => context.posText('kitchenChannelKiosk', 'Kiosk'),
    'online' || 'web' || 'website' =>
      context.posText('kitchenChannelOnline', 'Online'),
    'delivery' => context.posText('kitchenTypeDelivery', 'Delivery'),
    'captain' || 'waiter' =>
      context.posText('kitchenChannelCaptain', 'Captain'),
    'app' || 'mobile' => context.posText('kitchenChannelApp', 'App'),
    'zomato' => context.posText('ordersFilterZomato', 'Zomato'),
    'swiggy' => context.posText('ordersFilterSwiggy', 'Swiggy'),
    _ => _prettyChannel(channel),
  };
}

IconData kitchenChannelIcon(String channel) => switch (channel) {
      'pos' => Icons.point_of_sale_rounded,
      'kiosk' => Icons.tablet_mac_rounded,
      'online' || 'web' || 'website' => Icons.language_rounded,
      'delivery' || 'zomato' || 'swiggy' => Icons.delivery_dining_rounded,
      'captain' || 'waiter' => Icons.badge_outlined,
      'app' || 'mobile' => Icons.phone_iphone_rounded,
      _ => Icons.storefront_outlined,
    };

Color kitchenChannelColor(String channel) {
  if (PosTheme.isDark) {
    return switch (channel) {
      'pos' => const Color(0xFFCBD5E1),
      'kiosk' => const Color(0xFF5EEAD4),
      'online' || 'web' || 'website' => const Color(0xFFA5B4FC),
      'delivery' => const Color(0xFFFDBA74),
      'captain' || 'waiter' => const Color(0xFFFDE68A),
      'app' || 'mobile' => const Color(0xFFC4B5FD),
      'zomato' => const Color(0xFFFCA5A5),
      'swiggy' => const Color(0xFFFDBA74),
      _ => const Color(0xFFCBD5E1),
    };
  }
  return switch (channel) {
      'pos' => const Color(0xFF334155),
      'kiosk' => Colors.teal.shade700,
      'online' || 'web' || 'website' => Colors.indigo.shade600,
      'delivery' => Colors.orange.shade700,
      'captain' || 'waiter' => Colors.amber.shade800,
      'app' || 'mobile' => Colors.deepPurple.shade600,
      'zomato' => const Color(0xFFE23744),
      'swiggy' => const Color(0xFFFC8019),
      _ => Colors.blueGrey.shade700,
  };
}

String _prettyChannel(String channel) {
  final pretty = channel.replaceAll('_', ' ').trim();
  if (pretty.isEmpty) return channel;
  return pretty[0].toUpperCase() + pretty.substring(1);
}

String? kitchenOrderTable(KitchenBoardOrder order) {
  final table = order.tableName?.trim();
  if (table != null && table.isNotEmpty) return table;
  return null;
}

String? kitchenOrderToken(KitchenBoardOrder order) {
  final token = order.token?.trim();
  if (token != null && token.isNotEmpty) return token;
  return null;
}

String kitchenOrderIdentity(KitchenBoardOrder order) {
  return kitchenOrderTable(order) ??
      kitchenOrderToken(order) ??
      order.orderNumber;
}

String kitchenElapsedLabel(
  BuildContext context,
  KitchenBoardOrder order, {
  required String laneKey,
}) {
  final base = laneKey == 'preparing'
      ? (order.preparingStartedAt ?? order.createdAt)
      : order.createdAt;
  if (base == null) return '';
  final mins = DateTime.now().difference(base).inMinutes;
  if (mins < 1) {
    return context.posText('kitchenElapsedNow', 'Just now');
  }
  return context.posText('kitchenElapsed', '{minutes}m', {'minutes': mins});
}

/// Card background tint based on kitchen lane.
Color kitchenLaneCardBackground(String laneKey) {
  final tint = _kitchenLaneTint(laneKey);
  if (tint == null) return PosTheme.surface;
  if (PosTheme.isDark) {
    return Color.lerp(PosTheme.surface, tint, 0.22)!;
  }
  return switch (laneKey) {
    'ready' => Colors.green.shade50,
    'preparing' => const Color(0xFFF5F3FF),
    'confirmed' => const Color(0xFFF0F9FF),
    'new' => const Color(0xFFFFFBEB),
    _ => PosTheme.surface,
  };
}

Color kitchenLaneCardBorder(
  String laneKey, {
  required bool urgent,
}) {
  if (urgent) {
    return PosTheme.isDark ? const Color(0xFFF87171) : Colors.red.shade400;
  }
  final tint = _kitchenLaneTint(laneKey);
  if (tint == null) return PosTheme.border;
  if (PosTheme.isDark) {
    return tint.withValues(alpha: 0.48);
  }
  return switch (laneKey) {
    'ready' => Colors.green.shade300,
    'preparing' => Colors.deepPurple.shade200,
    'confirmed' => Colors.lightBlue.shade200,
    'new' => Colors.amber.shade300,
    _ => PosTheme.border,
  };
}

Color? _kitchenLaneTint(String laneKey) {
  return switch (laneKey) {
    'ready' => Colors.green.shade600,
    'preparing' => Colors.deepPurple.shade400,
    'confirmed' => Colors.lightBlue.shade600,
    'new' => Colors.amber.shade700,
    _ => null,
  };
}

/// White / muted plate behind status pills and elapsed chips.
Color kitchenChipPlate({required bool filled, Color? fill}) {
  if (filled && fill != null) return fill;
  return PosTheme.isDark ? PosTheme.surfaceMuted : Colors.white;
}

Color kitchenChipOnPlate({required bool filled, required Color color}) {
  if (!filled) {
    return PosTheme.isDark ? posAccentSoft(color).fg : color;
  }
  return posOnColor(color);
}

({Color bg, Color border, Color fg}) kitchenCalloutColors({
  bool danger = false,
}) {
  final tone = posStatusColors(danger ? 'cancelled' : 'pending');
  return (
    bg: tone.bg,
    border: tone.fg.withValues(alpha: PosTheme.isDark ? 0.38 : 0.45),
    fg: tone.fg,
  );
}

ButtonStyle kitchenReadyOutlineStyle({
  required bool compact,
  Size? minimumSize,
}) {
  final tone = posStatusColors('ready');
  return OutlinedButton.styleFrom(
    foregroundColor: tone.fg,
    side: BorderSide(color: tone.fg.withValues(alpha: 0.45)),
    backgroundColor: tone.bg,
    minimumSize: minimumSize ?? Size(0, compact ? 36 : 40),
    padding: EdgeInsets.symmetric(
      horizontal: 10,
      vertical: compact ? 8 : 10,
    ),
    visualDensity: VisualDensity.compact,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    textStyle: TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 11 : 12,
    ),
  );
}
