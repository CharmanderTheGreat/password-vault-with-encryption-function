import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/encryption/key_derivation.dart';
import '../../core/encryption/vault_cipher.dart';

/// Manages the master password lifecycle:
///  - first-time setup (no master password stored anywhere, ever)
///  - unlocking the vault on each app open
///  - deriving the AES key used by [VaultCipher] for that session only
///
/// The master password itself is NEVER written to disk. Only:
///   1. A random salt (not secret)
///   2. An encrypted "verifier" string (used to check if the password you
///      typed is correct, without storing the password itself)
///
/// Both the salt and verifier are also mirrored to Firestore (under the
/// signed-in user's UID) so a second device can pull them down and
/// unlock the same vault, instead of generating a brand new key.
class MasterPasswordService {
  static const _saltKey = 'vault_salt';
  static const _verifierKey = 'vault_verifier';
  static const _verifierPlainText = 'VAULT_OK'; // constant known value

  static DocumentReference<Map<String, dynamic>>? get _cloudDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  /// True if THIS DEVICE already has a local salt + verifier stored.
  /// Does not check the cloud — call [pullFromCloud] first if you want
  /// to know whether the signed-in account has a vault set up anywhere.
  static Future<bool> isVaultInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saltKey) && prefs.containsKey(_verifierKey);
  }

  /// Call once, the first time the user sets their master password.
  static Future<SecretKey> setupMasterPassword(String masterPassword) async {
    final salt = KeyDerivation.generateSalt();
    final key = await KeyDerivation.deriveKey(
      masterPassword: masterPassword,
      salt: salt,
    );

    final cipher = VaultCipher(key);
    final verifier = await cipher.encrypt(_verifierPlainText);
    final saltB64 = base64Encode(salt);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saltKey, saltB64);
    await prefs.setString(_verifierKey, verifier);

    // Mirror to Firestore so other devices on this account can unlock too.
    try {
      await _cloudDoc?.set({
        'vault_salt': saltB64,
        'vault_verifier': verifier,
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline — local setup still succeeded, will retry to sync
      // naturally next time setupMasterPassword or changeMasterPassword runs.
    }

    return key;
  }

  /// Checks Firestore for an existing salt/verifier under the signed-in
  /// user's UID and copies them down to this device's local prefs.
  ///
  /// Call this BEFORE checking [isVaultInitialized] right after sign-in,
  /// so a returning user on a new device gets routed to UnlockScreen
  /// (with the correct key) instead of SetupScreen (which would silently
  /// create a second, incompatible encryption key).
  ///
  /// Returns true if cloud data was found and pulled down, false if
  /// there's genuinely nothing in the cloud yet (brand new user).
  static Future<bool> pullFromCloud() async {
    final cloudDoc = _cloudDoc;
    if (cloudDoc == null) return false;

    final doc = await _getWithFreshToken(cloudDoc);
    final data = doc.data();
    if (data == null ||
        data['vault_salt'] == null ||
        data['vault_verifier'] == null) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saltKey, data['vault_salt'] as String);
    await prefs.setString(_verifierKey, data['vault_verifier'] as String);
    return true;
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
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      return await docRef.get();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await Future.delayed(const Duration(milliseconds: 700));
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      return await docRef.get();
    }
  }

  /// Attempts to unlock the vault with [masterPassword].
  /// Returns the derived SecretKey if correct, or null if the password
  /// is wrong. Keep this key in memory only for the current session —
  /// never persist it.
  static Future<SecretKey?> unlock(String masterPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final saltB64 = prefs.getString(_saltKey);
    final verifier = prefs.getString(_verifierKey);

    if (saltB64 == null || verifier == null) {
      throw StateError('Vault has not been initialized yet.');
    }

    final salt = Uint8List.fromList(base64Decode(saltB64));
    final key = await KeyDerivation.deriveKey(
      masterPassword: masterPassword,
      salt: salt,
    );

    final cipher = VaultCipher(key);
    try {
      final decoded = await cipher.decrypt(verifier);
      if (decoded == _verifierPlainText) {
        return key; // correct master password
      }
      return null;
    } catch (_) {
      // Decryption failing (bad MAC) means wrong password.
      return null;
    }
  }

  /// Clears this device's local encryption setup entirely (salt +
  /// verifier). Used when signing out, so the next Google account that
  /// signs in on this device goes through setup fresh, rather than
  /// trying to unlock with the previous account's now-irrelevant local
  /// state.
  ///
  /// Does NOT touch Firestore — other devices still signed into this
  /// account need that cloud copy to keep working.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saltKey);
    await prefs.remove(_verifierKey);
  }

  /// Changing the master password re-encrypts the verifier with a new
  /// salt + key, and pushes the new salt/verifier to Firestore too
  /// (via setupMasterPassword). NOTE: the caller is responsible for also
  /// re-encrypting every vault entry with the new key (see
  /// VaultRepository.reencryptAll) — otherwise old entries and the new
  /// key will no longer match.
  static Future<SecretKey> changeMasterPassword(
      String newMasterPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saltKey);
    await prefs.remove(_verifierKey);
    return setupMasterPassword(newMasterPassword);
  }
}
