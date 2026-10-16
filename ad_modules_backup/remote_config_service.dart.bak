import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/firebase_config.dart';

/// Firebase Remote Config Service for Dynamic Feature Toggles & Native Ad Control
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  static const String _prefShowAds = 'rc_show_ads';
  static const String _prefIsPurchaser = 'rc_is_purchaser';
  static const String _prefNativeAdUnitId = 'rc_native_ad_unit_id';
  static const String _prefNativeAdInterval = 'rc_native_ad_interval';
  static const String _prefLastFetchTime = 'rc_last_fetch_time';

  // Remote Config Default Parameters
  static const bool defaultShowAds = true;
  static const String defaultAdmobAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String defaultNativeAdUnitIdAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String defaultNativeAdUnitIdIos = 'ca-app-pub-3940256099942544/3986624511';
  static const int defaultNativeAdInterval = 3; // Show an inline native ad every 3 provider cards

  bool _showAdsRemote = defaultShowAds;
  bool _isPurchaser = false;
  String _nativeAdUnitId = defaultNativeAdUnitIdAndroid;
  int _nativeAdInterval = defaultNativeAdInterval;
  DateTime? _lastFetchTime;
  int _minimumFetchIntervalSeconds = kDebugMode ? 0 : 3600;

  // --- Getters ---
  /// Dynamic hybrid check: If user is a Purchaser/Paying User, ads are hidden (showAds == false).
  /// Otherwise, returns the Remote Config cloud switch value.
  bool get showAds {
    if (_isPurchaser) {
      return false; // Ad-free experience for paying users / purchasers
    }
    return _showAdsRemote;
  }

  bool get isPurchaser => _isPurchaser;
  String get nativeAdUnitId => _nativeAdUnitId;
  int get nativeAdInterval => _nativeAdInterval;
  DateTime? get lastFetchTime => _lastFetchTime;
  int get minimumFetchIntervalSeconds => _minimumFetchIntervalSeconds;

  /// Set interval in seconds (use 0 for instant updates during testing)
  void setMinimumFetchIntervalInSeconds(int seconds) {
    _minimumFetchIntervalSeconds = seconds;
  }

  /// Initialize Remote Config with local cached values and trigger background fetch
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showAdsRemote = prefs.getBool(_prefShowAds) ?? defaultShowAds;
      _isPurchaser = prefs.getBool(_prefIsPurchaser) ?? false;
      _nativeAdUnitId = prefs.getString(_prefNativeAdUnitId) ?? defaultNativeAdUnitIdAndroid;
      _nativeAdInterval = prefs.getInt(_prefNativeAdInterval) ?? defaultNativeAdInterval;
      
      final lastTimeMs = prefs.getInt(_prefLastFetchTime);
      if (lastTimeMs != null) {
        _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMs);
      }

      // Fetch latest values from Firebase cloud
      await fetchAndActivate();
    } catch (e) {
      debugPrint('[RemoteConfig] Init local error: $e');
    }
  }

  /// Mark user as a paying purchaser (auto disables ads across app)
  Future<void> setPurchaserStatus(bool isPurchaser) async {
    _isPurchaser = isPurchaser;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsPurchaser, isPurchaser);
    } catch (_) {}
  }

  /// Fetch and activate Remote Config from Firebase Cloud
  Future<bool> fetchAndActivate({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && _lastFetchTime != null && _minimumFetchIntervalSeconds > 0) {
      final elapsed = now.difference(_lastFetchTime!).inSeconds;
      if (elapsed < _minimumFetchIntervalSeconds) {
        return true;
      }
    }

    try {
      final baseUrl = FirebaseConfig.cloudBaseUrl;
      final uri = Uri.parse('$baseUrl/remote_config.json');

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('show_ads')) {
            _showAdsRemote = data['show_ads'] == true || data['show_ads'] == 'true';
          }
          if (data.containsKey('native_ad_unit_id') && data['native_ad_unit_id'] is String) {
            _nativeAdUnitId = data['native_ad_unit_id'];
          }
          if (data.containsKey('native_ad_interval')) {
            _nativeAdInterval = (data['native_ad_interval'] as num?)?.toInt() ?? defaultNativeAdInterval;
          }

          // Persist to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_prefShowAds, _showAdsRemote);
          await prefs.setString(_prefNativeAdUnitId, _nativeAdUnitId);
          await prefs.setInt(_prefNativeAdInterval, _nativeAdInterval);
          await prefs.setInt(_prefLastFetchTime, now.millisecondsSinceEpoch);
          _lastFetchTime = now;

          debugPrint('[RemoteConfig] Successfully synced: show_ads=$_showAdsRemote (Purchaser=$_isPurchaser -> effective showAds=$showAds), nativeUnitId=$_nativeAdUnitId');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[RemoteConfig] Remote fetch notice: $e (using local cached config)');
    }

    return false;
  }

  /// Update remote config in Firebase RTDB (Admin control tool)
  Future<bool> updateRemoteConfigInCloud({
    required bool showAds,
    String? nativeAdUnitId,
    int? nativeAdInterval,
  }) async {
    try {
      final baseUrl = FirebaseConfig.cloudBaseUrl;
      final uri = Uri.parse('$baseUrl/remote_config.json');

      final payload = {
        'show_ads': showAds,
        'native_ad_unit_id': nativeAdUnitId ?? _nativeAdUnitId,
        'native_ad_interval': nativeAdInterval ?? _nativeAdInterval,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final res = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        _showAdsRemote = showAds;
        if (nativeAdUnitId != null) _nativeAdUnitId = nativeAdUnitId;
        if (nativeAdInterval != null) _nativeAdInterval = nativeAdInterval;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefShowAds, _showAdsRemote);
        return true;
      }
    } catch (e) {
      debugPrint('[RemoteConfig] Cloud update error: $e');
    }
    return false;
  }
}
