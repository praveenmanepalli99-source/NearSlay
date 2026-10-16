class ColonyModel {
  final String id;
  final String name;
  final String landmark;
  final String city;
  final String pincode;
  final double latitude;
  final double longitude;
  final int activeProvidersCount;

  const ColonyModel({
    required this.id,
    required this.name,
    required this.landmark,
    required this.city,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.activeProvidersCount,
  });

  String get fullAddress => '$name, $landmark, $city - $pincode';

  ColonyModel copyWith({
    String? id,
    String? name,
    String? landmark,
    String? city,
    String? pincode,
    double? latitude,
    double? longitude,
    int? activeProvidersCount,
  }) {
    return ColonyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      activeProvidersCount: activeProvidersCount ?? this.activeProvidersCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'landmark': landmark,
      'city': city,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'activeProvidersCount': activeProvidersCount,
    };
  }

  factory ColonyModel.fromJson(Map<String, dynamic> json) {
    return ColonyModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      city: json['city'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 12.9298,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.6749,
      activeProvidersCount: json['activeProvidersCount'] as int? ?? 0,
    );
  }
}
