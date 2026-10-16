import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseConfig {
  static const String _prefCustomCloudUrl = 'nearfix_custom_cloud_url';
  static const String _prefDynamicApiUrl = 'nearfix_dynamic_production_api_url';

  /// Primary Production Google Firebase Realtime Database REST URL (24/7 Cloud)
  static const String defaultFirebaseRealtimeDbUrl =
      'https://nearslay-default-rtdb.firebaseio.com';

  /// Production REST API Gateway URL
  static String dynamicProductionApiUrl = '';

  /// Active production Firebase Realtime Database URL
  static String get productionApiUrl =>
      customCloudUrl.isNotEmpty
          ? customCloudUrl
          : (dynamicProductionApiUrl.isNotEmpty ? dynamicProductionApiUrl : defaultFirebaseRealtimeDbUrl);

  /// Dedicated Local & LAN Cloud Server endpoints (for local development fallback)
  static const String localServerUrl = 'http://localhost:5000/api';
  static const String loopbackUrl = 'http://127.0.0.1:5000/api';
  static const String emulatorServerUrl = 'http://10.0.2.2:5000/api';
  static const String lanServerUrl = 'http://192.168.1.4:5000/api';

  static String customCloudUrl = '';

  /// Initialize and load saved custom cloud URL
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      customCloudUrl = prefs.getString(_prefCustomCloudUrl) ?? '';
      
      final savedDynamicUrl = prefs.getString(_prefDynamicApiUrl) ?? '';
      if (savedDynamicUrl.isNotEmpty && savedDynamicUrl.startsWith('http')) {
        dynamicProductionApiUrl = savedDynamicUrl;
      }
    } catch (_) {}
  }

  /// Save custom Firebase / REST API URL manually set by admin
  static Future<void> saveCustomCloudUrl(String url) async {
    customCloudUrl = url.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (customCloudUrl.isEmpty) {
        await prefs.remove(_prefCustomCloudUrl);
      } else {
        await prefs.setString(_prefCustomCloudUrl, customCloudUrl);
      }
    } catch (_) {}
  }

  /// Save dynamically discovered Production Backend API URL
  static Future<void> saveDynamicApiUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isNotEmpty && clean.startsWith('http')) {
      dynamicProductionApiUrl = clean;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefDynamicApiUrl, clean);
      } catch (_) {}
    }
  }

  /// All candidate cloud endpoints queried and broadcast in parallel
  static List<String> get candidateUrls {
    final List<String> urls = [];

    // 1. User/Admin-configured custom cloud URL (highest priority)
    if (customCloudUrl.isNotEmpty) {
      urls.add(customCloudUrl);
    }

    // 2. Production Google Firebase Realtime Database (Enterprise 24/7 Cloud)
    if (!urls.contains(defaultFirebaseRealtimeDbUrl)) {
      urls.add(defaultFirebaseRealtimeDbUrl);
    }

    // 3. Local development endpoints (when in debug mode or testing)
    if (kDebugMode) {
      for (final devUrl in [localServerUrl, loopbackUrl, emulatorServerUrl, lanServerUrl]) {
        if (!urls.contains(devUrl)) {
          urls.add(devUrl);
        }
      }
    }

    return urls;
  }

  /// Returns the primary active cloud database base URL
  static String get cloudBaseUrl =>
      customCloudUrl.isNotEmpty ? customCloudUrl : defaultFirebaseRealtimeDbUrl;

  /// Custom Firebase configuration check
  static bool get isCustomFirebaseConfigured => customCloudUrl.isNotEmpty;
}
