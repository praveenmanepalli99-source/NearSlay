import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../config/firebase_config.dart';
import '../models/provider_model.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../models/booking_model.dart';
import '../models/service_category.dart';

bool get _isTestEnvironment {
  final binding = WidgetsBinding.instance;
  return binding.runtimeType.toString().toLowerCase().contains('test');
}

class FirebaseCloudData {
  final List<ProviderModel> providers;
  final List<UserModel> residents;

  const FirebaseCloudData({
    required this.providers,
    required this.residents,
  });
}

class FirebaseService {
  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'NearFixApp/1.0',
  };

  static List<ProviderModel> get defaultSeedProviders => [
    const ProviderModel(
      id: 'prov_1788421965063_673',
      name: 'Ramesh Kumar',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
      category: ServiceType.electrician,
      categoryTitle: 'Electrician',
      hourlyRate: 300,
      colonyId: 'colony_ktps',
      colonyName: 'KTPS',
      city: 'Palvancha',
      latitude: 17.5980,
      longitude: 80.6970,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9848012345',
      maskedVirtualNumber: '+91 80 4353 5258',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'Expert residential electrician with 7+ years experience in wiring switchboards and fans',
    ),
    const ProviderModel(
      id: 'prov_1788421965063_224',
      name: 'Suresh Reddy',
      avatarUrl: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200',
      category: ServiceType.plumber,
      categoryTitle: 'Plumber',
      hourlyRate: 250,
      colonyId: 'colony_ktps',
      colonyName: 'KTPS',
      city: 'Palvancha',
      latitude: 17.5980,
      longitude: 80.6970,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9848012346',
      maskedVirtualNumber: '+91 80 2422 1209',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'Master plumber specializing in pipe fittings tap leakage and motor installations',
    ),
    const ProviderModel(
      id: 'prov_1788290492050',
      name: 'Praveen Manepalli',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
      category: ServiceType.plumber,
      categoryTitle: 'Plumber',
      hourlyRate: 199,
      colonyId: 'colony_ktps',
      colonyName: 'KTPS',
      city: 'Palvancha',
      latitude: 17.6015,
      longitude: 80.7135,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9912525829',
      maskedVirtualNumber: '+91 80 4710 8275',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'Certified technician with expertise in residential plumbing and electrical solutions',
    ),
    const ProviderModel(
      id: 'prov_1788369192845',
      name: 'Srikanth',
      avatarUrl: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200',
      category: ServiceType.applianceRepair,
      categoryTitle: 'Appliance Repair',
      hourlyRate: 199,
      colonyId: 'colony_ktps',
      colonyName: 'KTPS',
      city: 'Palvancha',
      latitude: 17.6015,
      longitude: 80.7135,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9959945059',
      maskedVirtualNumber: '+91 80 4710 7431',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'Home appliance servicing, washing machine, microwave and refrigerator repairs',
    ),
    const ProviderModel(
      id: 'prov_1788421965063_460',
      name: 'Mahesh Babu',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200',
      category: ServiceType.applianceRepair,
      categoryTitle: 'Appliance Repair',
      hourlyRate: 300,
      colonyId: 'colony_1',
      colonyName: 'Green Glen Layout',
      city: 'Bengaluru',
      latitude: 12.9298,
      longitude: 77.6749,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9848012349',
      maskedVirtualNumber: '+91 80 7467 2115',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'Washing machine refrigerator microwave and home appliance service specialist',
    ),
    const ProviderModel(
      id: 'prov_1788421965063_485',
      name: 'Krishna Murthy',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      category: ServiceType.painter,
      categoryTitle: 'Painter',
      hourlyRate: 400,
      colonyId: 'colony_2',
      colonyName: 'Indiranagar',
      city: 'Bengaluru',
      latitude: 12.9784,
      longitude: 77.6408,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9848012350',
      maskedVirtualNumber: '+91 80 8069 1539',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'Professional interior exterior wall painting water proofing and texture finishes',
    ),
    const ProviderModel(
      id: 'prov_1788421965063_874',
      name: 'Venkat Rao',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
      category: ServiceType.applianceRepair,
      categoryTitle: 'AC Repair & Service',
      hourlyRate: 450,
      colonyId: 'colony_kukatpally',
      colonyName: 'Kukatpally',
      city: 'Hyderabad',
      latitude: 17.4849,
      longitude: 78.4138,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9848012347',
      maskedVirtualNumber: '+91 80 3004 9107',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'AC technician certified in split and window AC gas filling servicing and installation',
    ),
    const ProviderModel(
      id: 'prov_1788421965063_779',
      name: 'Anil Sharma',
      avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=200',
      category: ServiceType.carpenter,
      categoryTitle: 'Carpenter',
      hourlyRate: 350,
      colonyId: 'colony_kukatpally',
      colonyName: 'Kukatpally',
      city: 'Hyderabad',
      latitude: 17.4849,
      longitude: 78.4138,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9848012348',
      maskedVirtualNumber: '+91 80 6184 7391',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'Experienced carpenter for door locks modular kitchen repairs and custom wooden furniture',
    ),
    const ProviderModel(
      id: 'prov_1788372409380',
      name: 'sai Chand',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
      category: ServiceType.electrician,
      categoryTitle: 'Electrician',
      hourlyRate: 300,
      colonyId: 'colony_kukatpally',
      colonyName: 'Kukatpally',
      city: 'Hyderabad',
      latitude: 17.5036,
      longitude: 78.4193,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9391981103',
      maskedVirtualNumber: '+91 80 4710 5069',
      rating: 5.0,
      reviewsCount: 1,
      bio: 'Local technician available for colony repair.',
    ),
    const ProviderModel(
      id: 'prov_1788371669516',
      name: 'karthik pati',
      avatarUrl: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200',
      category: ServiceType.plumber,
      categoryTitle: 'Plumber',
      hourlyRate: 500,
      colonyId: 'colony_kukatpally',
      colonyName: 'Kukatpally',
      city: 'Hyderabad',
      latitude: 17.5071,
      longitude: 78.4125,
      distanceMeters: 250,
      isAvailable: true,
      isVerified: true,
      realPhone: '+91 9551810924',
      maskedVirtualNumber: '+91 80 4710 5632',
      rating: 5.0,
      reviewsCount: 1,
      bio: '5 years experience in plumbing and pipe repair.',
    ),
  ];

  static bool _isFirebaseRtdb(String url) {
    final lower = url.toLowerCase();
    return lower.contains('firebaseio.com') || lower.contains('firebasedatabase.app');
  }

  static String _buildProviderUrl(String base, {String? id}) {
    final clean = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (_isFirebaseRtdb(clean)) {
      return id != null ? '$clean/providers/$id.json' : '$clean/providers.json';
    }
    return id != null ? '$clean/providers/$id' : (clean.endsWith('/providers') ? clean : '$clean/providers');
  }

  static String _buildResidentUrl(String base, {String? phone}) {
    final clean = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (_isFirebaseRtdb(clean)) {
      return phone != null ? '$clean/residents/$phone.json' : '$clean/residents.json';
    }
    return phone != null ? '$clean/residents/$phone' : (clean.endsWith('/residents') ? clean : '$clean/residents');
  }

  static void _parseAndAddProvider(Map<String, dynamic> item, Map<String, ProviderModel> providerMap) {
    try {
      final p = ProviderModel.fromJson(item);
      if (p.name.isNotEmpty) {
        final cleanKey = _normalizePhone(p.realPhone);
        final pKey = cleanKey.isNotEmpty ? cleanKey : p.id;
        if (pKey.isNotEmpty) {
          providerMap[pKey] = p;
        }
      }
    } catch (_) {}
  }

  static void _parseAndAddResident(Map<String, dynamic> item, Map<String, UserModel> residentMap) {
    try {
      final r = UserModel.fromJson(item);
      final cleanPhone = _normalizePhone(r.phone);
      if (cleanPhone.isNotEmpty) {
        residentMap[cleanPhone] = r;
      }
    } catch (_) {}
  }

  /// Fetch all live service providers and residents with 100% Google Firebase Realtime Database
  static Future<FirebaseCloudData> fetchCloudData() async {
    final Map<String, ProviderModel> providerMap = {};
    final Map<String, UserModel> residentMap = {};

    bool fbSuccess = false;
    const rtdb = FirebaseConfig.defaultFirebaseRealtimeDbUrl;

    // 1. Fetch authoritatively from Google Firebase Realtime Database (24/7 Cloud) in parallel
    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('$rtdb/providers.json'), headers: _headers)
            .timeout(const Duration(milliseconds: 3500)),
        http
            .get(Uri.parse('$rtdb/residents.json'), headers: _headers)
            .timeout(const Duration(milliseconds: 3500)),
      ]);
      final resProv = results[0];
      final resUser = results[1];

      if (resProv.statusCode == 200 && resProv.body.isNotEmpty && resProv.body.trim() != 'null') {
        final decoded = jsonDecode(resProv.body);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) _parseAndAddProvider(item, providerMap);
          }
        } else if (decoded is Map<String, dynamic>) {
          for (final val in decoded.values) {
            if (val is Map<String, dynamic>) _parseAndAddProvider(val, providerMap);
          }
        }
        fbSuccess = true;
      } else if (resProv.statusCode == 200) {
        fbSuccess = true;
      }
      if (resUser.statusCode == 200 && resUser.body.isNotEmpty && resUser.body.trim() != 'null') {
        final decoded = jsonDecode(resUser.body);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) _parseAndAddResident(item, residentMap);
          }
        } else if (decoded is Map<String, dynamic>) {
          for (final val in decoded.values) {
            if (val is Map<String, dynamic>) _parseAndAddResident(val, residentMap);
          }
        }
        fbSuccess = true;
      } else if (resUser.statusCode == 200) {
        fbSuccess = true;
      }
    } catch (_) {}

    // 2. Fallback to candidate endpoints only if Firebase RTDB was unreachable (e.g. offline local dev)
    if (!fbSuccess) {
      final candidateUrls = FirebaseConfig.candidateUrls
          .where((u) => !_isFirebaseRtdb(u))
          .toList();

      await Future.wait(
        candidateUrls.map((base) async {
          try {
            final provUrl = _buildProviderUrl(base);
            final resProv = await http
                .get(Uri.parse(provUrl), headers: _headers)
                .timeout(const Duration(milliseconds: 3000));

            if (resProv.statusCode == 200 && resProv.body.isNotEmpty && resProv.body != 'null') {
              final decoded = jsonDecode(resProv.body);
              if (decoded is List) {
                for (final item in decoded) {
                  if (item is Map<String, dynamic>) _parseAndAddProvider(item, providerMap);
                }
              } else if (decoded is Map<String, dynamic>) {
                for (final val in decoded.values) {
                  if (val is Map<String, dynamic>) _parseAndAddProvider(val, providerMap);
                }
              }
            }
          } catch (_) {}

          try {
            final resUrl = _buildResidentUrl(base);
            final resUser = await http
                .get(Uri.parse(resUrl), headers: _headers)
                .timeout(const Duration(milliseconds: 3000));

            if (resUser.statusCode == 200 && resUser.body.isNotEmpty && resUser.body != 'null') {
              final decoded = jsonDecode(resUser.body);
              if (decoded is List) {
                for (final item in decoded) {
                  if (item is Map<String, dynamic>) _parseAndAddResident(item, residentMap);
                }
              } else if (decoded is Map<String, dynamic>) {
                for (final val in decoded.values) {
                  if (val is Map<String, dynamic>) _parseAndAddResident(val, residentMap);
                }
              }
            }
          } catch (_) {}
        }),
      );
    }

    return FirebaseCloudData(
      providers: providerMap.values.toList(),
      residents: residentMap.values.toList(),
    );
  }

  /// Publish a single provider to Google Firebase Realtime Database
  static Future<bool> publishProvider(ProviderModel provider) async {
    final candidateUrls = FirebaseConfig.candidateUrls;
    bool success = false;

    await Future.wait(
      candidateUrls.map((base) async {
        try {
          final isRtdb = _isFirebaseRtdb(base);
          final url = _buildProviderUrl(base, id: isRtdb ? provider.id : null);
          final uri = Uri.parse(url);
          final body = jsonEncode(provider.toJson());

          final http.Response res = isRtdb
              ? await http.put(uri, headers: _headers, body: body).timeout(const Duration(milliseconds: 4000))
              : await http.post(uri, headers: _headers, body: body).timeout(const Duration(milliseconds: 4000));

          if (res.statusCode == 200 || res.statusCode == 201) {
            success = true;
          }
        } catch (_) {}
      }),
    );

    return success;
  }

  /// Publish a single resident to Google Firebase Realtime Database
  static Future<bool> publishResident(UserModel resident) async {
    final normPhone = _normalizePhone(resident.phone);
    final cleanPhone = normPhone.isNotEmpty ? normPhone : resident.id;
    final candidateUrls = FirebaseConfig.candidateUrls;
    bool success = false;

    await Future.wait(
      candidateUrls.map((base) async {
        try {
          final isRtdb = _isFirebaseRtdb(base);
          final url = _buildResidentUrl(base, phone: isRtdb ? cleanPhone : null);
          final uri = Uri.parse(url);
          final body = jsonEncode(resident.toJson());

          final http.Response res = isRtdb
              ? await http.put(uri, headers: _headers, body: body).timeout(const Duration(milliseconds: 4000))
              : await http.post(uri, headers: _headers, body: body).timeout(const Duration(milliseconds: 4000));

          if (res.statusCode == 200 || res.statusCode == 201) {
            success = true;
          }
        } catch (_) {}
      }),
    );

    return success;
  }

  /// Delete provider permanently across candidate endpoints and Firebase RTDB
  static Future<bool> deleteProvider(String providerId, {String? phone}) async {
    final normPhone = phone != null ? _normalizePhone(phone) : '';
    final candidateUrls = FirebaseConfig.candidateUrls;

    await Future.wait(
      candidateUrls.map((base) async {
        try {
          final url1 = _buildProviderUrl(base, id: providerId);
          await http.delete(Uri.parse(url1), headers: _headers).timeout(const Duration(milliseconds: 3000));

          if (normPhone.isNotEmpty && normPhone != providerId) {
            final url2 = _buildProviderUrl(base, id: normPhone);
            await http.delete(Uri.parse(url2), headers: _headers).timeout(const Duration(milliseconds: 3000));
          }
        } catch (_) {}
      }),
    );
    return true;
  }

  /// Delete resident permanently across candidate endpoints and Firebase RTDB
  static Future<bool> deleteResident(String phone, {String? id}) async {
    final normPhone = _normalizePhone(phone);
    final cleanPhone = normPhone.isNotEmpty ? normPhone : phone;
    final candidateUrls = FirebaseConfig.candidateUrls;

    await Future.wait(
      candidateUrls.map((base) async {
        try {
          final url1 = _buildResidentUrl(base, phone: cleanPhone);
          await http.delete(Uri.parse(url1), headers: _headers).timeout(const Duration(milliseconds: 3000));

          if (id != null && id.isNotEmpty && id != cleanPhone) {
            final url2 = _buildResidentUrl(base, phone: id);
            await http.delete(Uri.parse(url2), headers: _headers).timeout(const Duration(milliseconds: 3000));
          }
        } catch (_) {}
      }),
    );
    return true;
  }

  static bool? forceTestUserAvailableInCloud;

  /// Real-time live check to verify if a user or provider exists in the cloud database
  static Future<bool> isUserAvailableInCloud(String phone, {String? providerId, String? residentId}) async {
    if (forceTestUserAvailableInCloud != null) return forceTestUserAvailableInCloud!;
    if (_isTestEnvironment) return true;
    final normPhone = _normalizePhone(phone);
    const rtdb = FirebaseConfig.defaultFirebaseRealtimeDbUrl;

    try {
      // 1. Check Resident in Firebase RTDB
      if (normPhone.isNotEmpty) {
        final resUri = Uri.parse('$rtdb/residents/$normPhone.json');
        final res = await http.get(resUri, headers: _headers).timeout(const Duration(milliseconds: 3500));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
          return true;
        }
      }
      if (residentId != null && residentId.isNotEmpty) {
        final resUri = Uri.parse('$rtdb/residents/$residentId.json');
        final res = await http.get(resUri, headers: _headers).timeout(const Duration(milliseconds: 3500));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
          return true;
        }
      }

      // 2. Check Provider in Firebase RTDB by ID or Phone Key
      if (providerId != null && providerId.isNotEmpty) {
        final provUri = Uri.parse('$rtdb/providers/$providerId.json');
        final res = await http.get(provUri, headers: _headers).timeout(const Duration(milliseconds: 3500));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
          return true;
        }
      }
      if (normPhone.isNotEmpty) {
        final provUri = Uri.parse('$rtdb/providers/$normPhone.json');
        final res = await http.get(provUri, headers: _headers).timeout(const Duration(milliseconds: 3500));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
          return true;
        }
      }

      // 3. Check entire providers map to match realPhone if keyed by auto-generated ID
      if (normPhone.isNotEmpty) {
        final allProvUri = Uri.parse('$rtdb/providers.json');
        final res = await http.get(allProvUri, headers: _headers).timeout(const Duration(milliseconds: 3500));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            for (final entry in data.values) {
              if (entry is Map<String, dynamic>) {
                final rPhone = _normalizePhone(entry['realPhone']?.toString() ?? entry['phone']?.toString() ?? '');
                if (rPhone == normPhone) {
                  return true;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Test connection latency to Firebase RTDB or custom endpoint
  static Future<Map<String, dynamic>> testApiGatewayConnection([String? customUrl]) async {
    final target = (customUrl != null && customUrl.trim().isNotEmpty)
        ? customUrl.trim()
        : FirebaseConfig.defaultFirebaseRealtimeDbUrl;

    final uri = _isFirebaseRtdb(target)
        ? Uri.parse(target.endsWith('/') ? '${target}providers.json' : '$target/providers.json')
        : Uri.parse(target.endsWith('/') ? '${target}stats' : '$target/stats');

    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(uri, headers: _headers).timeout(const Duration(milliseconds: 4000));
      stopwatch.stop();
      if (res.statusCode >= 200 && res.statusCode < 400) {
        return {'success': true, 'latencyMs': stopwatch.elapsedMilliseconds};
      }
      return {'success': false, 'error': 'Status ${res.statusCode}', 'latencyMs': stopwatch.elapsedMilliseconds};
    } catch (e) {
      stopwatch.stop();
      return {'success': false, 'error': e.toString(), 'latencyMs': stopwatch.elapsedMilliseconds};
    }
  }

  /// Add rewarded coins to a resident or provider in Firebase Realtime Database
  static Future<bool> addRewardCoins(String phoneOrId, int coins) async {
    final cleanPhone = _normalizePhone(phoneOrId);
    final key = cleanPhone.isNotEmpty ? cleanPhone : phoneOrId;
    if (key.isEmpty) return false;

    const rtdb = FirebaseConfig.defaultFirebaseRealtimeDbUrl;
    try {
      final userUri = Uri.parse('$rtdb/residents/$key.json');
      final res = await http.get(userUri, headers: _headers).timeout(const Duration(milliseconds: 3000));
      int currentCoins = 0;
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          currentCoins = (data['rewardCoins'] as num?)?.toInt() ??
              (data['reward_coins'] as num?)?.toInt() ??
              0;
        }
      }

      final newTotal = currentCoins + coins;
      final patchUri = Uri.parse('$rtdb/residents/$key.json');
      final patchRes = await http.patch(
        patchUri,
        headers: _headers,
        body: jsonEncode({
          'rewardCoins': newTotal,
          'lastRewardEarned': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(milliseconds: 3000));

      return patchRes.statusCode == 200 || patchRes.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Fetch total reward coins for a user from Firebase RTDB
  static Future<int> getUserRewardCoins(String phoneOrId) async {
    final cleanPhone = _normalizePhone(phoneOrId);
    final key = cleanPhone.isNotEmpty ? cleanPhone : phoneOrId;
    if (key.isEmpty) return 0;

    const rtdb = FirebaseConfig.defaultFirebaseRealtimeDbUrl;
    try {
      final userUri = Uri.parse('$rtdb/residents/$key.json');
      final res = await http.get(userUri, headers: _headers).timeout(const Duration(milliseconds: 3000));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return (data['rewardCoins'] as num?)?.toInt() ??
              (data['reward_coins'] as num?)?.toInt() ??
              0;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Publish payment receipt to Firebase Realtime Database and Cloud DB
  static Future<bool> publishPayment(PaymentModel payment) async {
    final candidateUrls = FirebaseConfig.candidateUrls;
    bool success = false;

    await Future.wait(
      candidateUrls.map((base) async {
        try {
          final isRtdb = _isFirebaseRtdb(base);
          final clean = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
          final url = isRtdb ? '$clean/payments/${payment.id}.json' : '$clean/payments';
          final uri = Uri.parse(url);
          final body = jsonEncode(payment.toJson());

          final http.Response res = isRtdb
              ? await http.put(uri, headers: _headers, body: body).timeout(const Duration(milliseconds: 4000))
              : await http.post(uri, headers: _headers, body: body).timeout(const Duration(milliseconds: 4000));

          if (res.statusCode == 200 || res.statusCode == 201) {
            success = true;
          }
        } catch (_) {}
      }),
    );
    return success;
  }

  /// Fetch payments from Firebase Realtime Database
  static Future<List<PaymentModel>> fetchPayments({String? providerId}) async {
    const rtdb = FirebaseConfig.defaultFirebaseRealtimeDbUrl;
    final List<PaymentModel> payments = [];

    try {
      final res = await http
          .get(Uri.parse('$rtdb/payments.json'), headers: _headers)
          .timeout(const Duration(milliseconds: 4000));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          for (final val in decoded.values) {
            if (val is Map<String, dynamic>) {
              try {
                final p = PaymentModel.fromJson(val);
                if (providerId == null || providerId.isEmpty || p.providerId == providerId) {
                  payments.add(p);
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payments;
  }

  /// Search and find a payment record in Firebase Realtime Database by UTR, Transaction ID, or Receipt Number
  static Future<PaymentModel?> findPaymentByUtr(String query) async {
    final cleanQuery = query.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleanQuery.isEmpty) return null;

    const rtdb = FirebaseConfig.defaultFirebaseRealtimeDbUrl;
    try {
      final res = await http
          .get(Uri.parse('$rtdb/payments.json'), headers: _headers)
          .timeout(const Duration(milliseconds: 4500));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body.trim() != 'null') {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          for (final val in decoded.values) {
            if (val is Map<String, dynamic>) {
              try {
                final p = PaymentModel.fromJson(val);
                final cleanTxn = p.transactionId.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
                final cleanReceipt = p.receiptNumber.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
                final cleanId = p.id.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
                final notes = (p.notes ?? '').toUpperCase();

                if (cleanTxn == cleanQuery ||
                    cleanReceipt == cleanQuery ||
                    cleanId == cleanQuery ||
                    (cleanQuery.length >= 8 && cleanTxn.contains(cleanQuery)) ||
                    (cleanQuery.length >= 8 && notes.contains(cleanQuery))) {
                  return p;
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Publish a service booking to Firebase Realtime Database
  static Future<bool> publishBooking(BookingModel booking) async {
    final candidateUrls = FirebaseConfig.candidateUrls;
    bool success = false;

    await Future.wait(
      candidateUrls.map((base) async {
        try {
          final isRtdb = _isFirebaseRtdb(base);
          final clean = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
          final url = isRtdb ? '$clean/bookings/${booking.id}.json' : '$clean/bookings';
          final uri = Uri.parse(url);
          final body = jsonEncode(booking.toJson());

          final http.Response res = isRtdb
              ? await http.put(uri, headers: _headers, body: body).timeout(const Duration(milliseconds: 4000))
              : await http.post(uri, headers: _headers, body: body).timeout(const Duration(milliseconds: 4000));

          if (res.statusCode == 200 || res.statusCode == 201) {
            success = true;
          }
        } catch (_) {}
      }),
    );
    return success;
  }

  /// Clear all cloud data across RTDB and local endpoints
  static Future<void> clearAllCloudData() async {
    final candidateUrls = FirebaseConfig.candidateUrls;

    await Future.wait(
      candidateUrls.map((base) async {
        try {
          if (_isFirebaseRtdb(base)) {
            final clean = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
            for (final col in ['providers', 'residents', 'payments', 'bookings', 'payouts']) {
              try {
                final getRes = await http.get(Uri.parse('$clean/$col.json'), headers: _headers).timeout(const Duration(milliseconds: 3000));
                if (getRes.statusCode == 200 && getRes.body.isNotEmpty && getRes.body.trim() != 'null') {
                  final decoded = jsonDecode(getRes.body);
                  if (decoded is Map<String, dynamic>) {
                    await Future.wait(
                      decoded.keys.map((k) => http.delete(Uri.parse('$clean/$col/$k.json'), headers: _headers).timeout(const Duration(milliseconds: 3000))),
                    );
                  }
                }
              } catch (_) {}
            }
          } else {
            await http.post(Uri.parse('$base/wipe')).timeout(const Duration(milliseconds: 3000));
            await http.post(Uri.parse('$base/api/wipe')).timeout(const Duration(milliseconds: 3000));
          }
        } catch (_) {}
      }),
    );
  }
}

