import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Encrypts and decrypts individual strings (passwords, usernames, notes)
/// using AES-256-GCM, which gives both confidentiality AND integrity
/// (if the ciphertext is tampered with, decryption fails loudly instead
/// of silently returning garbage).
class VaultCipher {
  final SecretKey _key;
  final _algorithm = AesGcm.with256bits();

  VaultCipher(this._key);

  /// Encrypts [plainText]. Returns a single base64 string containing
  /// nonce + ciphertext + MAC, safe to store directly in SQLite.
  Future<String> encrypt(String plainText) async {
    final nonce = _algorithm.newNonce(); // random 12-byte nonce per encryption
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: _key,
      nonce: nonce,
    );

    // Pack nonce + ciphertext + mac together so we only need to store one blob.
    final packed = <int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];

    return base64Encode(packed);
  }

  /// Decrypts a base64 string produced by [encrypt]. Throws if the data
  /// was tampered with or the wrong key/master password was used.
  Future<String> decrypt(String encoded) async {
    final bytes = base64Decode(encoded);

    const nonceLength = 12; // AES-GCM standard nonce size
    const macLength = 16; // AES-GCM standard MAC size

    final nonce = bytes.sublist(0, nonceLength);
    final mac = bytes.sublist(bytes.length - macLength);
    final cipherText = bytes.sublist(nonceLength, bytes.length - macLength);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );

    final clearBytes = await _algorithm.decrypt(secretBox, secretKey: _key);
    return utf8.decode(clearBytes);
  }
}
