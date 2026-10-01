import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/offline/pos_database_platform.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test(
    'desktop database opens without a mobile database plugin',
    () async {
      expect(usesDesktopDatabase, isTrue);
      final db = await posDatabaseFactory.openDatabase(inMemoryDatabasePath);
      try {
        await db.execute('CREATE TABLE startup_check (value TEXT NOT NULL)');
        await db.insert('startup_check', {'value': 'ready'});
        expect(await db.query('startup_check'), [
          {'value': 'ready'},
        ]);
      } finally {
        await db.close();
      }
    },
    skip: !Platform.isWindows && !Platform.isLinux,
  );
}
