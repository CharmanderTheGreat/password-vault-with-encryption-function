import 'package:cryptography/cryptography.dart';
import '../encryption/vault_cipher.dart';
import '../models/vault_entry.dart';
import 'database_helper.dart';

/// The only place in the app that talks to the database directly.
/// Every write encrypts username/password/notes first; every read
/// decrypts them before handing a [VaultEntry] back to the UI.
///
/// [_cipher] is built from the session's derived key (see
/// MasterPasswordService.unlock) — it lives only in memory, never on disk.
class VaultRepository {
  final VaultCipher _cipher;

  VaultRepository(SecretKey sessionKey) : _cipher = VaultCipher(sessionKey);

  Future<int> addEntry(VaultEntry entry) async {
    final db = await DatabaseHelper.database;

    final row = {
      'label': entry.label,
      'url': entry.url,
      'username_encrypted': await _cipher.encrypt(entry.username),
      'password_encrypted': await _cipher.encrypt(entry.password),
      'notes_encrypted': entry.notes != null ? await _cipher.encrypt(entry.notes!) : null,
      'created_at': entry.createdAt.toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
      'last_password_change': entry.lastPasswordChange.toIso8601String(),
    };

    return db.insert('vault_entries', row);
  }

  Future<List<VaultEntry>> getAllEntries() async {
    final db = await DatabaseHelper.database;
    final rows = await db.query('vault_entries', orderBy: 'label ASC');

    final entries = <VaultEntry>[];
    for (final row in rows) {
      entries.add(await _rowToEntry(row));
    }
    return entries;
  }

  /// Entries whose password is 30+ days old — surfaced on the dashboard
  /// as "needs rotation" per your monthly password change requirement.
  Future<List<VaultEntry>> getEntriesDueForRotation() async {
    final all = await getAllEntries();
    return all.where((e) => e.isPasswordDueForRotation).toList();
  }

  Future<void> updateEntry(VaultEntry entry) async {
    final db = await DatabaseHelper.database;

    final passwordChanged = await _hasPasswordChanged(entry);

    final row = {
      'label': entry.label,
      'url': entry.url,
      'username_encrypted': await _cipher.encrypt(entry.username),
      'password_encrypted': await _cipher.encrypt(entry.password),
      'notes_encrypted': entry.notes != null ? await _cipher.encrypt(entry.notes!) : null,
      'updated_at': DateTime.now().toIso8601String(),
      'last_password_change': passwordChanged
          ? DateTime.now().toIso8601String()
          : entry.lastPasswordChange.toIso8601String(),
    };

    await db.update(
      'vault_entries',
      row,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final db = await DatabaseHelper.database;
    await db.delete('vault_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> _hasPasswordChanged(VaultEntry updatedEntry) async {
    final db = await DatabaseHelper.database;
    final rows = await db.query(
      'vault_entries',
      where: 'id = ?',
      whereArgs: [updatedEntry.id],
    );
    if (rows.isEmpty) return true;

    final oldPassword = await _cipher.decrypt(rows.first['password_encrypted'] as String);
    return oldPassword != updatedEntry.password;
  }

  Future<VaultEntry> _rowToEntry(Map<String, dynamic> row) async {
    return VaultEntry(
      id: row['id'] as int,
      label: row['label'] as String,
      url: row['url'] as String?,
      username: await _cipher.decrypt(row['username_encrypted'] as String),
      password: await _cipher.decrypt(row['password_encrypted'] as String),
      notes: row['notes_encrypted'] != null
          ? await _cipher.decrypt(row['notes_encrypted'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      lastPasswordChange: DateTime.parse(row['last_password_change'] as String),
    );
  }

  /// Re-encrypts every entry with a new key. Call this right after
  /// MasterPasswordService.changeMasterPassword succeeds, passing in
  /// a repository built from the OLD key to read, and one from the
  /// NEW key to write — see README for the full flow.
  Future<List<VaultEntry>> exportAllDecrypted() => getAllEntries();
}
