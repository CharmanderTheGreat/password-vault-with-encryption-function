import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Copies a value to the clipboard, then auto-clears it after a 30s
/// cooldown, showing a persistent countdown notification (visible even
/// outside the app) so the user knows the credential is still live.
class ClipboardCooldownService {
  static const _cooldownSeconds = 30;
  static const _notificationId = 7001;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static Timer? _timer;
  static int _secondsLeft = 0;
  static String? _lastCopiedValue;

  /// Call once at app startup, before copying anything.
  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windowsInit = WindowsInitializationSettings(
      appName: 'Grand Vault',
      appUserModelId: 'com.charmander.grandvault',
      guid: 'b6d3f7b0-9b2b-4e5b-9f2c-1a2b3c4d5e6f',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        windows: windowsInit,
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> copy(String value, {required String label}) async {
    await Clipboard.setData(ClipboardData(text: value));
    _lastCopiedValue = value;
    _secondsLeft = _cooldownSeconds;

    _timer?.cancel();
    await _showNotification(label);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _secondsLeft--;
      if (_secondsLeft <= 0) {
        timer.cancel();
        await _clearClipboardIfUnchanged();
        await _plugin.cancel(id: _notificationId);
        return;
      }
      await _showNotification(label);
    });
  }

  static Future<void> _showNotification(String label) async {
    const androidDetails = AndroidNotificationDetails(
      'clipboard_cooldown',
      'Clipboard cooldown',
      channelDescription:
          'Countdown before a copied username/password is cleared',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
    );
    final windowsDetails =
        WindowsNotificationDetails(audio: WindowsNotificationAudio.silent());
    await _plugin.show(
      id: _notificationId,
      title: '$label copied',
      body: 'Clears from clipboard in $_secondsLeft s',
      notificationDetails: NotificationDetails(
        android: androidDetails,
        windows: windowsDetails,
      ),
    );
  }

  static Future<void> _clearClipboardIfUnchanged() async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == _lastCopiedValue) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
    _lastCopiedValue = null;
  }
}
