import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kotResetTimeKey = 'kot_reset_time';

class KotResetTimeSettings {
  KotResetTimeSettings._();

  static const defaultTime = TimeOfDay(hour: 4, minute: 0);

  static Future<TimeOfDay> read() async {
    final prefs = await SharedPreferences.getInstance();
    return parseHhmm(prefs.getString(_kotResetTimeKey));
  }

  static Future<void> save(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kotResetTimeKey, formatHhmm(time));
  }

  static TimeOfDay parseHhmm(String? value) {
    final parts = (value ?? '').split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return defaultTime;
  }

  static String formatHhmm(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String label(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Orders created strictly before this instant are hidden on the KDS.
  static DateTime cutoff(TimeOfDay resetTime, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = DateTime(
      clock.year,
      clock.month,
      clock.day,
      resetTime.hour,
      resetTime.minute,
    );
    if (clock.isBefore(today)) {
      return today.subtract(const Duration(days: 1));
    }
    return today;
  }
}
