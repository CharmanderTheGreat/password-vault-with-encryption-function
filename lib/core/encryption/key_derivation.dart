import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Handles turning a human master password into a strong AES-256 key
/// using Argon2id (memory-hard, resistant to GPU/ASIC brute-forcing).
///
/// This never touches the network. Everything happens on-device.
class KeyDerivation {
  // Tuneable Argon2id cost parameters.
  // Higher memory/iterations = slower to brute-force, but slower to unlock too.
  // These values are a reasonable balance for a mobile/desktop app in 2026.
  static const int _memoryKiB = 19456; // ~19 MB, OWASP-recommended minimum
  static const int _iterations = 2;
  static const int _parallelism = 1;
  static const int _keyLengthBytes = 32; // 256-bit key for AES-256

  /// Generates a new random 16-byte salt. Store this alongside the vault
  /// (it is not secret) — it's needed every time to re-derive the same key.
  static Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  /// Derives a 256-bit key from [masterPassword] and [salt] using Argon2id.
  static Future<SecretKey> deriveKey({
    required String masterPassword,
    required Uint8List salt,
  }) async {
    final algorithm = Argon2id(
      memory: _memoryKiB,
      iterations: _iterations,
      parallelism: _parallelism,
      hashLength: _keyLengthBytes,
    );

    final newSecretKey = await algorithm.deriveKeyFromPassword(
      password: masterPassword,
      nonce: salt,
    );

    return newSecretKey;
  }
}
