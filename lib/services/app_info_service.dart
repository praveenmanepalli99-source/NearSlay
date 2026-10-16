import 'package:flutter/services.dart';

/// Service to dynamically retrieve app version and build numbers
/// from the native platform package manager.
class AppInfoService {
  static const MethodChannel _channel = MethodChannel('com.nearfix.app/app_info');

  static const String currentVersion = '1.0.41';
  static const String currentBuildNumber = '48';

  /// Returns a map containing 'version' and 'buildNumber'
  static Future<Map<String, String>> getAppInfo() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
      if (res != null) {
        final version = res['version']?.toString() ?? currentVersion;
        final buildNumber = res['buildNumber']?.toString() ?? currentBuildNumber;
        return {
          'version': version,
          'buildNumber': buildNumber,
        };
      }
    } catch (_) {}
    return {
      'version': currentVersion,
      'buildNumber': currentBuildNumber,
    };
  }

  /// Formats the version string for UI display (e.g. "App v1.0.17")
  static Future<String> getDisplayVersion() async {
    final info = await getAppInfo();
    return 'App v${info['version']}';
  }

  /// Formats full version string with build code (e.g. "App v1.0.17+22")
  static Future<String> getFullDisplayVersion() async {
    final info = await getAppInfo();
    return 'App v${info['version']}+${info['buildNumber']}';
  }
}
