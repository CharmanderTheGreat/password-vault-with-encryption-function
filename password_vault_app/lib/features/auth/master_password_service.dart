import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
class MasterPasswordService {
  static const _saltKey = 'vault_salt';
  static const _verifierKey = 'vault_verifier';
  static const _verifierPlainText = 'VAULT_OK'; // constant known value

  /// True if this is the first time the app is being set up.
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saltKey, base64Encode(salt));
    await prefs.setString(_verifierKey, verifier);

    return key;
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

  /// Changing the master password re-encrypts the verifier with a new
  /// salt + key. NOTE: the caller is responsible for also re-encrypting
  /// every vault entry with the new key (see VaultRepository.reencryptAll).
  static Future<SecretKey> changeMasterPassword(String newMasterPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saltKey);
    await prefs.remove(_verifierKey);
    return setupMasterPassword(newMasterPassword);
  }
}
