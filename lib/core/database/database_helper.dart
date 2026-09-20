import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sets up the local, offline SQLite database. Works the same whether
/// the app is running on Android/iOS (native sqflite) or Windows/Linux/
/// macOS (sqflite_common_ffi).
///
/// Two tables:
///  - vault_entries: the actual saved accounts, always the local
///    source of truth on this device.
///  - sync_queue: a durable outbox of changes (add/edit/delete) that
///    still need to reach Firestore. See SyncQueueService.
class DatabaseHelper {
  static Database? _db;
  static const _dbVersion = 2;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  /// Closes and deletes the local database file entirely. Used when
  /// signing out, so a different Google account signing in on this same
  /// device doesn't see the previous account's locally-cached entries.
  static Future<void> resetLocalData() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'vault.db');

    // TEMPORARY debug log — this should ONLY ever print when the user
    // explicitly signs out. If it shows up any other time, that's the
    // smoking gun for any "vault empties unexpectedly" bug.
    debugPrint('*** resetLocalData() CALLED — wiping $path ***');

    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'vault.db');
    final alreadyExisted = await File(path).exists();

    debugPrint(
        '*** DatabaseHelper opening: $path (existed before open: $alreadyExisted) ***');

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        debugPrint(
            '*** DatabaseHelper onCreate FIRED — creating fresh tables at $path ***');
        await _createVaultEntriesTable(db);
        await _createSyncQueueTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint(
            '*** DatabaseHelper onUpgrade FIRED — $oldVersion -> $newVersion at $path ***');
        if (oldVersion < 2) {
          await _createSyncQueueTable(db);
        }
      },
    );

    final countResult =
        await db.rawQuery('SELECT COUNT(*) AS c FROM vault_entries');
    debugPrint(
        '*** DatabaseHelper opened $path — vault_entries row count: ${countResult.first['c']} ***');

    return db;
  }

  static Future<void> _createVaultEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE vault_entries (
        id TEXT PRIMARY KEY,
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
  }

  static Future<void> _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        queued_at TEXT NOT NULL
      )
    ''');
  }
}
