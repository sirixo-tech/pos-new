import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'payment_session.dart';

class PaymentSessionStore {
  static const _storageKey = 'pending_payment_sessions_v1';

  Future<List<PaymentSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .map(
            (value) => PaymentSession.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<void> saveAll(Iterable<PaymentSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );
  }
}
