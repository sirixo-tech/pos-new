import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool get usesDesktopDatabase => Platform.isWindows || Platform.isLinux;

DatabaseFactory get posDatabaseFactory {
  if (usesDesktopDatabase) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return databaseFactory;
}
