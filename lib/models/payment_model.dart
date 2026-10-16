class PaymentModel {
  final String id; // payment_id
  final String providerId;
  final String providerName;
  final String providerPhone;
  final double amount; // e.g. 116.82 (₹99 + 18% GST)
  final String currency; // 'INR'
  final String planId; // 'nearslay_pro_monthly'
  final String planName; // 'NearSlay Pro (1 Month)'
  final String gateway; // 'Direct UPI / QR', 'UPI'
  final String transactionId;
  final String orderId;
  final String status; // 'success', 'failed', 'refunded'
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool autoBilling;
  final String receiptNumber;
  final String receiptUrl;
  final String? notes;

  const PaymentModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    this.amount = 116.82,
    this.currency = 'INR',
    this.planId = 'nearslay_pro_monthly',
    this.planName = 'NearSlay Pro (1 Month)',
    required this.gateway,
    required this.transactionId,
    this.orderId = '',
    this.status = 'success',
    required this.createdAt,
    required this.expiresAt,
    this.autoBilling = true,
    required this.receiptNumber,
    this.receiptUrl = '',
    this.notes,
  });

  String get formattedAmount =>
      '₹${amount % 1 == 0 ? amount.toInt() : amount.toStringAsFixed(2)}';

  String get formattedDate {
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }

  String get formattedExpiryDate {
    return '${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}';
  }

  PaymentModel copyWith({
    String? id,
    String? providerId,
    String? providerName,
    String? providerPhone,
    double? amount,
    String? currency,
    String? planId,
    String? planName,
    String? gateway,
    String? transactionId,
    String? orderId,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? autoBilling,
    String? receiptNumber,
    String? receiptUrl,
    String? notes,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      providerPhone: providerPhone ?? this.providerPhone,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      gateway: gateway ?? this.gateway,
      transactionId: transactionId ?? this.transactionId,
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      autoBilling: autoBilling ?? this.autoBilling,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_id': id,
      'provider_id': providerId,
      'providerId': providerId,
      'provider_name': providerName,
      'providerName': providerName,
      'provider_phone': providerPhone,
      'providerPhone': providerPhone,
      'amount': amount,
      'currency': currency,
      'plan_id': planId,
      'planId': planId,
      'plan_name': planName,
      'planName': planName,
      'gateway': gateway,
      'transaction_id': transactionId,
      'transactionId': transactionId,
      'order_id': orderId,
      'orderId': orderId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'auto_billing': autoBilling,
      'autoBilling': autoBilling,
      'receipt_number': receiptNumber,
      'receiptNumber': receiptNumber,
      'receipt_url': receiptUrl,
      'receiptUrl': receiptUrl,
      'notes': notes ?? '',
    };
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreated = DateTime.now();
    final cVal = json['created_at'] ?? json['createdAt'] ?? json['timestamp'];
    if (cVal is String && cVal.isNotEmpty) {
      parsedCreated = DateTime.tryParse(cVal) ?? DateTime.now();
    } else if (cVal is int) {
      parsedCreated = DateTime.fromMillisecondsSinceEpoch(cVal);
    }

    DateTime parsedExpires = parsedCreated.add(const Duration(days: 30));
    final eVal = json['expires_at'] ?? json['expiresAt'];
    if (eVal is String && eVal.isNotEmpty) {
      parsedExpires = DateTime.tryParse(eVal) ?? parsedExpires;
    } else if (eVal is int) {
      parsedExpires = DateTime.fromMillisecondsSinceEpoch(eVal);
    }

    final pId = json['id'] as String? ??
        json['payment_id'] as String? ??
        json['paymentId'] as String? ??
        'pay_${DateTime.now().millisecondsSinceEpoch}';

    return PaymentModel(
      id: pId,
      providerId: json['provider_id'] as String? ??
          json['providerId'] as String? ??
          '',
      providerName: json['provider_name'] as String? ??
          json['providerName'] as String? ??
          'Provider',
      providerPhone: json['provider_phone'] as String? ??
          json['providerPhone'] as String? ??
          '',
      amount: (json['amount'] as num?)?.toDouble() ?? 116.82,
      currency: json['currency'] as String? ?? 'INR',
      planId: json['plan_id'] as String? ??
          json['planId'] as String? ??
          'nearslay_pro_monthly',
      planName: json['plan_name'] as String? ??
          json['planName'] as String? ??
          'NearSlay Pro (1 Month)',
      gateway: json['gateway'] as String? ?? 'Direct UPI / QR',
      transactionId: json['transaction_id'] as String? ??
          json['transactionId'] as String? ??
          'TXN_${DateTime.now().millisecondsSinceEpoch}',
      orderId: json['order_id'] as String? ??
          json['orderId'] as String? ??
          'ORD_${DateTime.now().millisecondsSinceEpoch}',
      status: json['status'] as String? ?? 'success',
      createdAt: parsedCreated,
      expiresAt: parsedExpires,
      autoBilling: json['auto_billing'] == true ||
          json['autoBilling'] == true ||
          json['auto_billing'] == null,
      receiptNumber: json['receipt_number'] as String? ??
          json['receiptNumber'] as String? ??
          'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      receiptUrl: json['receipt_url'] as String? ??
          json['receiptUrl'] as String? ??
          '',
      notes: json['notes'] as String?,
    );
  }
}
