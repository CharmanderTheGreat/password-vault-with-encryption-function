import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import '../database/vault_repository.dart';

/// Holds the unlocked session in memory ONLY. The moment the app is
/// closed, backgrounded past the auto-lock timeout, or the user taps
/// "Lock", this is wiped — the derived key and repository disappear,
/// and the master password must be re-entered to get them back.
class VaultSession extends ChangeNotifier {
  SecretKey? _sessionKey;
  VaultRepository? _repository;
  DateTime? _lastActivity;

  static const autoLockAfter = Duration(minutes: 3);

  bool get isUnlocked => _sessionKey != null;
  VaultRepository? get repository => _repository;

  void unlock(SecretKey key) {
    _sessionKey = key;
    _repository = VaultRepository(key);
    _lastActivity = DateTime.now();
    notifyListeners();
  }

  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  bool get shouldAutoLock {
    if (_lastActivity == null) return false;
    return DateTime.now().difference(_lastActivity!) > autoLockAfter;
  }

  void lock() {
    _sessionKey = null;
    _repository = null;
    _lastActivity = null;
    notifyListeners();
  }
}
