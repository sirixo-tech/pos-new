import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'pos_database_platform.dart';
import 'offline_token_store.dart';

class PosDatabase {
  PosDatabase._();

  static final PosDatabase instance = PosDatabase._();
  static Database? _database;
  static Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final opening = _opening ??= _initDatabase();
    try {
      return _database = await opening;
    } finally {
      if (identical(_opening, opening)) _opening = null;
    }
  }

  Future<Database> _initDatabase() async {
    final factory = posDatabaseFactory;
    // FFI's default directory can be relative to the launcher working folder.
    // Keep installed desktop data in the user's persistent application folder.
    final dbPath = usesDesktopDatabase
        ? join((await getApplicationSupportDirectory()).path, 'databases')
        : await factory.getDatabasesPath();
    final path = join(dbPath, 'serveai_pos.db');

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bootstrap_cache (
        id INTEGER PRIMARY KEY,
        branch_id INTEGER NOT NULL UNIQUE,
        data TEXT NOT NULL,
        menu_revision TEXT,
        bootstrap_revision TEXT,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE receipt_settings_cache (
        id INTEGER PRIMARY KEY,
        branch_id INTEGER NOT NULL UNIQUE,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_orders (
        id INTEGER PRIMARY KEY,
        local_uuid TEXT NOT NULL UNIQUE,
        branch_id INTEGER NOT NULL,
        order_data TEXT NOT NULL,
        local_order_number TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        server_order_id INTEGER,
        server_order_number TEXT,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        synced_at INTEGER,
        printed_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE print_queue (
        id INTEGER PRIMARY KEY,
        local_order_uuid TEXT NOT NULL,
        print_type TEXT NOT NULL,
        print_data TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        printed_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_pending_orders_status ON pending_orders(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_pending_orders_branch ON pending_orders(branch_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_print_queue_status ON print_queue(status)
    ''');

    await _createLocalHeldOrdersTable(db);
    await _createPendingPrintJobsTable(db);
    await OfflineTokenStore.createTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await OfflineTokenStore.createTable(db);
    }
    if (oldVersion < 2) {
      await _createLocalHeldOrdersTable(db);
    }
    if (oldVersion < 3) {
      await _createPendingPrintJobsTable(db);
    }
  }

  Future<void> _createPendingPrintJobsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_print_jobs (
        id INTEGER PRIMARY KEY,
        job_key TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL,
        order_id INTEGER NOT NULL DEFAULT 0,
        order_number TEXT NOT NULL,
        source TEXT,
        cashier INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        paper_out INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_print_jobs_status
      ON pending_print_jobs(status)
    ''');
  }

  Future<void> _createLocalHeldOrdersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_held_orders (
        id INTEGER PRIMARY KEY,
        local_uuid TEXT NOT NULL UNIQUE,
        branch_id INTEGER NOT NULL,
        payload TEXT NOT NULL,
        local_order_number TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_held_orders_branch
      ON local_held_orders(branch_id)
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

class BootstrapCache {
  BootstrapCache._();

  static const _webPrefix = 'pos_bootstrap_cache_';

  static Future<void> save({
    required int branchId,
    required Map<String, dynamic> data,
    String? menuRevision,
    String? bootstrapRevision,
  }) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_webPrefix$branchId',
          jsonEncode({
            'data': data,
            'menu_revision': menuRevision,
            'bootstrap_revision': bootstrapRevision,
            'cached_at': DateTime.now().millisecondsSinceEpoch,
          }),
        );
      } catch (e) {
        debugPrint('BootstrapCache web save failed: $e');
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.insert('bootstrap_cache', {
        'branch_id': branchId,
        'data': jsonEncode(data),
        'menu_revision': menuRevision,
        'bootstrap_revision': bootstrapRevision,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('BootstrapCache save failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> load(int branchId) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_webPrefix$branchId');
        if (raw == null) return null;
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return {
          'data': decoded['data'] as Map<String, dynamic>,
          'menu_revision': decoded['menu_revision'] as String?,
          'bootstrap_revision': decoded['bootstrap_revision'] as String?,
          'cached_at': decoded['cached_at'] as int?,
        };
      } catch (e) {
        debugPrint('BootstrapCache web load failed: $e');
        return null;
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      final results = await db.query(
        'bootstrap_cache',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final row = results.first;
      return {
        'data': jsonDecode(row['data'] as String),
        'menu_revision': row['menu_revision'],
        'bootstrap_revision': row['bootstrap_revision'],
        'cached_at': row['cached_at'],
      };
    } catch (e) {
      debugPrint('BootstrapCache load failed: $e');
      return null;
    }
  }

  static Future<String?> getMenuRevision(int branchId) async {
    if (kIsWeb) {
      final cached = await load(branchId);
      return cached?['menu_revision'] as String?;
    }

    try {
      final db = await PosDatabase.instance.database;
      final results = await db.query(
        'bootstrap_cache',
        columns: ['menu_revision'],
        where: 'branch_id = ?',
        whereArgs: [branchId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return results.first['menu_revision'] as String?;
    } catch (e) {
      debugPrint('BootstrapCache getMenuRevision failed: $e');
      return null;
    }
  }

  static Future<void> clear(int branchId) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_webPrefix$branchId');
      } catch (_) {}
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.delete(
        'bootstrap_cache',
        where: 'branch_id = ?',
        whereArgs: [branchId],
      );
    } catch (_) {}
  }
}

class ReceiptSettingsCache {
  ReceiptSettingsCache._();

  static const _webPrefix = 'pos_receipt_settings_cache_';

  static Future<void> save({
    required int branchId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_webPrefix$branchId', jsonEncode(data));
      } catch (e) {
        debugPrint('ReceiptSettingsCache web save failed: $e');
      }
      return;
    }

    try {
      final db = await PosDatabase.instance.database;
      await db.insert('receipt_settings_cache', {
        'branch_id': branchId,
        'data': jsonEncode(data),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('ReceiptSettingsCache save failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> load(int branchId) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_webPrefix$branchId');
        if (raw == null) return null;
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('ReceiptSettingsCache web load failed: $e');
        return null;
      }
    }

    try {
      final db = await PosDatabase.instance.database;
      final results = await db.query(
        'receipt_settings_cache',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return jsonDecode(results.first['data'] as String)
          as Map<String, dynamic>;
    } catch (e) {
      debugPrint('ReceiptSettingsCache load failed: $e');
      return null;
    }
  }
}
