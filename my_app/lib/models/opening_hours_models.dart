import '../utils/json_parse.dart';

class PosGuestOrdering {
  const PosGuestOrdering({
    this.open = true,
    this.offlineReason,
    this.closedMessage = '',
    this.restaurantOpen = true,
    this.acceptOnlineOrders = true,
    this.nextOpensAt,
    this.nextOpensLabel,
    this.nextOpensIsToday = false,
  });

  final bool open;
  final String? offlineReason;
  final String closedMessage;
  final bool restaurantOpen;
  final bool acceptOnlineOrders;
  final String? nextOpensAt;
  final String? nextOpensLabel;
  final bool nextOpensIsToday;

  bool get isPaused => offlineReason == 'paused';
  bool get isOutsideHours => offlineReason == 'outside_hours';

  factory PosGuestOrdering.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PosGuestOrdering();
    return PosGuestOrdering(
      open: parseJsonBool(json['open'], fallback: true),
      offlineReason: json['offline_reason'] as String?,
      closedMessage: (json['closed_message'] as String?) ?? '',
      restaurantOpen: parseJsonBool(json['restaurant_open'], fallback: true),
      acceptOnlineOrders:
          parseJsonBool(json['accept_online_orders'], fallback: true),
      nextOpensAt: json['next_opens_at'] as String?,
      nextOpensLabel: json['next_opens_label'] as String?,
      nextOpensIsToday: parseJsonBool(json['next_opens_is_today']),
    );
  }

  PosGuestOrdering copyWith({
    bool? open,
    String? offlineReason,
    bool clearOfflineReason = false,
    String? closedMessage,
    bool? restaurantOpen,
    bool? acceptOnlineOrders,
    String? nextOpensAt,
    String? nextOpensLabel,
    bool? nextOpensIsToday,
  }) {
    return PosGuestOrdering(
      open: open ?? this.open,
      offlineReason:
          clearOfflineReason ? null : (offlineReason ?? this.offlineReason),
      closedMessage: closedMessage ?? this.closedMessage,
      restaurantOpen: restaurantOpen ?? this.restaurantOpen,
      acceptOnlineOrders: acceptOnlineOrders ?? this.acceptOnlineOrders,
      nextOpensAt: nextOpensAt ?? this.nextOpensAt,
      nextOpensLabel: nextOpensLabel ?? this.nextOpensLabel,
      nextOpensIsToday: nextOpensIsToday ?? this.nextOpensIsToday,
    );
  }
}

class PosOpeningHours {
  const PosOpeningHours({
    this.enabled = false,
    this.timezone = 'UTC',
    this.schedule = const {},
    this.closedMessage = '',
  });

  final bool enabled;
  final String timezone;
  final Map<String, List<String>> schedule;
  final String closedMessage;

  static const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  factory PosOpeningHours.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PosOpeningHours();
    final rawSchedule = json['schedule'];
    final schedule = <String, List<String>>{};
    if (rawSchedule is Map) {
      for (final day in days) {
        final ranges = rawSchedule[day];
        if (ranges is List) {
          schedule[day] = ranges
              .map((e) => '$e')
              .where((e) => e.contains('-'))
              .toList();
        } else {
          schedule[day] = const [];
        }
      }
    }
    return PosOpeningHours(
      enabled: parseJsonBool(json['enabled']),
      timezone: (json['timezone'] as String?)?.trim().isNotEmpty == true
          ? (json['timezone'] as String).trim()
          : 'UTC',
      schedule: schedule,
      closedMessage: (json['closed_message'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toApiSchedule() {
    final out = <String, dynamic>{};
    for (final day in days) {
      out[day] = List<String>.from(schedule[day] ?? const []);
    }
    return out;
  }

  PosOpeningHours copyWith({
    bool? enabled,
    String? timezone,
    Map<String, List<String>>? schedule,
    String? closedMessage,
  }) {
    return PosOpeningHours(
      enabled: enabled ?? this.enabled,
      timezone: timezone ?? this.timezone,
      schedule: schedule ?? this.schedule,
      closedMessage: closedMessage ?? this.closedMessage,
    );
  }
}

class PosOpeningHoursPayload {
  const PosOpeningHoursPayload({
    required this.acceptOnlineOrders,
    required this.openingHours,
    required this.guestOrdering,
    this.restaurantTimezone = 'UTC',
    this.timezones = const [],
  });

  final bool acceptOnlineOrders;
  final PosOpeningHours openingHours;
  final PosGuestOrdering guestOrdering;
  final String restaurantTimezone;
  final List<String> timezones;

  factory PosOpeningHoursPayload.fromJson(Map<String, dynamic> json) {
    return PosOpeningHoursPayload(
      acceptOnlineOrders:
          parseJsonBool(json['accept_online_orders'], fallback: true),
      openingHours: PosOpeningHours.fromJson(
        json['opening_hours'] as Map<String, dynamic>?,
      ),
      guestOrdering: PosGuestOrdering.fromJson(
        json['guest_ordering'] as Map<String, dynamic>?,
      ),
      restaurantTimezone:
          (json['restaurant_timezone'] as String?)?.trim().isNotEmpty == true
              ? (json['restaurant_timezone'] as String).trim()
              : 'UTC',
      timezones: (json['timezones'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}
