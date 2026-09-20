import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Drop-in replacement for FlutterSecureStorage's read/write/delete API.
///
/// WHY THIS EXISTS: flutter_secure_storage_windows has a long-standing,
/// still-unresolved native (C++) build bug on current toolchains (TCHAR
/// / std::wstring mismatches that fail to compile). Because Flutter
/// compiles a plugin's native code for every declared platform whether
/// or not the Dart side calls it, simply avoiding the calls in Dart does
/// not avoid the broken compile — the dependency has to not be present
/// at all for Windows builds to succeed. So this app does not depend on
/// flutter_secure_storage for any platform, and uses this instead.
///
/// HOW IT STORES DATA: a single JSON file inside this app's own,
/// per-user application-support folder (via path_provider), which the
/// OS already restricts to the logged-in user account (NTFS permissions
/// on Windows, per-app sandboxing on Android). This is NOT hardware-
/// backed encryption the way Android Keystore is — it relies on OS-level
/// file permissions rather than an extra encryption layer, the same
/// trust boundary this app already relies on for its shared_preferences
/// data. The actual vault entries remain separately encrypted with
/// AES-256-GCM regardless of how this file is protected.
class PlatformSecureStorage {
  static Map<String, String>? _cache;

  static Future<void> write({required String key, required String value}) async {
    final data = await _load();
    data[key] = value;
    await _save(data);
  }

  static Future<String?> read({required String key}) async {
    final data = await _load();
    return data[key];
  }

  static Future<void> delete({required String key}) async {
    final data = await _load();
    data.remove(key);
    await _save(data);
  }

  static Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;

    final file = await _storeFile();
    if (!await file.exists()) {
      _cache = {};
      return _cache!;
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _cache = decoded.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      // Corrupt or unreadable file, start fresh rather than crash.
      _cache = {};
    }
    return _cache!;
  }

  static Future<void> _save(Map<String, String> data) async {
    _cache = data;
    final file = await _storeFile();
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  static Future<File> _storeFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'secure_store.json'));
  }
}
