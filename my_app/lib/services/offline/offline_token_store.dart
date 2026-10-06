import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/pos_models.dart';
import 'pos_database.dart';

/// Local high-water mark only. Never assigns or changes a server order token.
class OfflineTokenStore {
  OfflineTokenStore({Future<Database> Function()? database})
    : _database = database ?? (() => PosDatabase.instance.database);

  static final instance = OfflineTokenStore();
  final Future<Database> Function() _database;
  static Future<void> _webQueue = Future.value();

  static String scopeFor(PosSession session) =>
      '${session.serverUrl.replaceAll(RegExp(r'/+$'), '')}|${session.restaurantId}|${session.branchId}';

  static Future<void> createTable(DatabaseExecutor db) => db.execute('''
    CREATE TABLE IF NOT EXISTS offline_token_counters (
      scope TEXT PRIMARY KEY,
      last_token INTEGER NOT NULL
    )
  ''');

  static Future<T> _serializeWeb<T>(Future<T> Function() action) {
    final result = _webQueue.then((_) => action());
    _webQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> observe(String scope, Object? rawToken) async {
    final token = int.tryParse(rawToken?.toString().trim() ?? '');
    if (token == null || token < 1) return;
    if (kIsWeb) {
      return _serializeWeb(() async {
        final prefs = await SharedPreferences.getInstance();
        final key = 'offline_token_counter_$scope';
        if (token > (prefs.getInt(key) ?? 0)) await prefs.setInt(key, token);
      });
    }
    final db = await _database();
    await db.transaction((tx) async {
      final previous = await _read(tx, scope);
      if (token > previous) await _write(tx, scope, token);
    });
  }

  /// Save the token and pending order in one transaction. Failed saves do not
  /// consume a token, concurrent sales cannot receive the same number.
  Future<T> allocate<T>(
    String scope,
    Future<T> Function(int token, DatabaseExecutor? tx) save, {
    Future<T?> Function(DatabaseExecutor? tx)? existing,
  }) async {
    if (kIsWeb) {
      return _serializeWeb(() async {
        final saved = await existing?.call(null);
        if (saved != null) return saved;
        final prefs = await SharedPreferences.getInstance();
        final key = 'offline_token_counter_$scope';
        final token = (prefs.getInt(key) ?? 0) + 1;
        // Persist the high-water mark first so a crash cannot reuse a token.
        await prefs.setInt(key, token);
        return save(token, null);
      });
    }
    final db = await _database();
    return db.transaction((tx) async {
      final saved = await existing?.call(tx);
      if (saved != null) return saved;
      final token = await _read(tx, scope) + 1;
      await _write(tx, scope, token);
      return save(token, tx);
    });
  }

  Future<int> _read(DatabaseExecutor db, String scope) async {
    final rows = await db.query(
      'offline_token_counters',
      where: 'scope = ?',
      whereArgs: [scope],
    );
    return rows.isEmpty ? 0 : rows.first['last_token'] as int;
  }

  Future<void> _write(DatabaseExecutor db, String scope, int token) async {
    await db.insert('offline_token_counters', {
      'scope': scope,
      'last_token': token,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
