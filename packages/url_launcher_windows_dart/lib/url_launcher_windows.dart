import 'dart:io';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Pure-Dart replacement for the official url_launcher_windows plugin.
///
/// Registered automatically via a dependency_override in the app's
/// pubspec.yaml pointing the `url_launcher_windows` package name at this
/// local package instead of the real (broken) one. Flutter's Dart-only
/// plugin mechanism (`dartPluginClass` in pubspec.yaml) calls
/// [registerWith] at startup, which is all that's needed, no native
/// build step is involved.
class UrlLauncherWindowsDart extends UrlLauncherPlatform {
  static void registerWith() {
    UrlLauncherPlatform.instance = UrlLauncherWindowsDart();
  }

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) {
    return launchUrl(url, const LaunchOptions());
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    try {
      final result = await Process.run(
        'rundll32',
        ['url.dll,FileProtocolHandler', url],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
