import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/provider_model.dart';
import '../models/payment_model.dart';
import 'sms_service.dart';
import 'firebase_service.dart';

class SubscriptionReminderAlert {
  final String title;
  final String message;
  final String urgency; // 'info', 'warning', 'urgent', 'critical', 'expired'
  final int daysLeft;
  final int triggerDay;
  final bool requiresAction;

  const SubscriptionReminderAlert({
    required this.title,
    required this.message,
    required this.urgency,
    required this.daysLeft,
    required this.triggerDay,
    this.requiresAction = false,
  });
}

class SubscriptionService {
  static const String _prefPaymentsKey = 'nearslay_saved_payments_cache';

  static const double basePlanPriceInr = 99.0;
  static const double gstRatePercent = 18.0;
  static const double gstAmountInr = 17.82; // 18% of ₹99
  static const double totalPlanPriceInr = 116.82; // ₹99 + ₹17.82 GST
  static const int freeTrialDays = 90;
  static const int gracePeriodDays = 3;

  /// Default Business Payee Name
  static const String upiVpa = '';
  static const String upiPayeeName = 'NearSlay Technologies';

  /// Evaluate provider subscription status, apply 3-day grace period, and auto-hide if expired
  static ProviderModel evaluateProviderSubscription(ProviderModel provider) {
    if (provider.subscriptionStatus == 'pending_verification') {
      return provider;
    }
    final days = provider.daysRemaining;

    if (days < -gracePeriodDays) {
      // Past 3-day grace period -> Expired and auto-mark Busy / hidden
      return provider.copyWith(
        subscriptionStatus: 'expired',
        isAvailable: false,
      );
    } else if (days < 0) {
      // In 3-day grace period -> Still visible during buffer but flagged grace_period
      return provider.copyWith(
        subscriptionStatus: 'grace_period',
      );
    } else {
      // Days remaining >= 0
      if (provider.subscriptionEndDate.isNotEmpty) {
        final subEnd = provider.subscriptionEndDateTime;
        if (subEnd != null && subEnd.isAfter(DateTime.now())) {
          return provider.copyWith(subscriptionStatus: 'active');
        }
      }
      return provider.copyWith(subscriptionStatus: 'trial');
    }
  }

  /// Get reminder alert for provider based on 75-day (15d left), 85-day (5d left), grace period or expiry
  static SubscriptionReminderAlert? getSubscriptionReminder(
      ProviderModel provider) {
    final days = provider.daysRemaining;

    if (days < -gracePeriodDays || provider.subscriptionStatus == 'expired') {
      return const SubscriptionReminderAlert(
        title: 'Subscription Expired',
        message:
            'Your ₹99 + GST monthly subscription has expired. Your profile is currently hidden from resident searches. Renew your subscription to become Available immediately.',
        urgency: 'expired',
        daysLeft: 0,
        triggerDay: 93,
        requiresAction: true,
      );
    }

    if (days < 0 && days >= -gracePeriodDays) {
      final bufferLeft = gracePeriodDays + days; // 3 + (-1) = 2 days left
      return SubscriptionReminderAlert(
        title: 'Grace Period Active ($bufferLeft Days Left)',
        message:
            'Your free trial has ended. You have $bufferLeft days buffer remaining before your profile is hidden from colony residents. Renew your NearSlay Pro subscription now.',
        urgency: 'critical',
        daysLeft: days,
        triggerDay: 90,
        requiresAction: true,
      );
    }

    // 85 days (5 days left)
    if (days <= 5) {
      return SubscriptionReminderAlert(
        title: 'Free Trial Ending in $days Days',
        message:
            'Only $days days left in your 90-day free trial! Renew for ₹99 + GST/month to keep receiving direct colony calls uninterrupted.',
        urgency: 'urgent',
        daysLeft: days,
        triggerDay: 85,
        requiresAction: true,
      );
    }

    // 75 days (15 days left)
    if (days <= 15) {
      return SubscriptionReminderAlert(
        title: 'Free Trial Ending in $days Days',
        message:
            'Your 90-day free trial ends in $days days. Renew for ₹99 + GST/month on NearSlay to stay visible in resident searches.',
        urgency: 'warning',
        daysLeft: days,
        triggerDay: 75,
        requiresAction: false,
      );
    }

    return null;
  }

