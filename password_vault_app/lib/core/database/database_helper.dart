import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sets up the local, offline SQLite database. Works the same whether
/// the app is running on Android/iOS (native sqflite) or Windows/Linux/
/// macOS (sqflite_common_ffi). No network involved at any point.
class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    // Desktop platforms need the FFI-based sqflite implementation.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'vault.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vault_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT NOT NULL,
            url TEXT,
            username_encrypted TEXT NOT NULL,
            password_encrypted TEXT NOT NULL,
            notes_encrypted TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_password_change TEXT NOT NULL
          )
        ''');
      },
    );
  }
}
