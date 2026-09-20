import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';

/// A durable, local outbox for changes (add/edit/delete) that still
/// need to reach Firestore.
///
/// Every write to vault_entries is enqueued here FIRST, in the same
/// action as the local save — the local save itself never depends on
/// network access, so add/edit/delete always work offline. The queue
/// is then flushed opportunistically:
///  - immediately after the change is made (best-effort, in case
///    there's internet right now)
///  - on every unlock (VaultAccessService / UnlockScreen)
///  - on every manual pull-to-refresh (VaultListScreen)
///
/// Nothing is lost if the device is offline when a change is made — it
/// just waits in the queue until the next successful flush.
class SyncQueueService {
  static Future<void> enqueueUpsert(
      String entryId, Map<String, dynamic> row) async {
    final db = await DatabaseHelper.database;
    await db.insert('sync_queue', {
      'entry_id': entryId,
      'operation': 'upsert',
      'payload': jsonEncode(row),
      'queued_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> enqueueDelete(String entryId) async {
    final db = await DatabaseHelper.database;
    await db.insert('sync_queue', {
      'entry_id': entryId,
      'operation': 'delete',
      'payload': null,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }

  /// Attempts to push every queued change to Firestore, oldest first.
  /// Stops at the first failure (almost always "no internet", or a
  /// permission hiccup right after sign-in) rather than skipping
  /// around — whatever's left stays queued and gets retried in full
  /// next time this runs. Safe to call often; it's a no-op if the
  /// queue is empty or nobody's signed in.
  static Future<void> flushPendingChanges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = await DatabaseHelper.database;
    final queued = await db.query('sync_queue', orderBy: 'queued_at ASC');
    if (queued.isEmpty) return;

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vault_entries');

    for (final item in queued) {
      final queueId = item['queue_id'] as int;
      final entryId = item['entry_id'] as String;
      final operation = item['operation'] as String;

      try {
        if (operation == 'upsert') {
          final payload =
              jsonDecode(item['payload'] as String) as Map<String, dynamic>;
          await collection.doc(entryId).set(payload);
        } else if (operation == 'delete') {
          await collection.doc(entryId).delete();
        }
        await db.delete('sync_queue', where: 'queue_id = ?', whereArgs: [queueId]);
      } catch (e) {
        debugPrint(
            '*** SyncQueueService.flushPendingChanges: stopped at entry $entryId ($operation) — $e ***');
        return; // likely offline — leave the rest queued, retry later
      }
    }

    debugPrint('*** SyncQueueService.flushPendingChanges: queue fully drained ***');
  }

  /// How many changes are still waiting to reach the cloud. Exposed in
  /// case the UI wants to show a "N changes pending sync" indicator.
  static Future<int> pendingCount() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_queue');
    return (result.first['c'] as int?) ?? 0;
  }
}