import '../models/provider_model.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class CloudSyncData {
  final List<ProviderModel> providers;
  final List<UserModel> residents;

  const CloudSyncData({
    required this.providers,
    required this.residents,
  });
}

class CloudSyncService {
  /// Fetch all live providers and residents from Firebase Cloud Services
  static Future<CloudSyncData> fetchCloudData() async {
    final data = await FirebaseService.fetchCloudData();
    return CloudSyncData(providers: data.providers, residents: data.residents);
  }

  /// Publish provider to Firebase Cloud Services
  static Future<bool> publishProvider(ProviderModel provider) async {
    return FirebaseService.publishProvider(provider);
  }

  /// Publish resident to Firebase Cloud Services
  static Future<bool> publishResident(UserModel resident) async {
    return FirebaseService.publishResident(resident);
  }

  /// Delete provider from Firebase Cloud Services
  static Future<bool> deleteProvider(String providerId, {String? phone}) async {
    return FirebaseService.deleteProvider(providerId, phone: phone);
  }

  /// Delete resident from Firebase Cloud Services
  static Future<bool> deleteResident(String phone, {String? id}) async {
    return FirebaseService.deleteResident(phone, id: id);
  }

  /// Check if user or provider is currently available / not deleted in Cloud Database
  static Future<bool> isUserAvailableInCloud(String phone, {String? providerId, String? residentId}) async {
    return FirebaseService.isUserAvailableInCloud(phone, providerId: providerId, residentId: residentId);
  }

  /// Clear all cloud data from Firebase Cloud Services
  static Future<void> clearAllCloudData() async {
    return FirebaseService.clearAllCloudData();
  }
}
