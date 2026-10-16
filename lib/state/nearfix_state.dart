import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/colony_model.dart';
import '../models/service_category.dart';
import '../models/provider_model.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../services/session_service.dart';
import '../services/location_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/firebase_service.dart';
import '../services/subscription_service.dart';
import '../services/sms_service.dart';
import '../main.dart';

enum AppRole {
  resident,
  provider,
  unregistered,
}

enum LocationFilterScope {
  nearbyCity, // Nearby within 5km (auto-fallback to 10km if none found)
  exactColony, // Only exact colony
}

class NearFixState extends ChangeNotifier {
  NearFixState() {
    _initData();
    final bool isTestEnv = WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    if (!isTestEnv) {
      _loadSavedSession();
      _startPeriodicCloudSync();
    }
  }

  // --- Auth & Session State ---
  AppRole _activeRole = AppRole.unregistered;
  UserModel? _currentUser;
  ProviderModel? _currentProvider;
  String _verifiedPhone = '';
  String _currentGeneratedOtp = '112233';
  bool _isLoggedIn = false;
  bool _isSessionLoaded = false;
  bool _isCloudSyncing = false;

  // --- Subscription State ---
  List<PaymentModel> _myPayments = [];
  SubscriptionReminderAlert? _activeReminderAlert;
  bool _isDismissedReminder = false;

  Timer? _syncTimer;

  // --- Colonies & Location State ---
  late List<ColonyModel> _colonies;
  late ColonyModel _currentColony;
  bool _isGpsLocating = false;
  LocationFilterScope _locationScope = LocationFilterScope.nearbyCity;

  // --- Category & Search Filters ---
  ServiceType _selectedCategory = ServiceType.all;
  String _searchQuery = '';
  bool _filterAvailableOnly = false;

  // --- Real Providers & Residents Directories ---
  List<ProviderModel> _allProviders = [];
  List<UserModel> _allResidents = [];

  // Getters
  AppRole get activeRole => _activeRole;
  UserModel? get currentUser => _currentUser;
  ProviderModel? get currentProvider => _currentProvider;
  String get verifiedPhone => _verifiedPhone;
  String get currentGeneratedOtp => _currentGeneratedOtp;
  bool get isLoggedIn => _isLoggedIn;
  bool get isSessionLoaded => _isSessionLoaded;
  bool get isCloudSyncing => _isCloudSyncing;
  bool get isProviderMode => _activeRole == AppRole.provider;

  List<ColonyModel> get colonies => _colonies;
  ColonyModel get currentColony => _currentColony;
  bool get isGpsLocating => _isGpsLocating;
  LocationFilterScope get locationScope => _locationScope;

  ServiceType get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get filterAvailableOnly => _filterAvailableOnly;
  List<ProviderModel> get allProviders => _allProviders;
  List<UserModel> get allResidents => _allResidents;
  List<PaymentModel> get myPayments => _myPayments;
  SubscriptionReminderAlert? get activeReminderAlert =>
      _isDismissedReminder ? null : _activeReminderAlert;
  bool get isDismissedReminder => _isDismissedReminder;

  int _activeRadiusKm = 5;
  bool _isRadiusExpandedTo10Km = false;

  int get activeRadiusKm => _activeRadiusKm;
  bool get isRadiusExpandedTo10Km => _isRadiusExpandedTo10Km;

  List<ProviderModel>? _cachedFilteredProviders;

  @override
  void notifyListeners() {
    _cachedFilteredProviders = null;
    super.notifyListeners();
  }

  /// Smart location-based filtered providers (cached for 60-120fps smooth scrolling)
  List<ProviderModel> get filteredProviders {
    if (_cachedFilteredProviders != null) {
      return _cachedFilteredProviders!;
    }
    _cachedFilteredProviders = _computeFilteredProviders();
    return _cachedFilteredProviders!;
  }

  List<ProviderModel> _computeFilteredProviders() {
    final isResidentBrowsing = _activeRole == AppRole.resident;
    final selfPhone = isResidentBrowsing
        ? _cleanPhone(_verifiedPhone.isNotEmpty ? _verifiedPhone : (_currentUser?.phone ?? ''))
        : '';
    final selfProvId = (isResidentBrowsing && _currentProvider != null && _cleanPhone(_currentProvider!.realPhone) == selfPhone)
        ? _currentProvider!.id
        : '';

    final candidates = _allProviders.where((p) {
      // 0. Restrict self user display (never show own provider card when browsing as resident)
      if (selfPhone.isNotEmpty && _cleanPhone(p.realPhone) == selfPhone) {
        return false;
      }
      if (selfProvId.isNotEmpty && p.id == selfProvId) {
        return false;
      }

      // 1. Category match
      if (_selectedCategory != ServiceType.all &&
          p.category != _selectedCategory) {
        return false;
      }

      // 2. Search match
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesCategory = p.categoryTitle.toLowerCase().contains(query);
        final matchesColony = p.colonyName.toLowerCase().contains(query);
        if (!matchesName && !matchesCategory && !matchesColony) {
          return false;
        }
      }

      // 3. Availability and Subscription Expiry filter (Customer app shows only Available providers)
      if (p.isExpired || p.subscriptionStatus == 'expired') {
        return false;
      }
      if (isResidentBrowsing && !p.isAvailable) {
        return false;
      }
      if (_filterAvailableOnly && !p.isAvailable) {
        return false;
      }

      return true;
    }).map((p) {
      // Calculate live distance from active colony/GPS
      final d = LocationService.calculateDistanceMeters(
        startLat: _currentColony.latitude,
        startLng: _currentColony.longitude,
        endLat: p.latitude != 0 ? p.latitude : _currentColony.latitude,
        endLng: p.longitude != 0 ? p.longitude : _currentColony.longitude,
      );
      return p.copyWith(distanceMeters: d.round());
    }).toList()
      ..sort((a, b) {
        if (a.isAvailable && !b.isAvailable) return -1;
        if (!a.isAvailable && b.isAvailable) return 1;
        return a.distanceMeters.compareTo(b.distanceMeters);
      });