  /// Generate UPI Payment URI for native intent and dynamic QR code
  static String generateUpiUri({
    required double amount,
    required String receiptNumber,
    String? providerName,
    String scheme = 'upi',
  }) {
    final note = Uri.encodeComponent(
        'NearSlay Pro Subscription - $receiptNumber');
    final payee = Uri.encodeComponent(upiPayeeName);
    final params = 'pa=$upiVpa&pn=$payee&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$note';

    switch (scheme) {
      case 'phonepe':
        return 'phonepe://pay?$params';
      case 'gpay':
      case 'tez':
        return 'tez://upi/pay?$params';
      case 'paytm':
        return 'paytmmp://pay?$params';
      default:
        return 'upi://pay?$params';
    }
  }

  /// Validate Indian UPI UTR / Reference Number (Strict Production Banking Validation)
  static bool isValidUtr(String? utr) {
    if (utr == null) return false;
    final clean = utr.trim().replaceAll(RegExp(r'\s+'), '');
    if (clean.length < 10 || clean.length > 22) return false;

    // Must be strictly alphanumeric
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(clean)) return false;

    final upper = clean.toUpperCase();
    if (upper.contains('TEST') ||
        upper.contains('DEMO') ||
        upper.contains('DUMMY') ||
        upper.contains('SAMPLE')) {
      return false;
    }

    // Must contain at least 6 digits (UPI UTRs are predominantly numeric)
    final digitsCount = clean.replaceAll(RegExp(r'\D'), '').length;
    if (digitsCount < 6) return false;

    // Reject all identical characters like '000000000000' or '111111111111'
    final uniqueChars = clean.split('').toSet();
    if (uniqueChars.length <= 2) return false;

    // Reject obvious sequential dummy strings
    if (upper == '123456789012' ||
        upper == '012345678901' ||
        upper == '987654321098' ||
        upper == '1234567890' ||
        upper == '1234567890123456') {
      return false;
    }

