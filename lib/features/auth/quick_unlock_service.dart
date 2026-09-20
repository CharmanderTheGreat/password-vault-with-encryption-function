import 'dart:io';
import 'package:local_auth/local_auth.dart';
import '../../core/storage/platform_secure_storage.dart';

/// "Quick Unlock" lets the vault be opened using the device's own PIN,
/// fingerprint, or face unlock instead of typing the master password
/// every time.
///
/// How it stays reasonably secure: the master password itself is stored
/// via PlatformSecureStorage (see that file for why) rather than in the
/// app's own vault database, and every read of it is gated behind a
/// fresh device-authentication prompt.
///
/// IMPORTANT TRADE-OFF: this is only as strong as the device's own lock
/// screen. If the device has no PIN/pattern/biometric set up, enabling
/// this effectively removes the master password protection — anyone who
/// picks up the unlocked device can open the vault.
///
/// PLATFORM NOTE: the `local_auth` plugin has no Windows/Linux/macOS
/// implementation. Calling its methods on desktop doesn't throw — the
/// method channel call just never returns, hanging the caller forever
/// (this is what caused the app to freeze on "Linking your vault to
/// your device lock..." on Windows). So every entry point here checks
/// Platform.isAndroid/isIOS FIRST and short-circuits on desktop before
/// touching `_localAuth` at all.
class QuickUnlockService {
  static const _enabledKey = 'quick_unlock_enabled';
  static const _passwordKey = 'quick_unlock_master_password';
  static final _localAuth = LocalAuthentication();

  static bool get _supportsLocalAuth => Platform.isAndroid || Platform.isIOS;

  /// True if this device has some form of lock screen (PIN, pattern,
  /// biometric) that we can piggyback on. Always false on desktop.
  static Future<bool> isDeviceSupported() async {
    if (!_supportsLocalAuth) return false;
    try {
      final biometrics = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      return biometrics || deviceSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    if (!_supportsLocalAuth) return false;
    final value = await PlatformSecureStorage.read(key: _enabledKey);
    return value == 'true';
  }

  /// Enables Quick Unlock. Requires the user to authenticate with their
  /// device credentials once, right now, to confirm they can actually
  /// use it before we rely on it. No-op (returns false) on desktop.
  static Future<bool> enable(String masterPassword) async {
    if (!_supportsLocalAuth) return false;

    final authenticated = await _authenticate();
    if (!authenticated) return false;

    await PlatformSecureStorage.write(key: _passwordKey, value: masterPassword);
    await PlatformSecureStorage.write(key: _enabledKey, value: 'true');
    return true;
  }

  static Future<void> disable() async {
    if (!_supportsLocalAuth) return;
    await PlatformSecureStorage.delete(key: _passwordKey);
    await PlatformSecureStorage.write(key: _enabledKey, value: 'false');
  }

  /// Prompts for device authentication (PIN/biometric); on success,
  /// returns the stored master password so the caller can unlock
  /// normally through MasterPasswordService. Returns null if the user
  /// cancels, authentication fails, or on desktop (unsupported).
  static Future<String?> authenticateAndGetPassword() async {
    if (!_supportsLocalAuth) return null;
    final authenticated = await _authenticate();
    if (!authenticated) return null;
    return PlatformSecureStorage.read(key: _passwordKey);
  }

  static Future<bool> _authenticate() async {
    if (!_supportsLocalAuth) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock your password vault',
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}
