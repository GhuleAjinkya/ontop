// test/test_helpers.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

/// Initialize SQLite for testing
void initializeTestSqlite() {
  // Initialize FFI
  sqfliteFfiInit();
  // Set databaseFactory to use the FFI version
  databaseFactory = databaseFactoryFfi;
}

/// Create a temporary database for testing
Future<Database> getTestDatabase() async {
  final databasePath = await getDatabasesPath();
  final tempDbPath = join(databasePath, 'test_contacts.db');

  // Delete existing database if it exists
  if (await File(tempDbPath).exists()) {
    await File(tempDbPath).delete();
  }

  // Create a new database
  return await openDatabase(
    tempDbPath,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE contacts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          position TEXT NOT NULL,
          organization TEXT NOT NULL,
          phoneNumber TEXT NOT NULL,
          starred INTEGER NOT NULL DEFAULT 0
        )
      ''');
    },
  );
}
