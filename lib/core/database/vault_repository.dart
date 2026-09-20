import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import '../encryption/vault_cipher.dart';
import '../models/vault_entry.dart';
import 'database_helper.dart';
import 'sync_queue_service.dart';

class VaultRepository {
  final VaultCipher _cipher;
  static const _uuid = Uuid();

  VaultRepository(SecretKey sessionKey) : _cipher = VaultCipher(sessionKey);

  Future<String> addEntry(VaultEntry entry) async {
    final db = await DatabaseHelper.database;
    final id = entry.id ?? _uuid.v4();

    final row = {
      'id': id,
      'label': entry.label,
      'url': entry.url,
      'username_encrypted': await _cipher.encrypt(entry.username),
      'password_encrypted': await _cipher.encrypt(entry.password),
      'notes_encrypted':
          entry.notes != null ? await _cipher.encrypt(entry.notes!) : null,
      'created_at': entry.createdAt.toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
      'last_password_change': entry.lastPasswordChange.toIso8601String(),
    };

    // Local save happens FIRST and unconditionally — this must succeed
    // regardless of internet access. The cloud push is queued
    // separately (see SyncQueueService) and retried automatically
    // later (on unlock, on pull-to-refresh) if it can't go through
    // right now.
    await db.insert('vault_entries', row);
    await SyncQueueService.enqueueUpsert(id, row);
    // Fire-and-forget: the caller (UI) must not wait on this. Firestore
    // hangs indefinitely with no internet rather than failing fast, so
    // awaiting it here would freeze the "Save" flow while offline.
    unawaited(SyncQueueService.flushPendingChanges());

    return id;
  }

  Future<List<VaultEntry>> getAllEntries() async {
    final db = await DatabaseHelper.database;
    final rows = await db.query('vault_entries', orderBy: 'label ASC');

    debugPrint(
        '*** VaultRepository.getAllEntries: db.query returned ${rows.length} raw rows ***');

    final entries = <VaultEntry>[];
    for (final row in rows) {
      try {
        entries.add(await _rowToEntry(row));
      } catch (e) {
        // If a single entry fails to decrypt (e.g. wrong key), skip
        // just that one and keep going instead of losing the whole list.
        debugPrint(
            '*** VaultRepository.getAllEntries: FAILED to decrypt row id=${row['id']} label=${row['label']}: $e ***');
      }
    }

    debugPrint(
        '*** VaultRepository.getAllEntries: returning ${entries.length} successfully-decrypted entries ***');

    return entries;
  }

  Future<List<VaultEntry>> getEntriesDueForRotation() async {
    final all = await getAllEntries();
    return all.where((e) => e.isPasswordDueForRotation).toList();
  }

  Future<void> updateEntry(VaultEntry entry) async {
    final db = await DatabaseHelper.database;

    final passwordChanged = await _hasPasswordChanged(entry);
    final updatedAt = DateTime.now().toIso8601String();
    final lastPasswordChange = passwordChanged
        ? updatedAt
        : entry.lastPasswordChange.toIso8601String();

    final row = {
      'id': entry.id,
      'label': entry.label,
      'url': entry.url,
      'username_encrypted': await _cipher.encrypt(entry.username),
      'password_encrypted': await _cipher.encrypt(entry.password),
      'notes_encrypted':
          entry.notes != null ? await _cipher.encrypt(entry.notes!) : null,
      'updated_at': updatedAt,
      'last_password_change': lastPasswordChange,
    };

    await db.update(
      'vault_entries',
      row,
      where: 'id = ?',
      whereArgs: [entry.id],
    );

    // The cloud copy needs the full row (Firestore doesn't merge partial
    // updates the way this local UPDATE does), so include created_at
    // here even though the local UPDATE statement above doesn't touch it.
    await SyncQueueService.enqueueUpsert(entry.id!, {
      ...row,
      'created_at': entry.createdAt.toIso8601String(),
    });
    unawaited(SyncQueueService.flushPendingChanges());
  }

  Future<void> deleteEntry(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('vault_entries', where: 'id = ?', whereArgs: [id]);
    await SyncQueueService.enqueueDelete(id);
    unawaited(SyncQueueService.flushPendingChanges());
  }

  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await DatabaseHelper.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'vault_entries',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    for (final id in ids) {
      await SyncQueueService.enqueueDelete(id);
    }
    unawaited(SyncQueueService.flushPendingChanges());
  }

  Future<bool> _hasPasswordChanged(VaultEntry updatedEntry) async {
    final db = await DatabaseHelper.database;
    final rows = await db.query(
      'vault_entries',
      where: 'id = ?',
      whereArgs: [updatedEntry.id],
    );
    if (rows.isEmpty) return true;

    final oldPassword =
        await _cipher.decrypt(rows.first['password_encrypted'] as String);
    return oldPassword != updatedEntry.password;
  }

  Future<VaultEntry> _rowToEntry(Map<String, dynamic> row) async {
    return VaultEntry(
      id: row['id'] as String,
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

  Future<List<VaultEntry>> exportAllDecrypted() => getAllEntries();
}