    final cColony = _currentColony.name.toLowerCase().trim();
    final cCity = _currentColony.city.toLowerCase().trim();

    // Helper: checks if provider belongs to same city/district or is same colony
    bool isSameRegion(ProviderModel p) {
      final pColony = p.colonyName.toLowerCase().trim();
      final pCity = p.city.toLowerCase().trim();
      if (pColony == cColony || pColony.contains(cColony) || cColony.contains(pColony)) {
        return true;
      }
      if (cCity.isNotEmpty && cCity != 'current location' && cCity != 'india') {
        if (pCity == cCity || pCity.contains(cCity) || cCity.contains(pCity)) {
          return true;
        }
      }
      // If distance is genuine and within 15km
      if (p.distanceMeters <= 15000 && _currentColony.latitude != 0.0 && p.latitude != 0.0) {
        return true;
      }
      return false;
    }

    // Exact Colony Only Filter Scope
    if (_locationScope == LocationFilterScope.exactColony) {
      _activeRadiusKm = 0;
      _isRadiusExpandedTo10Km = false;
      return candidates.where((p) {
        final pColony = p.colonyName.toLowerCase().trim();
        return pColony == cColony ||
            pColony.contains(cColony) ||
            cColony.contains(pColony) ||
            (p.colonyId.isNotEmpty && p.colonyId == _currentColony.id);
      }).toList();
    }

    // 1. Primary Filter: 5 km Range (or exact same colony)
    final within5km = candidates.where((p) {
      final pColony = p.colonyName.toLowerCase().trim();
      if (pColony.isNotEmpty &&
          (pColony == cColony || pColony.contains(cColony) || cColony.contains(pColony))) {
        return true;
      }
      // Strict rule: Must be in same region AND <= 5000m
      if (!isSameRegion(p)) return false;
      return p.distanceMeters <= 5000;
    }).toList();

    if (within5km.isNotEmpty) {
      _activeRadiusKm = 5;
      _isRadiusExpandedTo10Km = false;
      return within5km;
    }

    // 2. Cascading Fallback Filter: 10 km Range (within same city / region only)
    final within10km = candidates.where((p) {
      if (!isSameRegion(p)) return false;
      return p.distanceMeters <= 10000;
    }).toList();

    if (within10km.isNotEmpty) {
      _activeRadiusKm = 10;
      _isRadiusExpandedTo10Km = true;
      return within10km;
    }

