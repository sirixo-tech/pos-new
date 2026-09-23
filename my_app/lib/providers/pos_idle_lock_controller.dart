import 'package:flutter/foundation.dart';

import '../services/pos_storage.dart';

/// Persisted preference for idle / background auto-lock on this register.
class PosIdleLockController extends ChangeNotifier {
  PosIdleLockController({PosStorage? storage})
      : _storage = storage ?? PosStorage();

  final PosStorage _storage;
  bool _enabled = false;
  bool _ready = false;

  bool get enabled => _enabled;
  bool get ready => _ready;

  Future<void> load() async {
    _enabled = await _storage.getAutoLockEnabled();
    _ready = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled == _enabled) return;
    _enabled = enabled;
    notifyListeners();
    await _storage.saveAutoLockEnabled(enabled);
  }
}
