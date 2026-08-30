import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Called right after Google sign-in (see GoogleAuthService.signIn) so a
/// user's existing vault shows up immediately on a new device, and again
/// on every unlock (see UnlockScreen) so entries added on other devices
/// after the first sign-in still show up here.
class VaultSyncService {
  static Future<void> pullFromCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vault_entries')
        .get();

    if (snapshot.docs.isEmpty) return;

    final db = await DatabaseHelper.database;
    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Build the row explicitly from the known local schema instead of
      // inserting doc.data() as-is. Two reasons:
      //  1. Some cloud documents (e.g. older entries, or ones written
      //     from a different client/version) may be missing a field
      //     the local table declares NOT NULL (created_at, for
      //     example), which throws a SQLite constraint error and — if
      //     unhandled — aborts the ENTIRE sync, which in turn aborts
      //     sign-in itself (pullFromCloud runs during sign-in).
      //  2. A stray field that isn't an actual local column (e.g. a
      //     leftover "user_id") would otherwise be passed straight
      //     into the INSERT statement and fail with "no such column".
      final now = DateTime.now().toIso8601String();
      final updatedAt = data['updated_at'] as String? ?? now;

      final row = <String, Object?>{
        'id': data['id'] as String? ?? doc.id,
        'label': data['label'] as String? ?? '',
        'url': data['url'] as String?,
        'username_encrypted': data['username_encrypted'] as String? ?? '',
        'password_encrypted': data['password_encrypted'] as String? ?? '',
        'notes_encrypted': data['notes_encrypted'] as String?,
        'created_at': data['created_at'] as String? ?? updatedAt,
        'updated_at': updatedAt,
        'last_password_change':
            data['last_password_change'] as String? ?? updatedAt,
      };

      try {
        await db.insert(
          'vault_entries',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        // Skip this one malformed entry rather than aborting the whole
        // sync (and, if this runs during sign-in, the sign-in itself).
        debugPrint('Skipping malformed cloud vault entry ${doc.id}: $e');
      }
    }
  }
}
