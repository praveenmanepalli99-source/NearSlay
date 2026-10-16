class BookingModel {
  final String id; // booking_id
  final String providerId;
  final String providerName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String serviceType;
  final String categoryTitle;
  final String colonyName;
  final String city;
  final int hourlyRate;
  final String status; // 'pending', 'confirmed', 'in_progress', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? scheduledDate;
  final String? issueDescription;
  final String? paymentId;

  const BookingModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.serviceType,
    required this.categoryTitle,
    required this.colonyName,
    this.city = 'Current Location',
    required this.hourlyRate,
    this.status = 'confirmed',
    required this.createdAt,
    this.scheduledDate,
    this.issueDescription,
    this.paymentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': id,
      'provider_id': providerId,
      'providerId': providerId,
      'provider_name': providerName,
      'providerName': providerName,
      'customer_id': customerId,
      'customerId': customerId,
      'customer_name': customerName,
      'customerName': customerName,
      'customer_phone': customerPhone,
      'customerPhone': customerPhone,
      'service_type': serviceType,
      'serviceType': serviceType,
      'category_title': categoryTitle,
      'categoryTitle': categoryTitle,
      'colony_name': colonyName,
      'colonyName': colonyName,
      'city': city,
      'hourly_rate': hourlyRate,
      'hourlyRate': hourlyRate,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'scheduled_date': scheduledDate?.toIso8601String(),
      'scheduledDate': scheduledDate?.toIso8601String(),
      'issue_description': issueDescription,
      'issueDescription': issueDescription,
      'payment_id': paymentId,
      'paymentId': paymentId,
    };
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreated = DateTime.now();
    final cVal = json['created_at'] ?? json['createdAt'];
    if (cVal is String && cVal.isNotEmpty) {
      parsedCreated = DateTime.tryParse(cVal) ?? DateTime.now();
    }

    DateTime? parsedScheduled;
    final sVal = json['scheduled_date'] ?? json['scheduledDate'];
    if (sVal is String && sVal.isNotEmpty) {
      parsedScheduled = DateTime.tryParse(sVal);
    }

    return BookingModel(
      id: json['id'] as String? ??
          json['booking_id'] as String? ??
          'bk_${DateTime.now().millisecondsSinceEpoch}',
      providerId: json['provider_id'] as String? ??
          json['providerId'] as String? ??
          '',
      providerName: json['provider_name'] as String? ??
          json['providerName'] as String? ??
          'Technician',
      customerId: json['customer_id'] as String? ??
          json['customerId'] as String? ??
          '',
      customerName: json['customer_name'] as String? ??
          json['customerName'] as String? ??
          'Resident',
      customerPhone: json['customer_phone'] as String? ??
          json['customerPhone'] as String? ??
          '',
      serviceType: json['service_type'] as String? ??
          json['serviceType'] as String? ??
          'plumber',
      categoryTitle: json['category_title'] as String? ??
          json['categoryTitle'] as String? ??
          'Plumbing',
      colonyName: json['colony_name'] as String? ??
          json['colonyName'] as String? ??
          'Colony',
      city: json['city'] as String? ?? 'Current Location',
      hourlyRate: (json['hourly_rate'] as num?)?.toInt() ??
          (json['hourlyRate'] as num?)?.toInt() ??
          250,
      status: json['status'] as String? ?? 'confirmed',
      createdAt: parsedCreated,
      scheduledDate: parsedScheduled,
      issueDescription: json['issue_description'] as String? ??
          json['issueDescription'] as String?,
      paymentId: json['payment_id'] as String? ?? json['paymentId'] as String?,
    );
  }
}