    return true;
  }

  /// Process subscription renewal / activation payment (₹99 + 18% GST = ₹116.82)
  static Future<Map<String, dynamic>> processPayment({
    required ProviderModel provider,
    String gateway = 'Direct UPI / QR',
    double amount = totalPlanPriceInr,
    String? transactionId,
    String? utrNumber,
    bool autoBilling = true,
    String? promoCode,
    bool requireAdminVerification = false,
  }) async {
    try {
      final now = DateTime.now();
      final currentEnd = provider.subscriptionEndDateTime;

      // Extend from whichever is later: current end or now
      DateTime newEndDate;
      if (currentEnd != null && currentEnd.isAfter(now)) {
        newEndDate = currentEnd.add(const Duration(days: 30));
      } else {
        newEndDate = now.add(const Duration(days: 30));
      }

      final txnId = (utrNumber != null && utrNumber.trim().isNotEmpty)
          ? utrNumber.trim()
          : (transactionId != null && transactionId.trim().isNotEmpty)
              ? transactionId.trim()
              : 'UPI_UTR_${now.millisecondsSinceEpoch}';
      final payId = 'pay_nearslay_${now.millisecondsSinceEpoch}';
      final recNumber =
          'NS-REC-${now.millisecondsSinceEpoch.toString().substring(5)}';

      final paymentStatus =
          requireAdminVerification ? 'pending_verification' : 'success';
      final providerSubStatus =
          requireAdminVerification ? 'pending_verification' : 'active';

      final payment = PaymentModel(
        id: payId,
        providerId: provider.id,
        providerName: provider.name,
        providerPhone: provider.realPhone,
        amount: amount,
        currency: 'INR',
        planId: 'nearslay_pro_monthly',
        planName: 'NearSlay Pro (1 Month)',
        gateway: gateway,
        transactionId: txnId,
        orderId: 'ORD_${now.millisecondsSinceEpoch}',
        status: paymentStatus,
        createdAt: now,
        expiresAt: newEndDate,
        autoBilling: autoBilling,
        receiptNumber: recNumber,
        receiptUrl: '',
        notes: requireAdminVerification
            ? 'UTR: $txnId submitted via Direct UPI. Awaiting Admin bank credit verification against SBI statement.'
            : (promoCode != null && promoCode.isNotEmpty
                ? 'Applied Promo: $promoCode (Base ₹99 + 18% GST)'
                : 'Base ₹99.00 + 18% GST (CGST ₹8.91 + SGST ₹8.91) = ₹${amount.toStringAsFixed(2)}'),
      );

      // Save payment in local cache
      await savePaymentLocally(payment);

      // Sync payment to Firebase Cloud Database
      await FirebaseService.publishPayment(payment);

      // Update provider model
      final updatedProvider = provider.copyWith(
        subscriptionStatus: providerSubStatus,
        subscriptionEndDate: requireAdminVerification
            ? provider.subscriptionEndDate
            : newEndDate.toIso8601String(),
        paymentId: payId,
        autoBilling: autoBilling,
        isAvailable: requireAdminVerification ? provider.isAvailable : true,
        lastReminderSentDay: 0,
      );

      // Publish updated provider to Firebase
      await FirebaseService.publishProvider(updatedProvider);

      if (!requireAdminVerification) {
        // Send SMS notification confirmation only if already verified
        SmsService.sendPaymentReceiptSms(
          phone: provider.realPhone,
          amount: amount.toInt(),
          receiptNo: recNumber,
          validUntil: newEndDate,
        );
      }

      return {
        'success': true,
        'pending': requireAdminVerification,
        'provider': updatedProvider,
        'payment': payment,
        'message': requireAdminVerification
            ? 'UTR reference submitted. Awaiting Admin bank verification from Dashboard.'
            : 'Payment verified and Pro activated.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Payment processing failed: $e',
      };
    }
  }

  /// Search and find payment by UTR / Transaction ID or Receipt No across local cache and Firebase RTDB
  static Future<PaymentModel?> findPaymentByUtr(String utr) async {
    final clean = utr.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.isEmpty) return null;

    // 1. Search local cache
    try {
      final localList = await loadLocalPayments('');
      for (final p in localList) {
        final txn = p.transactionId.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
        final rec = p.receiptNumber.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
        if (txn == clean || rec == clean || (clean.length >= 8 && txn.contains(clean))) {
          return p;
        }
      }
    } catch (_) {}

    // 2. Search Firebase Cloud Database
    try {
      final remoteMatch = await FirebaseService.findPaymentByUtr(clean);
      if (remoteMatch != null) {
        await savePaymentLocally(remoteMatch);
        return remoteMatch;
      }
    } catch (_) {}

    return null;
  }

  /// Save payment to local cache for instant offline view
  static Future<void> savePaymentLocally(PaymentModel payment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getStringList(_prefPaymentsKey) ?? [];
      existingJson.insert(0, jsonEncode(payment.toJson()));
      await prefs.setStringList(_prefPaymentsKey, existingJson);
    } catch (_) {}
  }

  /// Load cached payments for a provider
  static Future<List<PaymentModel>> loadLocalPayments(String providerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefPaymentsKey) ?? [];
      final payments = <PaymentModel>[];
      for (final item in list) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          final p = PaymentModel.fromJson(map);
          if (providerId.isEmpty || p.providerId == providerId) {
            payments.add(p);
          }
        } catch (_) {}
      }
      return payments;
    } catch (_) {
      return [];
    }
  }
}
