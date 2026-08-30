import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Opens a URL in the default browser.
///
/// Deliberately does NOT depend on the `url_launcher` umbrella package
/// directly. Android is covered by `url_launcher_android` (a plain
/// federated implementation, no Windows code in it). Windows is covered
/// by a local pure-Dart replacement package (see
/// packages/url_launcher_windows_dart) substituted in via
/// dependency_overrides in pubspec.yaml, since the official
/// url_launcher_windows has a long-standing native build bug.
///
/// Both register themselves as UrlLauncherPlatform.instance, so this
/// class just calls through the platform interface uniformly.
class AppLauncher {
  static Future<bool> openUrl(String url) async {
    try {
      return await UrlLauncherPlatform.instance
          .launchUrl(url, const LaunchOptions());
    } catch (_) {
      return false;
    }
  }
}
