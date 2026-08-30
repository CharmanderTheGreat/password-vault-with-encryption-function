import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import '../../core/storage/platform_secure_storage.dart';
import '../../core/database/database_helper.dart';
import 'google_auth_service.dart';
import 'master_password_service.dart';
import 'quick_unlock_service.dart';

/// Replaces the old "type a master password" flow entirely, and (as of
/// the Google Sign-In integration) keeps the same vault key consistent
/// across every device signed into the same Google account.
///
/// Under the hood the vault is still encrypted with a real AES-256 key
/// derived through Argon2id (see MasterPasswordService / KeyDerivation).
/// What changed is where that key's password comes from:
///
///  - The first device ever used for a given Google account generates a
///    long random password and uploads it to Firestore, under a document
///    keyed by that account's Firebase UID.
///  - Any other device signing into the SAME Google account fetches that
///    same password from Firestore instead of generating its own, so the
///    same key decrypts the same data everywhere.
///  - Firestore security rules restrict that document to only be
///    readable/writable by the matching signed-in account, so other
///    users can never read each other's keys.
///  - On this device, once fetched, the password is cached locally and
///    gated behind this device's own PIN/pattern/biometric lock, exactly
///    as before. If the device has no lock, the vault just opens with no
///    prompt (see UnlockScreen).
class VaultAccessService {
  static const _autoPasswordKey = 'vault_auto_password';

  /// True if this device has a PIN/pattern/biometric lock we can use.
  static Future<bool> deviceHasLock() => QuickUnlockService.isDeviceSupported();

  /// Runs once per device, the first time this device opens the vault
  /// while signed in. Fetches the account's existing vault key from
  /// Firestore if one exists, or generates a new one and uploads it if
  /// this is the very first device for this account.
  static Future<SecretKey> setupAutomatically() async {
    final uid = GoogleAuthService.currentUser!.uid;
    final docRef = FirebaseFirestore.instance.collection('vaults').doc(uid);
    final snapshot = await _getWithFreshToken(docRef);

    final String password;
    final existingKey = snapshot.data()?['vaultKey'] as String?;

    if (snapshot.exists && existingKey != null) {
      // Not the first device for this account, reuse the same key.
      password = existingKey;
    } else {
      // First device ever for this account, generate and upload a key.
      password = _generateRandomPassword();
      await docRef.set({
        'vaultKey': password,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final key = await MasterPasswordService.setupMasterPassword(password);
    await PlatformSecureStorage.write(key: _autoPasswordKey, value: password);

    if (await deviceHasLock()) {
      // Confirms the user can actually use their device lock right now
      // and stores the password behind it for every future unlock on
      // this device.
      await QuickUnlockService.enable(password);
    }

    return key;
  }

  /// Reads a Firestore document, forcing a fresh ID token first and
  /// retrying once on a permission-denied error.
  ///
  /// Right after Firebase.signInWithCredential() completes, there's a
  /// brief window on some platforms (observed on Windows desktop) where
  /// the Firestore SDK hasn't yet picked up the newly-issued auth token,
  /// so the very first Firestore call after sign-in can be evaluated by
  /// security rules as request.auth == null and get rejected even
  /// though the user IS actually signed in. Forcing a token refresh
  /// (getIdToken(true)) and retrying once works around that race.
  static Future<DocumentSnapshot<Map<String, dynamic>>> _getWithFreshToken(
      DocumentReference<Map<String, dynamic>> docRef) async {
    try {
      await GoogleAuthService.currentUser?.getIdToken(true);
      return await docRef.get();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // One retry, with a short delay to let the token propagate.
      await Future.delayed(const Duration(milliseconds: 700));
      await GoogleAuthService.currentUser?.getIdToken(true);
      return await docRef.get();
    }
  }

  /// Fetches this account's existing vault password from Firestore
  /// WITHOUT generating a new one. Used as a recovery path when this
  /// device has local salt/verifier (so MasterPasswordService thinks
  /// the vault is "already set up") but no cached auto-unlock password
  /// — e.g. because the salt/verifier arrived here some other way than
  /// setupAutomatically() ever running on this device. Returns null if
  /// there's genuinely nothing in Firestore yet.
  static Future<String?> _fetchExistingPasswordFromCloud() async {
    final uid = GoogleAuthService.currentUser?.uid;
    if (uid == null) return null;
    final docRef = FirebaseFirestore.instance.collection('vaults').doc(uid);
    final snapshot = await _getWithFreshToken(docRef);
    return snapshot.data()?['vaultKey'] as String?;
  }

  /// True if the unlock screen needs to prompt for device auth at all.
  static Future<bool> requiresDeviceAuth() => QuickUnlockService.isEnabled();

  /// Retrieves the key with no prior UI, used when the device has no
  /// lock screen, so the vault just opens.
  static Future<SecretKey?> unlockWithoutPrompt() async {
    var storedPassword =
        await PlatformSecureStorage.read(key: _autoPasswordKey);

    if (storedPassword == null) {
      // Nothing cached locally. Rather than failing outright, fetch the
      // SAME password this account already uses from Firestore — never
      // generate a new one here, that would derive a different key and
      // make every existing (already-encrypted) entry unreadable.
      storedPassword = await _fetchExistingPasswordFromCloud();
      if (storedPassword == null) return null;

      await PlatformSecureStorage.write(
          key: _autoPasswordKey, value: storedPassword);
      if (await deviceHasLock()) {
        await QuickUnlockService.enable(storedPassword);
      }
    }

    return MasterPasswordService.unlock(storedPassword);
  }

  /// Prompts the device's PIN/biometric, then unlocks. Returns null if
  /// the user cancels or device authentication fails.
  static Future<SecretKey?> unlockWithDeviceAuth() async {
    final storedPassword =
        await QuickUnlockService.authenticateAndGetPassword();
    if (storedPassword == null) return null;
    return MasterPasswordService.unlock(storedPassword);
  }

  static String _generateRandomPassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Signs out of Google and fully resets this device's local state:
  /// the cached key, Quick Unlock, and every locally-stored entry.
  ///
  /// This is necessary because local entries are encrypted with a key
  /// tied to whichever Google account set them up. If a different
  /// account signs in afterward without this reset, the app would try
  /// to decrypt the previous account's entries with the new account's
  /// key and fail. Clearing local data here means each account starts
  /// clean on this device; entries live safely in that account's own
  /// Firestore document either way.
  static Future<void> signOutAndResetDevice() async {
    await QuickUnlockService.disable();
    await PlatformSecureStorage.delete(key: _autoPasswordKey);
    await MasterPasswordService.reset();
    await DatabaseHelper.resetLocalData();
    await GoogleAuthService.signOut();
  }
}
