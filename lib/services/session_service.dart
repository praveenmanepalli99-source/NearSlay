import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/provider_model.dart';
import '../models/colony_model.dart';
import '../state/nearfix_state.dart';

class SavedSessionData {
  final bool isLoggedIn;
  final AppRole role;
  final UserModel? user;
  final ProviderModel? provider;
  final ColonyModel? colony;
  final List<ProviderModel> allProviders;
  final String verifiedPhone;

  const SavedSessionData({
    required this.isLoggedIn,
    required this.role,
    this.user,
    this.provider,
    this.colony,
    required this.allProviders,
    this.verifiedPhone = '',
  });
}

class SessionService {
  static const String _keyIsLoggedIn = 'nearfix_is_logged_in';
  static const String _keyActiveRole = 'nearfix_active_role';
  static const String _keyUser = 'nearfix_user_data';
  static const String _keyProvider = 'nearfix_provider_data';
  static const String _keyColony = 'nearfix_colony_data';
  static const String _keyAllProviders = 'nearfix_all_providers_list';
  static const String _keyVerifiedPhone = 'nearfix_verified_phone';

  /// Save Resident Session
  static Future<void> saveResidentSession({
    required UserModel user,
    required ColonyModel colony,
    required List<ProviderModel> allProviders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyActiveRole, 'resident');
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    await prefs.setString(_keyColony, jsonEncode(colony.toJson()));
    await prefs.setString(_keyVerifiedPhone, user.phone);
    await saveAllProviders(allProviders);
  }

  /// Save Service Provider Session
  static Future<void> saveProviderSession({
    required ProviderModel provider,
    required ColonyModel colony,
    required List<ProviderModel> allProviders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyActiveRole, 'provider');
    await prefs.setString(_keyProvider, jsonEncode(provider.toJson()));
    await prefs.setString(_keyColony, jsonEncode(colony.toJson()));
    await prefs.setString(_keyVerifiedPhone, provider.realPhone);
    await saveAllProviders(allProviders);
  }

  static const String _keyPendingProviders = 'nearfix_pending_providers_queue';
  static const String _keyPendingResidents = 'nearfix_pending_residents_queue';

  /// Save persistent list of registered providers
  static Future<void> saveAllProviders(List<ProviderModel> allProviders) async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = allProviders.map((p) => p.toJson()).toList();
    await prefs.setString(_keyAllProviders, jsonEncode(listJson));
  }

  /// Save current active user profile updates
  static Future<void> saveCurrentUser(UserModel? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    } else {
      await prefs.remove(_keyUser);
    }
  }

  static String _last10(String phone) {
    final d = phone.replaceAll(RegExp(r'\D'), '');
    return d.length >= 10 ? d.substring(d.length - 10) : d;
  }

  /// Enqueue provider for background cloud sync retry
  static Future<void> enqueuePendingProvider(ProviderModel provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getPendingProviders();
      final cleanPhone = _last10(provider.realPhone);
      list.removeWhere((p) => p.id == provider.id || (cleanPhone.isNotEmpty && _last10(p.realPhone) == cleanPhone));
      list.add(provider);
      final jsonList = list.map((p) => p.toJson()).toList();
      await prefs.setString(_keyPendingProviders, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Retrieve all pending providers awaiting cloud sync
  static Future<List<ProviderModel>> getPendingProviders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyPendingProviders);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((i) => ProviderModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Remove confirmed synced provider from pending queue
  static Future<void> dequeuePendingProvider(String idOrPhone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getPendingProviders();
      final clean = _last10(idOrPhone);
      list.removeWhere((p) => p.id == idOrPhone || (clean.isNotEmpty && _last10(p.realPhone) == clean));
      final jsonList = list.map((p) => p.toJson()).toList();
      await prefs.setString(_keyPendingProviders, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Enqueue resident for background cloud sync retry
  static Future<void> enqueuePendingResident(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getPendingResidents();
      final cleanPhone = _last10(user.phone);
      list.removeWhere((r) => cleanPhone.isNotEmpty && _last10(r.phone) == cleanPhone);
      list.add(user);
      final jsonList = list.map((r) => r.toJson()).toList();
      await prefs.setString(_keyPendingResidents, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Retrieve all pending residents awaiting cloud sync
  static Future<List<UserModel>> getPendingResidents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyPendingResidents);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((i) => UserModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Remove confirmed synced resident from pending queue
  static Future<void> dequeuePendingResident(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getPendingResidents();
      final clean = _last10(phone);
      list.removeWhere((r) => clean.isNotEmpty && _last10(r.phone) == clean);
      final jsonList = list.map((r) => r.toJson()).toList();
      await prefs.setString(_keyPendingResidents, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Load session from local storage on app startup
  static Future<SavedSessionData?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final roleStr = prefs.getString(_keyActiveRole) ?? 'unregistered';

      // Load all stored providers
      List<ProviderModel> allProviders = [];
      final providersJsonStr = prefs.getString(_keyAllProviders);
      if (providersJsonStr != null && providersJsonStr.isNotEmpty) {
        final decoded = jsonDecode(providersJsonStr) as List<dynamic>;
        allProviders = decoded
            .map((item) => ProviderModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      UserModel? user;
      final userStr = prefs.getString(_keyUser);
      if (userStr != null && userStr.isNotEmpty) {
        user = UserModel.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
      }

      ProviderModel? provider;
      final provStr = prefs.getString(_keyProvider);
      if (provStr != null && provStr.isNotEmpty) {
        provider = ProviderModel.fromJson(jsonDecode(provStr) as Map<String, dynamic>);
      }

      ColonyModel? colony;
      final colonyStr = prefs.getString(_keyColony);
      if (colonyStr != null && colonyStr.isNotEmpty) {
        colony = ColonyModel.fromJson(jsonDecode(colonyStr) as Map<String, dynamic>);
      }

      AppRole role = AppRole.unregistered;
      if (roleStr == 'resident') {
        role = AppRole.resident;
      } else if (roleStr == 'provider') {
        role = AppRole.provider;
      }

      final verifiedPhone = prefs.getString(_keyVerifiedPhone) ??
          (user?.phone ?? (provider?.realPhone ?? ''));

      return SavedSessionData(
        isLoggedIn: isLoggedIn,
        role: role,
        user: user,
        provider: provider,
        colony: colony,
        allProviders: allProviders,
        verifiedPhone: verifiedPhone,
      );
    } catch (_) {
      return null;
    }
  }

  /// Update active role
  static Future<void> updateActiveRole(AppRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveRole, role == AppRole.provider ? 'provider' : (role == AppRole.resident ? 'resident' : 'unregistered'));
  }

  /// Clear session on Logout
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.setString(_keyActiveRole, 'unregistered');
    await prefs.remove(_keyUser);
    await prefs.remove(_keyProvider);
    await prefs.remove(_keyVerifiedPhone);
  }

  /// Completely wipe all SharedPreferences cache (session, lists, and pending queues)
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
