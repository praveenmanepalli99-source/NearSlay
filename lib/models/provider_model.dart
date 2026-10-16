import 'service_category.dart';

class ProviderModel {
  final String id;
  final String name;
  final String avatarUrl;
  final ServiceType category;
  final String categoryTitle;
  final int hourlyRate; // Charge per 1 hour
  final String colonyId;
  final String colonyName;
  final String city;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final bool isAvailable;
  final bool isVerified;
  final String realPhone; // Stored securely, never directly shown to user
  final String maskedVirtualNumber; // Displayed & dialed via secure bridge line
  final double rating;
  final int reviewsCount;
  final String bio;

  // --- Subscription & Free Trial Fields ---
  final String subscriptionStatus; // 'trial', 'active', 'grace_period', 'expired'
  final String trialEndDate; // ISO8601 string (90 days from registration)
  final String subscriptionEndDate; // ISO8601 string (renewed by ₹99/month payments)
  final String paymentId; // Last confirmed payment ID
  final bool autoBilling; // Auto-renew option
  final String createdAt; // Registration timestamp ISO8601
  final int lastReminderSentDay; // 0, 75 (15 days left), 85 (5 days left), 90 (grace)

  const ProviderModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.category,
    required this.categoryTitle,
    required this.hourlyRate,
    required this.colonyId,
    required this.colonyName,
    this.city = 'Current Location',
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.distanceMeters,
    required this.isAvailable,
    required this.isVerified,
    required this.realPhone,
    required this.maskedVirtualNumber,
    this.rating = 4.8,
    this.reviewsCount = 42,
    this.bio = 'Local service provider available for immediate service.',
    this.subscriptionStatus = 'trial',
    this.trialEndDate = '',
    this.subscriptionEndDate = '',
    this.paymentId = '',
    this.autoBilling = true,
    this.createdAt = '',
    this.lastReminderSentDay = 0,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters}m away';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km away';
  }

  // --- Subscription Date & Status Getters ---

  DateTime? get createdDateTime {
    if (createdAt.isEmpty) return null;
    return DateTime.tryParse(createdAt);
  }

  DateTime get trialEndDateTime {
    if (trialEndDate.isNotEmpty) {
      final parsed = DateTime.tryParse(trialEndDate);
      if (parsed != null) return parsed;
    }
    final created = createdDateTime ?? DateTime.now();
    return created.add(const Duration(days: 90));
  }

  DateTime? get subscriptionEndDateTime {
    if (subscriptionEndDate.isEmpty) return null;
    return DateTime.tryParse(subscriptionEndDate);
  }

  DateTime get effectiveEndDateTime {
    final subEnd = subscriptionEndDateTime;
    final trialEnd = trialEndDateTime;
    if (subEnd != null && subEnd.isAfter(trialEnd)) {
      return subEnd;
    }
    return trialEnd;
  }

  int get daysRemaining {
    final diff = effectiveEndDateTime.difference(DateTime.now());
    return (diff.inSeconds / 86400.0).ceil();
  }

  bool get isWithinGracePeriod {
    final days = daysRemaining;
    return days < 0 && days >= -3;
  }

  bool get isExpired {
    if (subscriptionStatus == 'expired') return true;
    return daysRemaining < -3;
  }

  bool get isPendingVerification {
    return subscriptionStatus == 'pending_verification';
  }

  bool get isSubscriptionActive {
    if (isExpired) return false;
    if (subscriptionStatus == 'pending_verification') return false;
    if (subscriptionStatus == 'active') return true;
    if (subscriptionStatus == 'trial') return daysRemaining >= -3;
    if (subscriptionStatus == 'grace_period') return daysRemaining >= -3;
    return daysRemaining >= -3;
  }

  bool get isTrialActive {
    return subscriptionStatus == 'trial' && daysRemaining >= 0;
  }

  String get subscriptionStatusDisplay {
    if (subscriptionStatus == 'pending_verification') {
      return 'Pending Admin Verification';
    }
    if (isExpired) {
      return 'Expired - Hidden';
    }
    if (isWithinGracePeriod) {
      final overdueDays = daysRemaining.abs();
      return 'Grace Period ($overdueDays/3 days)';
    }
    if (subscriptionStatus == 'active') {
      return 'Active Pro (₹99/mo)';
    }
    if (subscriptionStatus == 'trial') {
      return '90-Day Free Trial';
    }
    return 'Active Pro';
  }

  ProviderModel copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    ServiceType? category,
    String? categoryTitle,
    int? hourlyRate,
    String? colonyId,
    String? colonyName,
    String? city,
    double? latitude,
    double? longitude,
    int? distanceMeters,
    bool? isAvailable,
    bool? isVerified,
    String? realPhone,
    String? maskedVirtualNumber,
    double? rating,
    int? reviewsCount,
    String? bio,
    String? subscriptionStatus,
    String? trialEndDate,
    String? subscriptionEndDate,
    String? paymentId,
    bool? autoBilling,
    String? createdAt,
    int? lastReminderSentDay,
  }) {
    return ProviderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      category: category ?? this.category,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      colonyId: colonyId ?? this.colonyId,
      colonyName: colonyName ?? this.colonyName,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isAvailable: isAvailable ?? this.isAvailable,
      isVerified: isVerified ?? this.isVerified,
      realPhone: realPhone ?? this.realPhone,
      maskedVirtualNumber: maskedVirtualNumber ?? this.maskedVirtualNumber,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      bio: bio ?? this.bio,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      paymentId: paymentId ?? this.paymentId,
      autoBilling: autoBilling ?? this.autoBilling,
      createdAt: createdAt ?? this.createdAt,
      lastReminderSentDay: lastReminderSentDay ?? this.lastReminderSentDay,
    );
  }

  Map<String, dynamic> toJson() {
    final effectiveTrialEnd = trialEndDate.isNotEmpty
        ? trialEndDate
        : DateTime.now().add(const Duration(days: 90)).toIso8601String();
    final effectiveCreated =
        createdAt.isNotEmpty ? createdAt : DateTime.now().toIso8601String();

    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'category': category.name,
      'categoryTitle': categoryTitle,
      'hourlyRate': hourlyRate,
      'colonyId': colonyId,
      'colonyName': colonyName,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'isAvailable': isAvailable,
      'isVerified': isVerified,
      'realPhone': realPhone,
      'maskedVirtualNumber': maskedVirtualNumber,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'bio': bio,
      // Subscription & Free Trial
      'subscription_status': subscriptionStatus,
      'subscriptionStatus': subscriptionStatus,
      'trial_end_date': effectiveTrialEnd,
      'trialEndDate': effectiveTrialEnd,
      'subscription_end_date': subscriptionEndDate,
      'subscriptionEndDate': subscriptionEndDate,
      'payment_id': paymentId,
      'paymentId': paymentId,
      'auto_billing': autoBilling,
      'autoBilling': autoBilling,
      'created_at': effectiveCreated,
      'createdAt': effectiveCreated,
      'last_reminder_sent_day': lastReminderSentDay,
      'lastReminderSentDay': lastReminderSentDay,
    };
  }

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    ServiceType parsedCategory = ServiceType.plumber;
    final catName = (json['category'] as String? ?? 'plumber')
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]'), '');

    if (catName.contains('doctor') ||
        catName.contains('clinic') ||
        catName.contains('medic') ||
        catName.contains('health')) {
      parsedCategory = ServiceType.doctor;
    } else if (catName.contains('hotel') ||
        catName.contains('lodge') ||
        catName.contains('stay') ||
        catName.contains('room')) {
      parsedCategory = ServiceType.hotel;
    } else if (catName.contains('cater') ||
        catName.contains('chef') ||
        catName.contains('cook') ||
        catName.contains('baker') ||
        catName.contains('culinary') ||
        catName.contains('meal')) {
      parsedCategory = ServiceType.catering;
    } else if (catName.contains('restaurant') ||
        catName.contains('restaurent') ||
        catName.contains('food') ||
        catName.contains('dining') ||
        catName.contains('cafe')) {
      parsedCategory = ServiceType.restaurant;
    } else if (catName.contains('decor') ||
        catName.contains('flower') ||
        catName.contains('balloon')) {
      parsedCategory = ServiceType.decoration;
    } else if (catName.contains('tent') ||
        catName.contains('shamiana') ||
        catName.contains('mandap')) {
      parsedCategory = ServiceType.tentHouse;
    } else if (catName.contains('mechanic') ||
        catName.contains('auto') ||
        catName.contains('bike') ||
        catName.contains('car')) {
      parsedCategory = ServiceType.mechanic;
    } else if (catName.contains('plumb')) {
      parsedCategory = ServiceType.plumber;
    } else if (catName.contains('electr')) {
      parsedCategory = ServiceType.electrician;
    } else if (catName.contains('carpent')) {
      parsedCategory = ServiceType.carpenter;
    } else if (catName.contains('appliance') ||
        catName.contains('ac') ||
        catName.contains('ro') ||
        catName.contains('water') ||
        catName.contains('purifier') ||
        catName.contains('clean') ||
        catName.contains('garden')) {
      parsedCategory = ServiceType.applianceRepair;
    } else if (catName.contains('paint')) {
      parsedCategory = ServiceType.painter;
    } else if (catName.contains('dj') ||
        catName.contains('sound') ||
        catName.contains('audio') ||
        catName.contains('speaker') ||
        catName.contains('music') ||
        catName.contains('pest')) {
      parsedCategory = ServiceType.djSound;
    } else {
      for (final t in ServiceType.values) {
        if (t.name.toLowerCase() == catName) {
          parsedCategory = t;
          break;
        }
      }
    }

    final cTime = json['created_at'] as String? ??
        json['createdAt'] as String? ??
        DateTime.now().toIso8601String();

    String tEndDate = json['trial_end_date'] as String? ??
        json['trialEndDate'] as String? ??
        '';
    if (tEndDate.isEmpty) {
      final cParsed = DateTime.tryParse(cTime) ?? DateTime.now();
      tEndDate = cParsed.add(const Duration(days: 90)).toIso8601String();
    }

    final subStatus = json['subscription_status'] as String? ??
        json['subscriptionStatus'] as String? ??
        'trial';

    final sEndDate = json['subscription_end_date'] as String? ??
        json['subscriptionEndDate'] as String? ??
        '';

    final pId = json['payment_id'] as String? ??
        json['paymentId'] as String? ??
        '';

    final autoBill = json['auto_billing'] == true ||
        json['autoBilling'] == true ||
        json['auto_billing'] == null;

    final reminderDay = (json['last_reminder_sent_day'] as num?)?.toInt() ??
        (json['lastReminderSentDay'] as num?)?.toInt() ??
        0;

    return ProviderModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      category: parsedCategory,
      categoryTitle: json['categoryTitle'] as String? ?? 'Service',
      hourlyRate: (json['hourlyRate'] as num?)?.toInt() ?? 250,
      colonyId: json['colonyId'] as String? ?? '',
      colonyName: json['colonyName'] as String? ?? '',
      city: json['city'] as String? ?? 'Current Location',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 300,
      isAvailable: json['isAvailable'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? true,
      realPhone: json['realPhone'] as String? ?? '',
      maskedVirtualNumber: json['maskedVirtualNumber'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 1,
      bio: json['bio'] as String? ?? '',
      subscriptionStatus: subStatus,
      trialEndDate: tEndDate,
      subscriptionEndDate: sEndDate,
      paymentId: pId,
      autoBilling: autoBill,
      createdAt: cTime,
      lastReminderSentDay: reminderDay,
    );
  }
}