    // 3. Strict Standard Rule: If no technicians available within range in this region, return empty!
    _activeRadiusKm = 10;
    _isRadiusExpandedTo10Km = false;
    return [];
  }

  // --- Real-time Cloud Synchronization ---

  Future<void> syncWithCloud({bool showIndicator = false}) async {
    final bool isTestEnv = WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    if (isTestEnv && !showIndicator && FirebaseService.forceTestUserAvailableInCloud == null) return;

    if (_isCloudSyncing) return;
    if (showIndicator) {
      _isCloudSyncing = true;
      notifyListeners();
    }

    try {
      // 1. Fetch latest live cloud data first
      final cloudData = await CloudSyncService.fetchCloudData();

      // Update Providers from authoritative Cloud Data
      final Map<String, ProviderModel> provMap = {};
      for (final p in cloudData.providers) {
        final pKey = _cleanPhone(p.realPhone).isNotEmpty ? _cleanPhone(p.realPhone) : p.id;
        provMap[pKey] = p;
        _ensureColonyExists(p.colonyId, p.colonyName, p.city, p.latitude, p.longitude);
      }
      _allProviders = provMap.values.toList();
      checkAndApplySubscriptionStatus();
      SessionService.saveAllProviders(_allProviders);

      // Update Residents from authoritative Cloud Data
      final Map<String, UserModel> resMap = {};
      for (final r in cloudData.residents) {
        final rKey = _cleanPhone(r.phone);
        if (rKey.isNotEmpty) {
          resMap[rKey] = r;
        }
      }
      _allResidents = resMap.values.toList();

      // 2. Authoritative check: if currently logged-in account was not found in DB, log out immediately!
      final authPhone = _cleanPhone(_verifiedPhone.isNotEmpty
          ? _verifiedPhone
          : (_currentUser?.phone ?? (_currentProvider?.realPhone ?? '')));
      final activeProvId = _currentProvider?.id ?? '';
      final activeResId = _currentUser?.id ?? '';

      if (_isLoggedIn && authPhone.isNotEmpty) {
        bool existsInDb = false;

        if (_activeRole == AppRole.resident) {
          existsInDb = resMap.containsKey(authPhone) ||
              (activeResId.isNotEmpty && cloudData.residents.any((r) => r.id == activeResId));
        } else if (_activeRole == AppRole.provider) {
          existsInDb = provMap.containsKey(authPhone) ||
              (activeProvId.isNotEmpty && cloudData.providers.any((p) => p.id == activeProvId));
        } else {
          existsInDb = resMap.containsKey(authPhone) || provMap.containsKey(authPhone);
        }

        // Double check against live cloud database endpoint if missing from collections
        if (!existsInDb) {
          final isLive = await CloudSyncService.isUserAvailableInCloud(
            authPhone,
            residentId: activeResId,
            providerId: activeProvId,
          );
          if (isLive) {
            existsInDb = true;
          }
        }

        if (!existsInDb) {
          // User was not found in DB -> Logout and purge immediately!
          purgeUserByPhone(authPhone);
          if (activeProvId.isNotEmpty) {
            _allProviders.removeWhere((p) => p.id == activeProvId);
            SessionService.dequeuePendingProvider(activeProvId);
          }
          if (activeResId.isNotEmpty) {
            _allResidents.removeWhere((r) => r.id == activeResId);
            SessionService.dequeuePendingResident(activeResId);
          }
          _currentUser = null;
          _currentProvider = null;
          _activeRole = AppRole.unregistered;
          _isLoggedIn = false;
          _verifiedPhone = '';
          await SessionService.clearSession();
          try {
            NearFixApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
          } catch (_) {}
          _isCloudSyncing = false;
          notifyListeners();
          return;
        }
      }

      // 3. Drain & Retry Pending Offline Registrations Queue (only for valid users)
      final pendingProviders = await SessionService.getPendingProviders();
      for (final p in pendingProviders) {
        try {
          final ok = await CloudSyncService.publishProvider(p);
          if (ok) {
            await SessionService.dequeuePendingProvider(p.id);
          }
        } catch (_) {}
      }

      final pendingResidents = await SessionService.getPendingResidents();
      for (final r in pendingResidents) {
        try {
          final ok = await CloudSyncService.publishResident(r);
          if (ok) {
            await SessionService.dequeuePendingResident(r.phone);
          }
        } catch (_) {}
      }
    } catch (_) {}

    _isCloudSyncing = false;
    notifyListeners();
  }

  void _ensureColonyExists(String id, String name, String city, double lat, double lng) {
    final exists = _colonies.any((c) =>
        c.id == id || c.name.toLowerCase().trim() == name.toLowerCase().trim());
    if (!exists && name.isNotEmpty) {
      _colonies.add(
        ColonyModel(
          id: id.isNotEmpty ? id : 'colony_${name.hashCode}',
          name: name,
          landmark: 'Area in $city',
          city: city.isNotEmpty ? city : 'Current Location',
          pincode: '',
          latitude: lat,
          longitude: lng,
          activeProvidersCount: 1,
        ),
      );
    }
  }

  void _startPeriodicCloudSync() {
    _syncTimer?.cancel();

    // Auto-sync every 5 minutes directly with Google Firebase Realtime Database
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncWithCloud(showIndicator: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // --- Session Persistence Methods ---

  Future<void> _loadSavedSession() async {
    final saved = await SessionService.loadSession();
    if (saved != null) {
      if (saved.allProviders.isNotEmpty) {
        final Map<String, ProviderModel> map = {};
        for (final p in saved.allProviders) {
          map[p.id] = p;
        }
        for (final p in _allProviders) {
          map[p.id] = p;
        }
        _allProviders = map.values.toList();
      }
      if (saved.colony != null) {
        _currentColony = saved.colony!;
        _ensureColonyInList(_currentColony);
      }
      if (saved.isLoggedIn) {
        _isLoggedIn = true;
        _activeRole = saved.role;
        _currentUser = saved.user;
        _currentProvider = saved.provider;
        if (_currentUser != null) {
          _verifiedPhone = _currentUser!.phone;
        } else if (_currentProvider != null) {
          _verifiedPhone = _currentProvider!.realPhone;
        }
      }
    }

    checkAndApplySubscriptionStatus();
    if (_currentProvider != null) {
      loadProviderPayments(_currentProvider!.id);
    }

    _isSessionLoaded = true;
    notifyListeners();

    // Trigger cloud synchronization and GPS detection asynchronously in background
    // so the initial UI renders instantly with cached local data
    unawaited(syncWithCloud());
    unawaited(detectLiveGpsLocation(silent: true));
  }

  void _ensureColonyInList(ColonyModel colony) {
    final exists =
        _colonies.any((c) => c.id == colony.id || c.name.toLowerCase().trim() == colony.name.toLowerCase().trim());
    if (!exists) {
      _colonies.insert(0, colony);
    }
  }

  // --- Live GPS Location Access ---

  Future<bool> detectLiveGpsLocation({bool silent = false}) async {
    _isGpsLocating = true;
    if (!silent) notifyListeners();

    final liveColony = await LocationService.getLiveLocation();
    _isGpsLocating = false;

    if (liveColony != null) {
      _currentColony = liveColony;
      _ensureColonyInList(liveColony);
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          colonyId: liveColony.id,
          colonyName: liveColony.name,
          city: liveColony.city,
        );
      }
      _saveCurrentSession();
      notifyListeners();
      return true;
    } else {
      if (!silent) notifyListeners();
      return false;
    }
  }

  Future<bool> ensureLocationPermissionPrompt() async {
    final granted = await LocationService.requestLocationPermission();
    if (granted) {
      await detectLiveGpsLocation(silent: false);
      return true;
    }
    return false;
  }

  void setLocationScope(LocationFilterScope scope) {
    _locationScope = scope;
    notifyListeners();
  }

  // --- OTP Verification & Smart Login with Existing Account Check ---

  String requestOtp(String rawPhone) {
    _verifiedPhone = rawPhone.trim();
    final otp = (100000 + Random().nextInt(900000)).toString();
    _currentGeneratedOtp = otp;

    // Trigger cloud sync in background so latest accounts are available immediately
    syncWithCloud(showIndicator: false);

    notifyListeners();
    return otp;
  }

  /// Clean phone to last 10 digits for robust multi-device comparison
  String _cleanPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Checks if a mobile number is already registered in local or cloud database
  Map<String, dynamic> checkExistingAccount(String rawPhone) {
    final targetDigits = _cleanPhone(rawPhone);
    if (targetDigits.isEmpty) return {'exists': false};

    // 1. Check Providers
    for (final p in _allProviders) {
      if (_cleanPhone(p.realPhone) == targetDigits) {
        return {
          'exists': true,
          'role': AppRole.provider,
          'provider': p,
          'colonyName': p.colonyName,
          'city': p.city,
        };
      }
    }

    if (_currentProvider != null && _cleanPhone(_currentProvider!.realPhone) == targetDigits) {
      return {
        'exists': true,
        'role': AppRole.provider,
        'provider': _currentProvider,
        'colonyName': _currentProvider!.colonyName,
        'city': _currentProvider!.city,
      };
    }

    // 2. Check Residents
    for (final r in _allResidents) {
      if (_cleanPhone(r.phone) == targetDigits) {
        return {
          'exists': true,
          'role': AppRole.resident,
          'resident': r,
          'colonyName': r.colonyName,
          'city': r.city,
        };
      }
    }

    if (_currentUser != null && _cleanPhone(_currentUser!.phone) == targetDigits) {
      return {
        'exists': true,
        'role': AppRole.resident,
        'resident': _currentUser,
        'colonyName': _currentUser!.colonyName,
        'city': _currentUser!.city,
      };
    }

    return {'exists': false};
  }

  /// Verify OTP strictly against Firebase Phone Auth, generated OTP code, last sent OTP, or default testing OTP 112233
  bool verifyOtp(String enteredOtp, {bool firebaseVerified = false, String? expectedOtp}) {
    final cleanOtp = enteredOtp.trim();
    final bool matchesCode = cleanOtp.isNotEmpty && (
      cleanOtp == _currentGeneratedOtp ||
      cleanOtp == '112233' ||
      cleanOtp == SmsService.lastSentOtpCode ||
      (expectedOtp != null && cleanOtp == expectedOtp.trim())
    );

    if (firebaseVerified || matchesCode) {
      // Check if this mobile is already registered as a provider or resident
      final account = checkExistingAccount(_verifiedPhone);

      if (account['exists'] == true) {
        _isLoggedIn = true;
        if (account['role'] == AppRole.provider) {
          final prov = account['provider'] as ProviderModel;
          _currentProvider = prov;
          _activeRole = AppRole.provider;
          _currentColony = ColonyModel(
            id: prov.colonyId,
            name: prov.colonyName,
            landmark: 'Colony Area',
            city: prov.city,
            pincode: '560001',
            latitude: prov.latitude,
            longitude: prov.longitude,
            activeProvidersCount: 1,
          );
          _saveCurrentSession();
        } else if (account['role'] == AppRole.resident) {
          final res = account['resident'] as UserModel;
          _currentUser = res;
          _activeRole = AppRole.resident;
          _currentColony = ColonyModel(
            id: res.colonyId,
            name: res.colonyName,
            landmark: res.flatAddress,
            city: res.city,
            pincode: '560001',
            latitude: 12.9298,
            longitude: 77.6749,
            activeProvidersCount: 0,
          );
          _saveCurrentSession();
        }
      } else {
        // Unregistered / new user: keep logged out until registration completes
        _isLoggedIn = false;
        _activeRole = AppRole.unregistered;
        _currentUser = null;
        _currentProvider = null;
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  bool get hasRegisteredProviderProfile {
    final phone = _verifiedPhone.isNotEmpty
        ? _verifiedPhone
        : (_currentUser?.phone ?? (_currentProvider?.realPhone ?? ''));
    final clean = _cleanPhone(phone);
    if (clean.isEmpty) return false;
    return _allProviders.any((p) => _cleanPhone(p.realPhone) == clean) || _currentProvider != null;
  }

  bool get hasRegisteredResidentProfile {
    final phone = _verifiedPhone.isNotEmpty
        ? _verifiedPhone
        : (_currentUser?.phone ?? (_currentProvider?.realPhone ?? ''));
    final clean = _cleanPhone(phone);
    if (clean.isEmpty) return false;
    return _allResidents.any((r) => _cleanPhone(r.phone) == clean) || _currentUser != null;
  }

  /// Seamlessly switch between Resident Mode and Service Provider Mode
  bool switchToRole(AppRole targetRole) {
    if (_activeRole == targetRole) return true;

    final phone = _verifiedPhone.isNotEmpty
        ? _verifiedPhone
        : (_currentUser?.phone ?? (_currentProvider?.realPhone ?? ''));
    final clean = _cleanPhone(phone);

    if (targetRole == AppRole.provider) {
      // Find registered provider profile
      ProviderModel? prov = _currentProvider;
      if (prov == null && clean.isNotEmpty) {
        final matches = _allProviders.where((p) => _cleanPhone(p.realPhone) == clean);
        if (matches.isNotEmpty) {
          prov = matches.first;
        }
      }

      if (prov != null) {
        _currentProvider = prov;
        _activeRole = AppRole.provider;
        _saveCurrentSession();
        notifyListeners();
        return true;
      } else {
        // Needs provider profile registration
        return false;
      }
    } else if (targetRole == AppRole.resident) {
      // Find registered resident profile or auto-generate from provider details
      UserModel? res = _currentUser;
      if (res == null && clean.isNotEmpty) {
        final matches = _allResidents.where((r) => _cleanPhone(r.phone) == clean);
        if (matches.isNotEmpty) {
          res = matches.first;
        }
      }

      if (res == null && _currentProvider != null) {
        res = UserModel(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: _currentProvider!.name,
          avatarUrl: _currentProvider!.avatarUrl,
          colonyId: _currentProvider!.colonyId,
          colonyName: _currentProvider!.colonyName,
          city: _currentProvider!.city,
          flatAddress: 'Colony Resident (${_currentProvider!.colonyName})',
          phone: _currentProvider!.realPhone,
        );
        _allResidents.insert(0, res);
        CloudSyncService.publishResident(res);
      }

      if (res != null) {
        _currentUser = res;
        _activeRole = AppRole.resident;
        _saveCurrentSession();
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  // --- Role Management & Registrations ---

  void setRole(AppRole role) {
    _activeRole = role;
    if (role != AppRole.unregistered) {
      _isLoggedIn = true;
    }
    _saveCurrentSession();
    notifyListeners();
  }

  Future<void> registerResident({
    required String name,
    required ColonyModel colony,
    required String flatAddress,
    required String phone,
    String? avatarUrl,
  }) async {
    final user = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty)
          ? avatarUrl
          : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
      colonyId: colony.id,
      colonyName: colony.name,
      city: colony.city,
      flatAddress: flatAddress,
      phone: phone,
    );

    _currentUser = user;
    _verifiedPhone = phone;
    _currentColony = colony;
    _ensureColonyInList(colony);
    _isLoggedIn = true;
    _activeRole = AppRole.resident;

    // Add to residents list
    final idx = _allResidents.indexWhere((r) => _cleanPhone(r.phone) == _cleanPhone(phone));
    if (idx != -1) {
      _allResidents[idx] = user;
    } else {
      _allResidents.insert(0, user);
    }

    // Synchronize name in Provider profile if exists with same phone
    final pIdx = _allProviders.indexWhere((p) => _cleanPhone(p.realPhone) == _cleanPhone(phone));
    if (pIdx != -1) {
      final updatedProv = _allProviders[pIdx].copyWith(name: name);
      _allProviders[pIdx] = updatedProv;
      if (_currentProvider != null && _cleanPhone(_currentProvider!.realPhone) == _cleanPhone(phone)) {
        _currentProvider = updatedProv;
      }
      SessionService.enqueuePendingProvider(updatedProv);
      CloudSyncService.publishProvider(updatedProv).then((ok) {
        if (ok) SessionService.dequeuePendingProvider(updatedProv.id);
      }).catchError((_) {});
    }

    SessionService.saveResidentSession(
      user: _currentUser!,
      colony: _currentColony,
      allProviders: _allProviders,
    );

    // Save to pending queue for offline/poor connectivity resilience
    await SessionService.enqueuePendingResident(user);

    notifyListeners();

    // Broadcast synchronously to cloud backend (dequeues if success)
    try {
      final ok = await CloudSyncService.publishResident(user);
      if (ok) {
        await SessionService.dequeuePendingResident(user.phone);
      }
    } catch (_) {}

    syncWithCloud(showIndicator: false);
  }

  Future<void> updateResidentProfile({
    required String name,
    required String avatarUrl,
    required ColonyModel colony,
    required String flatAddress,
    required String phone,
  }) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(
      name: name,
      avatarUrl: avatarUrl,
      colonyId: colony.id,
      colonyName: colony.name,
      city: colony.city,
      flatAddress: flatAddress,
      phone: phone,
    );

    _currentUser = updated;
    _currentColony = colony;
    _ensureColonyInList(colony);

    final clean = _cleanPhone(phone);

    final idx = _allResidents.indexWhere((r) => _cleanPhone(r.phone) == clean);
    if (idx != -1) {
      _allResidents[idx] = updated;
    }

    // Synchronize name in Provider profile if exists with same phone
    final pIdx = _allProviders.indexWhere((p) => _cleanPhone(p.realPhone) == clean);
    if (pIdx != -1) {
      final updatedProv = _allProviders[pIdx].copyWith(name: name);
      _allProviders[pIdx] = updatedProv;
      if (_currentProvider != null && _cleanPhone(_currentProvider!.realPhone) == clean) {
        _currentProvider = updatedProv;
      }
      SessionService.enqueuePendingProvider(updatedProv);
      CloudSyncService.publishProvider(updatedProv).then((ok) {
        if (ok) SessionService.dequeuePendingProvider(updatedProv.id);
      }).catchError((_) {});
    }

    SessionService.saveResidentSession(
      user: _currentUser!,
      colony: _currentColony,
      allProviders: _allProviders,
    );

    await SessionService.enqueuePendingResident(updated);

    notifyListeners();

    try {
      final ok = await CloudSyncService.publishResident(updated);
      if (ok) {
        await SessionService.dequeuePendingResident(updated.phone);
      }
    } catch (_) {}
  }

  Future<void> registerServiceProvider({
    required String name,
    required String avatarUrl,
    required ServiceType category,
    required String categoryTitle,
    required int hourlyRate,
    required ColonyModel colony,
    required String phone,
    required String bio,
  }) async {
    final now = DateTime.now();
    final trialEnd = now.add(const Duration(days: 90));

    final newProvider = ProviderModel(
      id: 'prov_${now.millisecondsSinceEpoch}',
      name: name,
      avatarUrl: avatarUrl.isNotEmpty
          ? avatarUrl
          : 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200',
      category: category,
      categoryTitle: categoryTitle,
      hourlyRate: hourlyRate,
      colonyId: colony.id,
      colonyName: colony.name,
      city: colony.city,
      latitude: colony.latitude,
      longitude: colony.longitude,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: phone,
      maskedVirtualNumber: '',
      rating: 5.0,
      reviewsCount: 1,
      bio: bio.isNotEmpty
          ? bio
          : 'Local technician registered in ${colony.name}.',
      subscriptionStatus: 'trial',
      trialEndDate: trialEnd.toIso8601String(),
      subscriptionEndDate: '',
      paymentId: '',
      autoBilling: true,
      createdAt: now.toIso8601String(),
      lastReminderSentDay: 0,
    );

    _currentProvider = newProvider;
    final clean = _cleanPhone(phone);

    // Replace if already exists with same phone or insert
    final pIdx = _allProviders.indexWhere((p) => _cleanPhone(p.realPhone) == clean);
    if (pIdx != -1) {
      _allProviders[pIdx] = newProvider;
    } else {
      _allProviders.insert(0, newProvider);
    }

    // Synchronize name in Resident profile if exists with same phone
    final rIdx = _allResidents.indexWhere((r) => _cleanPhone(r.phone) == clean);
    if (rIdx != -1) {
      final updatedRes = _allResidents[rIdx].copyWith(name: name);
      _allResidents[rIdx] = updatedRes;
      if (_currentUser != null && _cleanPhone(_currentUser!.phone) == clean) {
        _currentUser = updatedRes;
      }
      SessionService.enqueuePendingResident(updatedRes);
      CloudSyncService.publishResident(updatedRes).then((ok) {
        if (ok) SessionService.dequeuePendingResident(updatedRes.phone);
      }).catchError((_) {});
    }

    _verifiedPhone = phone;
    _currentColony = colony;
    _ensureColonyInList(colony);
    _isLoggedIn = true;
    _activeRole = AppRole.provider;

    SessionService.saveProviderSession(
      provider: _currentProvider!,
      colony: _currentColony,
      allProviders: _allProviders,
    );

    // Enqueue to persistent queue for offline/poor connectivity resilience
    await SessionService.enqueuePendingProvider(newProvider);

    notifyListeners();

    // Synchronously broadcast to cloud backend (dequeues if success)
    try {
      final ok = await CloudSyncService.publishProvider(newProvider);
      if (ok) {
        await SessionService.dequeuePendingProvider(newProvider.id);
      }
    } catch (_) {}

    syncWithCloud(showIndicator: false);
  }

  Future<void> updateProviderProfile({
    required String name,
    required String avatarUrl,
    required ServiceType category,
    required String categoryTitle,
    required int hourlyRate,
    required ColonyModel colony,
    required String phone,
    required String bio,
  }) async {
    if (_currentProvider == null) return;

    final updated = _currentProvider!.copyWith(
      name: name,
      avatarUrl: avatarUrl,
      category: category,
      categoryTitle: categoryTitle,
      hourlyRate: hourlyRate,
      colonyId: colony.id,
      colonyName: colony.name,
      city: colony.city,
      latitude: colony.latitude,
      longitude: colony.longitude,
      realPhone: phone,
      bio: bio,
    );

    _currentProvider = updated;
    final clean = _cleanPhone(phone);

    final idx = _allProviders.indexWhere((p) => p.id == updated.id || _cleanPhone(p.realPhone) == clean);
    if (idx != -1) {
      _allProviders[idx] = updated;
    }
    _currentColony = colony;
    _ensureColonyInList(colony);

    // Synchronize name in Resident profile if exists with same phone
    final rIdx = _allResidents.indexWhere((r) => _cleanPhone(r.phone) == clean);
    if (rIdx != -1) {
      final updatedRes = _allResidents[rIdx].copyWith(name: name);
      _allResidents[rIdx] = updatedRes;
      if (_currentUser != null && _cleanPhone(_currentUser!.phone) == clean) {
        _currentUser = updatedRes;
      }
      SessionService.enqueuePendingResident(updatedRes);
      CloudSyncService.publishResident(updatedRes).then((ok) {
        if (ok) SessionService.dequeuePendingResident(updatedRes.phone);
      }).catchError((_) {});
    }

    SessionService.saveProviderSession(
      provider: _currentProvider!,
      colony: _currentColony,
      allProviders: _allProviders,
    );

    await SessionService.enqueuePendingProvider(updated);

    notifyListeners();

    try {
      final ok = await CloudSyncService.publishProvider(updated);
      if (ok) {
        await SessionService.dequeuePendingProvider(updated.id);
      }
    } catch (_) {}
  }

  void toggleMyAvailability() {
    if (_currentProvider == null) return;
    final updated =
        _currentProvider!.copyWith(isAvailable: !_currentProvider!.isAvailable);
    _currentProvider = updated;

    final idx = _allProviders.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _allProviders[idx] = updated;
    }

    SessionService.saveProviderSession(
      provider: _currentProvider!,
      colony: _currentColony,
      allProviders: _allProviders,
    );

    CloudSyncService.publishProvider(updated);
    checkAndApplySubscriptionStatus();
    notifyListeners();
  }

  // --- Subscription Lifecycle, Payments & Reminders ---

  void checkAndApplySubscriptionStatus() {
    bool stateChanged = false;

    // 1. Evaluate all providers in directory
    final List<ProviderModel> evaluatedList = [];
    for (final p in _allProviders) {
      final eval = SubscriptionService.evaluateProviderSubscription(p);
      if (eval.subscriptionStatus != p.subscriptionStatus || eval.isAvailable != p.isAvailable) {
        stateChanged = true;
      }
      evaluatedList.add(eval);
    }
    _allProviders = evaluatedList;

    // 2. Evaluate current provider
    if (_currentProvider != null) {
      final evalCurrent = SubscriptionService.evaluateProviderSubscription(_currentProvider!);
      if (evalCurrent.subscriptionStatus != _currentProvider!.subscriptionStatus ||
          evalCurrent.isAvailable != _currentProvider!.isAvailable) {
        _currentProvider = evalCurrent;
        stateChanged = true;
      }

      // 3. Compute reminder alert for active provider
      _activeReminderAlert = SubscriptionService.getSubscriptionReminder(_currentProvider!);
    }

    if (stateChanged) {
      _saveCurrentSession();
    }
  }

  void dismissReminderAlert() {
    _isDismissedReminder = true;
    notifyListeners();
  }

  void toggleProviderAutoBilling(bool enabled) {
    if (_currentProvider == null) return;
    final updated = _currentProvider!.copyWith(autoBilling: enabled);
    _currentProvider = updated;

    final idx = _allProviders.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _allProviders[idx] = updated;
    }

    _saveCurrentSession();
    CloudSyncService.publishProvider(updated);
    notifyListeners();
  }

  Future<List<PaymentModel>> loadProviderPayments(String providerId) async {
    final local = await SubscriptionService.loadLocalPayments(providerId);
    _myPayments = local;
    notifyListeners();

    // Also fetch latest payments from Cloud
    try {
      final remote = await FirebaseService.fetchPayments(providerId: providerId);
      if (remote.isNotEmpty) {
        final Map<String, PaymentModel> map = {};
        for (final p in local) {
          map[p.id] = p;
        }
        for (final p in remote) {
          map[p.id] = p;
          SubscriptionService.savePaymentLocally(p);
        }
        _myPayments = map.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }
    } catch (_) {}

    return _myPayments;
  }

  Future<Map<String, dynamic>> renewSubscription({
    String gateway = 'Direct UPI / QR',
    double amount = SubscriptionService.totalPlanPriceInr,
    String? transactionId,
    String? utrNumber,
    bool autoBilling = true,
    String? promoCode,
    bool requireAdminVerification = false,
  }) async {
    if (_currentProvider == null) {
      return {'success': false, 'message': 'No active provider profile found.'};
    }

    final result = await SubscriptionService.processPayment(
      provider: _currentProvider!,
      gateway: gateway,
      amount: amount,
      transactionId: transactionId,
      utrNumber: utrNumber,
      autoBilling: autoBilling,
      promoCode: promoCode,
      requireAdminVerification: requireAdminVerification,
    );

    if (result['success'] == true) {
      final updatedProv = result['provider'] as ProviderModel;
      final payment = result['payment'] as PaymentModel;

      _currentProvider = updatedProv;

      // Update in all providers list
      final idx = _allProviders.indexWhere((p) => p.id == updatedProv.id);
      if (idx != -1) {
        _allProviders[idx] = updatedProv;
      } else {
        _allProviders.insert(0, updatedProv);
      }

      // Add payment to local history
      _myPayments.insert(0, payment);
      if (!requireAdminVerification) {
        _activeReminderAlert = null;
        _isDismissedReminder = false;
      }

      _saveCurrentSession();
      notifyListeners();
    }

    return result;
  }

  /// Search and verify a payment record in Database by UTR / Reference ID or Receipt Number
  Future<PaymentModel?> checkPaymentByUtr(String utr) async {
    final clean = utr.trim().replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return null;
    return await SubscriptionService.findPaymentByUtr(clean);
  }

  /// Apply a verified Cloud payment record to current provider to instantly activate profile
  Future<bool> applyVerifiedCloudPayment(PaymentModel payment) async {
    if (_currentProvider == null) return false;

    final now = DateTime.now();
    final expiry = payment.expiresAt.isAfter(now)
        ? payment.expiresAt
        : now.add(const Duration(days: 30));

    final updated = _currentProvider!.copyWith(
      subscriptionStatus: 'active',
      subscriptionEndDate: expiry.toIso8601String(),
      paymentId: payment.id,
      autoBilling: payment.autoBilling,
      isAvailable: true,
      lastReminderSentDay: 0,
    );

    _currentProvider = updated;
    final idx = _allProviders.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _allProviders[idx] = updated;
    } else {
      _allProviders.insert(0, updated);
    }

    if (!_myPayments.any((p) => p.id == payment.id || p.transactionId == payment.transactionId)) {
      _myPayments.insert(0, payment);
    }
    _activeReminderAlert = null;
    _isDismissedReminder = false;

    _saveCurrentSession();
    await FirebaseService.publishProvider(updated);
    notifyListeners();
    return true;
  }

  void _saveCurrentSession() {
    if (_activeRole == AppRole.resident && _currentUser != null) {
      SessionService.saveResidentSession(
        user: _currentUser!,
        colony: _currentColony,
        allProviders: _allProviders,
      );
    } else if (_activeRole == AppRole.provider && _currentProvider != null) {
      SessionService.saveProviderSession(
        provider: _currentProvider!,
        colony: _currentColony,
        allProviders: _allProviders,
      );
    } else {
      SessionService.saveAllProviders(_allProviders);
    }
  }

  void logout() {
    _isLoggedIn = false;
    _activeRole = AppRole.unregistered;
    _currentUser = null;
    _currentProvider = null;
    SessionService.clearSession();
    notifyListeners();
  }

  /// Purge all local memory and session data for a phone number when deleted from cloud
  void purgeUserByPhone(String phone) {
    final clean = _cleanPhone(phone);
    if (clean.isEmpty) return;
    _allProviders.removeWhere((p) => _cleanPhone(p.realPhone) == clean);
    _allResidents.removeWhere((r) => _cleanPhone(r.phone) == clean);
    if (_currentProvider != null && _cleanPhone(_currentProvider!.realPhone) == clean) {
      _currentProvider = null;
      _activeRole = AppRole.unregistered;
      _isLoggedIn = false;
      _verifiedPhone = '';
    }
    if (_currentUser != null && _cleanPhone(_currentUser!.phone) == clean) {
      _currentUser = null;
      _activeRole = AppRole.unregistered;
      _isLoggedIn = false;
      _verifiedPhone = '';
    }
    SessionService.saveAllProviders(_allProviders);
    SessionService.dequeuePendingProvider(clean);
    SessionService.dequeuePendingResident(clean);
    SessionService.clearSession();
    notifyListeners();
  }

  /// Completely wipe all local in-memory data, SharedPreferences cache, and reset to factory unauthenticated state
  Future<void> wipeLocalDataAndCache() async {
    _currentUser = null;
    _currentProvider = null;
    _isLoggedIn = false;
    _activeRole = AppRole.unregistered;
    _verifiedPhone = '';
    _allProviders = [];
    _allResidents = [];
    _myPayments = [];
    _currentGeneratedOtp = '';
    await SessionService.clearAllCache();
    notifyListeners();
  }

  /// Self user account deletion: permanently deletes BOTH service provider and resident accounts
  Future<void> deleteCurrentAccount() async {
    final phone = _verifiedPhone.isNotEmpty
        ? _verifiedPhone
        : (_currentProvider?.realPhone ?? _currentUser?.phone ?? '');
    final clean = _cleanPhone(phone);
    final pId = _currentProvider?.id ?? '';
    final rId = _currentUser?.id ?? '';

    // 1. Delete from Providers list, local persistence, and cloud
    _allProviders.removeWhere(
        (p) => (pId.isNotEmpty && p.id == pId) || (clean.isNotEmpty && _cleanPhone(p.realPhone) == clean));
    await SessionService.saveAllProviders(_allProviders);
    if (pId.isNotEmpty || clean.isNotEmpty) {
      await CloudSyncService.deleteProvider(pId.isNotEmpty ? pId : clean, phone: clean);
    }
    if (clean.isNotEmpty) {
      await SessionService.dequeuePendingProvider(clean);
    }
    if (pId.isNotEmpty) {
      await SessionService.dequeuePendingProvider(pId);
    }

    // 2. Delete from Residents list and cloud
    _allResidents.removeWhere(
        (r) => (rId.isNotEmpty && r.id == rId) || (clean.isNotEmpty && _cleanPhone(r.phone) == clean));
    if (clean.isNotEmpty || rId.isNotEmpty) {
      await CloudSyncService.deleteResident(clean.isNotEmpty ? clean : rId, id: rId);
    }
    if (clean.isNotEmpty) {
      await SessionService.dequeuePendingResident(clean);
    }

    // 3. Purge user records from in-memory lists, pending queues, and local session
    if (clean.isNotEmpty) {
      purgeUserByPhone(clean);
    }
    _verifiedPhone = '';
    logout();
  }

  void setColony(ColonyModel colony) {
    _currentColony = colony;
    _ensureColonyInList(colony);
    _saveCurrentSession();
    syncWithCloud();
    notifyListeners();

    // Asynchronously resolve coordinates if missing or defaulted
    LocationService.resolveColonyCoordinates(colony).then((resolved) {
      if (resolved.latitude != colony.latitude || resolved.longitude != colony.longitude) {
        _currentColony = resolved;
        _ensureColonyInList(resolved);
        _saveCurrentSession();
        notifyListeners();
      }
    }).catchError((_) {});
  }

  Future<void> refreshGpsLocation() async {
    await detectLiveGpsLocation(silent: false);
    await syncWithCloud();
  }

  void selectCategory(ServiceType category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleFilterAvailableOnly() {
    _filterAvailableOnly = !_filterAvailableOnly;
    notifyListeners();
  }


  void _initData() {
    _colonies = [
      const ColonyModel(
        id: 'colony_live',
        name: 'My Live Location',
        landmark: 'GPS Tracking Active',
        city: 'Current Location',
        pincode: '',
        latitude: 0.0,
        longitude: 0.0,
        activeProvidersCount: 0,
      ),
      const ColonyModel(
        id: 'colony_kphb',
        name: 'KPHB Colony',
        landmark: 'Near KPHB Metro Station',
        city: 'Hyderabad',
        pincode: '500072',
        latitude: 17.4933,
        longitude: 78.3995,
        activeProvidersCount: 0,
      ),
      const ColonyModel(
        id: 'colony_kukatpally',
        name: 'Kukatpally',
        landmark: 'Near Metro Station',
        city: 'Hyderabad',
        pincode: '500072',
        latitude: 17.4849,
        longitude: 78.4138,
        activeProvidersCount: 0,
      ),
      const ColonyModel(
        id: 'colony_ktps',
        name: 'KTPS',
        landmark: 'Near Power Station',
        city: 'Palvancha',
        pincode: '507115',
        latitude: 17.5980,
        longitude: 80.6970,
        activeProvidersCount: 0,
      ),
      const ColonyModel(
        id: 'colony_8',
        name: 'Banjara Hills',
        landmark: 'Road No 12',
        city: 'Hyderabad',
        pincode: '500034',
        latitude: 17.4156,
        longitude: 78.4350,
        activeProvidersCount: 0,
      ),
    ];

    _currentColony = _colonies[0];
    _currentUser = null;
    _currentProvider = null;
    _allProviders = [];
    _allResidents = [];
    _activeRole = AppRole.unregistered;
    _isLoggedIn = false;
  }

  // --- Admin Dashboard Actions ---

  /// Admin: Delete a service provider account from local session and Firebase (also clears linked resident if sharing phone)
  Future<void> deleteProviderByAdmin(String providerId) async {
    String phone = '';
    final provIdx = _allProviders.indexWhere((p) => p.id == providerId);
    if (provIdx != -1) {
      phone = _cleanPhone(_allProviders[provIdx].realPhone);
    }
    _allProviders.removeWhere((p) => p.id == providerId || (phone.isNotEmpty && _cleanPhone(p.realPhone) == phone));
    if (_currentProvider != null && (_currentProvider!.id == providerId || (phone.isNotEmpty && _cleanPhone(_currentProvider!.realPhone) == phone))) {
      _currentProvider = null;
      _activeRole = AppRole.unregistered;
      _isLoggedIn = false;
    }
    if (phone.isNotEmpty) {
      _allResidents.removeWhere((r) => _cleanPhone(r.phone) == phone);
      if (_currentUser != null && _cleanPhone(_currentUser!.phone) == phone) {
        _currentUser = null;
        _activeRole = AppRole.unregistered;
        _isLoggedIn = false;
      }
      await FirebaseService.deleteResident(phone);
    }
    await SessionService.saveAllProviders(_allProviders);
    await FirebaseService.deleteProvider(providerId, phone: phone);
    notifyListeners();
  }

  /// Admin: Delete a resident account from local session and Firebase (also clears linked provider if sharing phone)
  Future<void> deleteResidentByAdmin(String phone) async {
    final clean = _cleanPhone(phone);
    _allResidents.removeWhere((r) => _cleanPhone(r.phone) == clean);
    if (_currentUser != null && _cleanPhone(_currentUser!.phone) == clean) {
      _currentUser = null;
      _activeRole = AppRole.unregistered;
      _isLoggedIn = false;
    }
    if (clean.isNotEmpty) {
      String? provId;
      final provIdx = _allProviders.indexWhere((p) => _cleanPhone(p.realPhone) == clean);
      if (provIdx != -1) {
        provId = _allProviders[provIdx].id;
      }
      _allProviders.removeWhere((p) => _cleanPhone(p.realPhone) == clean);
      if (_currentProvider != null && _cleanPhone(_currentProvider!.realPhone) == clean) {
        _currentProvider = null;
        _activeRole = AppRole.unregistered;
        _isLoggedIn = false;
      }
      await SessionService.saveAllProviders(_allProviders);
      if (provId != null) {
        await FirebaseService.deleteProvider(provId, phone: clean);
      }
    }
    await FirebaseService.deleteResident(clean);
    notifyListeners();
  }

  // --- Rewarded Ads & Hybrid AdMob Monetization ---

  /// Add or deduct reward coins from current active resident or provider
  void addRewardCoinsToCurrentUser(int coins) {
    if (_currentUser != null) {
      final currentCoins = _currentUser!.rewardCoins;
      final updatedCoins = (currentCoins + coins) < 0 ? 0 : (currentCoins + coins);
      _currentUser = _currentUser!.copyWith(rewardCoins: updatedCoins);

      // Update in resident list
      final idx = _allResidents.indexWhere((r) => _cleanPhone(r.phone) == _cleanPhone(_currentUser!.phone));
      if (idx != -1) {
        _allResidents[idx] = _currentUser!;
      }

      // Save locally & sync to Firebase
      SessionService.saveCurrentUser(_currentUser);
      FirebaseService.addRewardCoins(_currentUser!.phone, coins);
      notifyListeners();
    }
  }

  /// Toggle or update purchaser status (disables ads dynamically via Remote Config)
  Future<void> setPurchaserStatus(bool isPurchaser) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isPurchaser: isPurchaser);
      SessionService.saveCurrentUser(_currentUser);
    }
    notifyListeners();
  }

  /// Admin: Delete all data across Firebase, reset local state, and wipe all storage cache
  Future<void> clearAllDataByAdmin() async {
    await wipeLocalDataAndCache();
    await FirebaseService.clearAllCloudData();
    notifyListeners();
  }
}

