import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the optional "set POS PIN" prompt was dismissed for a user.
class PosPinPromptStorage {
  static String _key(int userId) => 'pos_pin_prompt_dismissed_$userId';

  static Future<bool> isDismissed(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  static Future<void> dismiss(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }

  static Future<void> clearDismissed(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
