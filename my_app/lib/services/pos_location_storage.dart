import 'package:shared_preferences/shared_preferences.dart';

/// Last restaurant + branch chosen on this device for a staff user.
class PosLocationPreference {
  const PosLocationPreference({
    required this.restaurantId,
    required this.branchId,
  });

  final int restaurantId;
  final int branchId;
}

class PosLocationStorage {
  static String _key(String serverUrl, int userId) {
    final host = serverUrl.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
    return 'pos_location_${host.hashCode}_$userId';
  }

  static Future<PosLocationPreference?> read({
    required String serverUrl,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(serverUrl, userId));
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final restaurantId = int.tryParse(parts[0]);
    final branchId = int.tryParse(parts[1]);
    if (restaurantId == null || branchId == null) return null;
    return PosLocationPreference(
      restaurantId: restaurantId,
      branchId: branchId,
    );
  }

  static Future<void> write({
    required String serverUrl,
    required int userId,
    required int restaurantId,
    required int branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(serverUrl, userId),
      '$restaurantId:$branchId',
    );
  }

  static Future<void> clear({
    required String serverUrl,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(serverUrl, userId));
  }
}
