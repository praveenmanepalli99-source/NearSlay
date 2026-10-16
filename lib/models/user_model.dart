class UserModel {
  final String id;
  final String name;
  final String avatarUrl;
  final String colonyId;
  final String colonyName;
  final String city;
  final String flatAddress;
  final String phone;
  final int rewardCoins;
  final bool isPurchaser;

  const UserModel({
    required this.id,
    required this.name,
    this.avatarUrl =
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
    required this.colonyId,
    required this.colonyName,
    this.city = 'Current Location',
    required this.flatAddress,
    required this.phone,
    this.rewardCoins = 0,
    this.isPurchaser = false,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? colonyId,
    String? colonyName,
    String? city,
    String? flatAddress,
    String? phone,
    int? rewardCoins,
    bool? isPurchaser,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      colonyId: colonyId ?? this.colonyId,
      colonyName: colonyName ?? this.colonyName,
      city: city ?? this.city,
      flatAddress: flatAddress ?? this.flatAddress,
      phone: phone ?? this.phone,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      isPurchaser: isPurchaser ?? this.isPurchaser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'colonyId': colonyId,
      'colonyName': colonyName,
      'city': city,
      'flatAddress': flatAddress,
      'phone': phone,
      'rewardCoins': rewardCoins,
      'isPurchaser': isPurchaser,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ??
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
      colonyId: json['colonyId'] as String? ?? '',
      colonyName: json['colonyName'] as String? ?? '',
      city: json['city'] as String? ?? 'Current Location',
      flatAddress: json['flatAddress'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      rewardCoins: (json['rewardCoins'] as num?)?.toInt() ??
          (json['reward_coins'] as num?)?.toInt() ??
          0,
      isPurchaser: json['isPurchaser'] == true ||
          json['is_purchaser'] == true ||
          json['isSubscribed'] == true,
    );
  }
}
