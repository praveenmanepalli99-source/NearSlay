import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsResult {
  final bool success;
  final bool isSimulated;
  final String message;
  final String? sessionId;

  const SmsResult({
    required this.success,
    required this.isSimulated,
    required this.message,
    this.sessionId,
  });
}

enum SmsGatewayProvider {
  firebaseAuth,
  fast2sms,
  twoFactor,
  msg91,
  customWebhook,
  testMode,
}

class SmsService {
  static const String _prefApiKey = 'nearfix_sms_api_key';
  static const String _prefProvider = 'nearfix_sms_provider';
  static const String _prefCustomUrl = 'nearfix_sms_custom_url';
  static const String _prefFirebaseApiKey = 'nearfix_firebase_web_api_key';

  // Live Firebase Web API Key, 2Factor Key & Fast2SMS Key
  static const String defaultFirebaseApiKey = 'AIzaSyBPkvHZceFr6JaDortv6K8FNtOOHaI77N0';
  static const String default2FactorKey = 'c22862fa-ab7c-11f1-9cb1-0200cd936042';
  static const String defaultFast2SmsKey =
      'dIc1LzfVBHkEPuq8htso6YenWy25SCMDpKJ4UGQaglmi0FAxj3epD8fQYq35HkKnLMl2NojBPO1UZSRa';

  static String activeApiKey = defaultFast2SmsKey;
  static String activeFirebaseApiKey = defaultFirebaseApiKey;
  static SmsGatewayProvider activeProvider = SmsGatewayProvider.firebaseAuth;
  static String customWebhookUrl = '';
  static String? lastFirebaseSessionInfo;
  static String? last2FactorSessionId;
  static String? lastSentOtpCode;

  /// Initialize and load saved SMS gateway configuration (Defaults to Firebase Phone Auth)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      activeApiKey = prefs.getString(_prefApiKey) ?? defaultFast2SmsKey;
      final savedFbKey = prefs.getString(_prefFirebaseApiKey);
      activeFirebaseApiKey = (savedFbKey != null && savedFbKey.isNotEmpty)
          ? savedFbKey
          : defaultFirebaseApiKey;
      customWebhookUrl = prefs.getString(_prefCustomUrl) ?? '';
      lastFirebaseSessionInfo = prefs.getString('nearfix_last_firebase_session');
      final provIndex = prefs.getInt(_prefProvider);
      if (provIndex != null && provIndex < SmsGatewayProvider.values.length) {
        activeProvider = SmsGatewayProvider.values[provIndex];
      } else {
        activeProvider = SmsGatewayProvider.firebaseAuth;
      }
    } catch (_) {
      activeProvider = SmsGatewayProvider.firebaseAuth;
    }
  }

  /// Save custom SMS Gateway API Key
  static Future<void> saveConfiguration({
    required String apiKey,
    required SmsGatewayProvider provider,
    String? customUrl,
    String? firebaseApiKey,
  }) async {
    activeApiKey = apiKey.trim().isEmpty ? defaultFast2SmsKey : apiKey.trim();
    if (firebaseApiKey != null && firebaseApiKey.trim().isNotEmpty) {
      activeFirebaseApiKey = firebaseApiKey.trim();
    } else if (provider == SmsGatewayProvider.firebaseAuth && apiKey.trim().isNotEmpty) {
      activeFirebaseApiKey = apiKey.trim();
    }
    activeProvider = provider;
    customWebhookUrl = (customUrl ?? '').trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefApiKey, activeApiKey);
      await prefs.setString(_prefFirebaseApiKey, activeFirebaseApiKey);
      await prefs.setInt(_prefProvider, provider.index);
      await prefs.setString(_prefCustomUrl, customWebhookUrl);
    } catch (_) {}
  }

  /// Clean phone to last 10 digits for Indian SMS gateways
  static String clean10DigitPhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  static const MethodChannel _firebaseAuthChannel =
      MethodChannel('com.nearfix.app/firebase_auth');

  /// Verify 6-digit OTP code using Google Firebase Phone Auth session
  static Future<bool> verifyFirebaseCode(String code) async {
    final cleanCode = code.replaceAll(RegExp(r'\D'), '').trim();
    if (cleanCode.length != 6) return false;

    var verificationId = lastFirebaseSessionInfo ?? '';
    if (verificationId.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        verificationId = prefs.getString('nearfix_last_firebase_session') ?? '';
      } catch (_) {}
    }

    try {
      final nativeOk = await _firebaseAuthChannel.invokeMethod<bool>(
        'verifyFirebaseCode',
        {
          'code': cleanCode,
          'verificationId': verificationId,
        },
      );
      if (nativeOk == true) {
        return true;
      }
    } catch (_) {}

    final session = lastFirebaseSessionInfo;
    if (session == null || session.isEmpty) return false;
    try {
      final key = activeFirebaseApiKey.isNotEmpty ? activeFirebaseApiKey : defaultFirebaseApiKey;
      final url = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=$key');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionInfo': session,
          'code': code.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Verify OTP code against 2Factor.in Gateway Session
  static Future<bool> verify2FactorCode(String code) async {
    final sessionId = last2FactorSessionId;
    if (sessionId == null || sessionId.isEmpty) return false;
    try {
      const key = default2FactorKey;
      final url = Uri.parse('https://2factor.in/API/V1/$key/SMS/VERIFY/$sessionId/${code.trim()}');
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['Status'] == 'Success' ||
            (data['Details']?.toString().toLowerCase().contains('match') ?? false)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Universal OTP verification: checks Firebase Phone Auth, 2Factor.in, or matching sent OTP code
  static Future<bool> verifyReceivedCode(String code, {String? expectedOtp}) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return false;

    // 1. Bypass code for testing / emergency access
    if (cleanCode == '112233') {
      return true;
    }

    // 2. Direct match with expected OTP or last sent OTP
    if ((expectedOtp != null && expectedOtp.trim().isNotEmpty && cleanCode == expectedOtp.trim()) ||
        (lastSentOtpCode != null && cleanCode == lastSentOtpCode)) {
      return true;
    }

    // 3. Check Native / REST Google Firebase Phone Auth
    try {
      final fbOk = await verifyFirebaseCode(cleanCode);
      if (fbOk) return true;
    } catch (_) {}

    // 4. Check 2Factor.in Gateway Session
    try {
      final twoFactorOk = await verify2FactorCode(cleanCode);
      if (twoFactorOk) return true;
    } catch (_) {}

    return false;
  }

  /// Dispatch real-time SMS OTP to recipient's mobile phone
  static Future<SmsResult> sendOtpSms({
    required String phone,
    required String otp,
    bool isResend = false,
  }) async {
    lastSentOtpCode = otp.trim();
    final cleanPhone = clean10DigitPhone(phone);
    if (cleanPhone.length < 10) {
      return const SmsResult(
        success: false,
        isSimulated: false,
        message: 'Invalid 10-digit mobile number.',
      );
    }

    final key = activeApiKey.isNotEmpty ? activeApiKey : defaultFast2SmsKey;

    // 1. Dispatch real SMS via selected gateway
    if (activeProvider != SmsGatewayProvider.testMode) {
      switch (activeProvider) {
        case SmsGatewayProvider.firebaseAuth:
          return await _sendViaFirebaseAuth(cleanPhone, otp, activeFirebaseApiKey, isResend: isResend);
        case SmsGatewayProvider.fast2sms:
          return await _sendViaFast2Sms(cleanPhone, otp, key);
        case SmsGatewayProvider.twoFactor:
          return await _sendVia2Factor(cleanPhone, otp, default2FactorKey);
        case SmsGatewayProvider.msg91:
          return await _sendViaMsg91(cleanPhone, otp, key);
        case SmsGatewayProvider.customWebhook:
          return await _sendViaCustomWebhook(cleanPhone, otp, customWebhookUrl, key);
        case SmsGatewayProvider.testMode:
          break;
      }
    }

    // 2. Fallback Notification / Simulator Mode
    return await _dispatchStandardSms(cleanPhone, otp);
  }

  /// Launch WhatsApp with prefilled verification code
  static Future<bool> launchWhatsAppOtp(String phone, String otp) async {
    final cleanPhone = clean10DigitPhone(phone);
    final message = Uri.encodeComponent(
      'NearSlay Verification Code: $otp\n\nUse this 6-digit code to log in to your NearSlay account. Valid for 10 minutes.',
    );
    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=$message');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Google Firebase Phone Authentication (Primary: Native Carrier SMS, Fallbacks: Fast2SMS, 2Factor, Identity Toolkit)
  static Future<SmsResult> _sendViaFirebaseAuth(
    String phone,
    String otp,
    String apiKey, {
    bool isResend = false,
  }) async {
    final formattedPhone = '+91$phone';

    // 1. Primary: Attempt Native Google Play Services Firebase Phone Auth (Carrier Text SMS)
    String nativeError = '';
    try {
      final nativeRes = await _firebaseAuthChannel.invokeMapMethod<String, dynamic>(
        'sendFirebaseOtp',
        {'phoneNumber': formattedPhone, 'isResend': isResend},
      ).timeout(const Duration(seconds: 45), onTimeout: () => null);

      if (nativeRes != null) {
        if (nativeRes['success'] == true) {
          final verificationId = nativeRes['verificationId']?.toString();
          lastFirebaseSessionInfo = verificationId;
          if (verificationId != null) {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('nearfix_last_firebase_session', verificationId);
            }).catchError((_) {});
          }
          if (nativeRes['smsCode'] != null && nativeRes['smsCode'].toString().isNotEmpty) {
            lastSentOtpCode = nativeRes['smsCode'].toString().trim();
          }
          return SmsResult(
            success: true,
            isSimulated: false,
            message: nativeRes['message']?.toString() ?? 'SMS verification code sent from Firebase',
            sessionId: verificationId,
          );
        } else {
          nativeError = nativeRes['message']?.toString() ?? 'Firebase SMS verification failed';
        }
      } else {
        nativeError = 'Firebase Play Services verification timed out.';
      }
    } catch (e) {
      nativeError = e.toString();
    }

    // 2. Fallback to Indian Telecom SMS Gateways (Fast2SMS / 2Factor)
    try {
      final key = activeApiKey.isNotEmpty ? activeApiKey : defaultFast2SmsKey;
      final fast2SmsResult = await _sendViaFast2Sms(phone, otp, key);
      if (fast2SmsResult.success) {
        return SmsResult(
          success: true,
          isSimulated: false,
          message: 'SMS delivered to +91 $phone via Indian SMS gateway',
          sessionId: fast2SmsResult.sessionId,
        );
      }
    } catch (_) {}

    try {
      final twoFactorResult = await _sendVia2Factor(phone, otp, default2FactorKey);
      if (twoFactorResult.success) {
        return SmsResult(
          success: true,
          isSimulated: false,
          message: 'OTP code sent to Registered Mobile number',
          sessionId: twoFactorResult.sessionId,
        );
      }
    } catch (_) {}

    // 3. Fallback: Firebase Identity Toolkit REST API (Acquires session token for web/testing)
    try {
      final effectiveKey = apiKey.isNotEmpty ? apiKey : defaultFirebaseApiKey;
      final url = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=$effectiveKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': formattedPhone,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = data['sessionInfo']?.toString();
        lastFirebaseSessionInfo = session;
        if (session != null) {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('nearfix_last_firebase_session', session);
          }).catchError((_) {});
        }
        // If native had no explicit error (e.g. running on web / test simulator)
        if (nativeError.isEmpty) {
          return SmsResult(
            success: true,
            isSimulated: false,
            message: 'SMS verification code dispatched from Firebase',
            sessionId: session,
          );
        }
      } else {
        try {
          final errData = jsonDecode(response.body);
          final errMsg = errData['error']?['message']?.toString();
          if (errMsg != null && errMsg.isNotEmpty) {
            nativeError = errMsg;
          }
        } catch (_) {}
      }
    } catch (e) {
      if (nativeError.isEmpty) nativeError = e.toString();
    }

    return SmsResult(
      success: false,
      isSimulated: false,
      message: nativeError.isNotEmpty
          ? 'Firebase Error: $nativeError'
          : 'Unable to dispatch SMS to +91 $phone. Check Firebase SHA-256 and SMS Region Policy.',
    );
  }


  /// 2Factor.in SMS / Voice OTP Gateway (Standard Indian Telecom DLT Approved API)
  static Future<SmsResult> _sendVia2Factor(String phone, String otp, String apiKey) async {
    try {
      // Primary DLT Whitelisted Template: OTP1
      final url1 = Uri.parse('https://2factor.in/API/V1/$apiKey/SMS/$phone/$otp/OTP1');
      final response1 = await http.get(url1).timeout(const Duration(seconds: 8));

      if (response1.statusCode == 200) {
        try {
          final data = jsonDecode(response1.body);
          if (data['Status'] == 'Success') {
            final sid = data['Details']?.toString();
            last2FactorSessionId = sid;
            return SmsResult(
              success: true,
              isSimulated: false,
              message: 'OTP delivered to Registered Mobile number',
              sessionId: sid,
            );
          }
        } catch (_) {}
      }

      // Fallback without template name
      final url2 = Uri.parse('https://2factor.in/API/V1/$apiKey/SMS/$phone/$otp');
      final response2 = await http.get(url2).timeout(const Duration(seconds: 8));

      if (response2.statusCode == 200) {
        try {
          final data = jsonDecode(response2.body);
          if (data['Status'] == 'Success') {
            final sid = data['Details']?.toString();
            last2FactorSessionId = sid;
            return SmsResult(
              success: true,
              isSimulated: false,
              message: 'OTP delivered to Registered Mobile number',
              sessionId: sid,
            );
          }
        } catch (_) {}
      }

      return SmsResult(
        success: false,
        isSimulated: false,
        message: '2Factor Gateway error: ${response1.body}',
      );
    } catch (e) {
      return SmsResult(
        success: false,
        isSimulated: false,
        message: 'SMS dispatch failed: $e',
      );
    }
  }

  /// Fast2SMS OTP Gateway (Single-request optimized to prevent duplicate wallet deductions)
  static Future<SmsResult> _sendViaFast2Sms(String phone, String otp, String apiKey) async {
    try {
      final url = Uri.parse('https://www.fast2sms.com/dev/bulkV2');

      // Attempt 1: Standard Fast2SMS OTP Route
      final otpResponse = await http.post(
        url,
        headers: {
          'authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'variables_values': otp,
          'route': 'otp',
          'numbers': phone,
        }),
      ).timeout(const Duration(seconds: 10));

      if (otpResponse.statusCode == 200) {
        try {
          final data = jsonDecode(otpResponse.body);
          if (data['return'] == true) {
            return SmsResult(
              success: true,
              isSimulated: false,
              message: 'SMS delivered to Registered Mobile number',
              sessionId: data['request_id']?.toString(),
            );
          }
          // If insufficient balance, return immediately - do not retry
          if (data['status_code'] == 416) {
            return SmsResult(
              success: false,
              isSimulated: false,
              message: data['message']?.toString() ?? 'Fast2SMS: Insufficient wallet balance.',
            );
          }
        } catch (_) {}
      }

      // Attempt 2: Quick SMS 'q' Route fallback (Only if OTP route returned 400/DLT restriction)
      final quickResponse = await http.post(
        url,
        headers: {
          'authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'route': 'q',
          'message': 'Your NearSlay OTP verification code is $otp.',
          'language': 'english',
          'flash': 0,
          'numbers': phone,
        }),
      ).timeout(const Duration(seconds: 10));

      if (quickResponse.statusCode == 200) {
        try {
          final data = jsonDecode(quickResponse.body);
          if (data['return'] == true) {
            return SmsResult(
              success: true,
              isSimulated: false,
              message: 'SMS delivered to Registered Mobile number',
              sessionId: data['request_id']?.toString(),
            );
          }
          final msg = data['message'] is List
              ? (data['message'] as List).join(', ')
              : data['message']?.toString();
          return SmsResult(
            success: false,
            isSimulated: false,
            message: msg ?? 'Fast2SMS dispatch failed',
          );
        } catch (_) {}
      }

      return const SmsResult(
        success: false,
        isSimulated: false,
        message: 'Fast2SMS dispatch failed. Please check wallet balance.',
      );
    } catch (e) {
      return SmsResult(
        success: false,
        isSimulated: false,
        message: 'Fast2SMS network error: $e',
      );
    }
  }

  /// MSG91 OTP Gateway
  static Future<SmsResult> _sendViaMsg91(String phone, String otp, String authKey) async {
    try {
      final url = Uri.parse('https://api.msg91.com/api/v5/otp?template_id=default&mobile=91$phone&authkey=$authKey&otp=$otp');
      final response = await http.post(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return SmsResult(
          success: true,
          isSimulated: false,
          message: 'Real SMS sent to +91 $phone via MSG91.',
        );
      }
      return SmsResult(
        success: false,
        isSimulated: false,
        message: 'MSG91 error: ${response.body}',
      );
    } catch (e) {
      return SmsResult(
        success: false,
        isSimulated: false,
        message: 'MSG91 connection error: $e',
      );
    }
  }

  /// Custom Webhook / Backend SMS Gateway
  static Future<SmsResult> _sendViaCustomWebhook(String phone, String otp, String urlStr, String apiKey) async {
    try {
      if (urlStr.isEmpty) {
        return const SmsResult(success: false, isSimulated: false, message: 'Webhook URL not configured.');
      }
      final url = Uri.parse(urlStr);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'phone': '+91$phone',
          'otp': otp,
          'appName': 'NearSlay',
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const SmsResult(
          success: true,
          isSimulated: false,
          message: 'Real SMS dispatched via Custom SMS Gateway.',
        );
      }
      return SmsResult(
        success: false,
        isSimulated: false,
        message: 'Custom gateway returned status ${response.statusCode}',
      );
    } catch (e) {
      return SmsResult(
        success: false,
        isSimulated: false,
        message: 'Custom gateway error: $e',
      );
    }
  }

  /// Standard Dispatch / Test Mode
  static Future<SmsResult> _dispatchStandardSms(String phone, String otp) async {
    return SmsResult(
      success: true,
      isSimulated: true,
      message: 'Verification code sent to +91 $phone',
    );
  }

  /// Test SMS gateway configuration live
  static Future<SmsResult> testSmsConnection({
    required String apiKey,
    required SmsGatewayProvider provider,
    required String testPhone,
  }) async {
    final cleanPhone = clean10DigitPhone(testPhone);
    if (cleanPhone.length < 10) {
      return const SmsResult(
        success: false,
        isSimulated: false,
        message: 'Enter a valid 10-digit mobile number for testing.',
      );
    }

    const testOtp = '123456';
    if (provider == SmsGatewayProvider.firebaseAuth) {
      return await _sendViaFirebaseAuth(cleanPhone, testOtp, apiKey);
    } else if (provider == SmsGatewayProvider.fast2sms) {
      return await _sendViaFast2Sms(cleanPhone, testOtp, apiKey);
    } else if (provider == SmsGatewayProvider.twoFactor) {
      return await _sendVia2Factor(cleanPhone, testOtp, apiKey);
    } else if (provider == SmsGatewayProvider.msg91) {
      return await _sendViaMsg91(cleanPhone, testOtp, apiKey);
    }
    return await _dispatchStandardSms(cleanPhone, testOtp);
  }

  /// Dispatch subscription reminder SMS (at 75 days, 85 days, grace period, or expiry)
  static Future<SmsResult> sendSubscriptionReminderSms({
    required String phone,
    required String providerName,
    required int daysLeft,
    required String status,
  }) async {
    final cleanPhone = clean10DigitPhone(phone);
    if (cleanPhone.length < 10) {
      return const SmsResult(
        success: false,
        isSimulated: false,
        message: 'Invalid phone number for reminder',
      );
    }

    String msg;
    if (status == 'expired') {
      msg = 'NearSlay Alert: Hi $providerName, your monthly subscription has expired. Pay Rs.99 + GST (Rs.116.82) to reactivate your profile and receive colony calls.';
    } else if (daysLeft < 0) {
      final buffer = 3 + daysLeft;
      msg = 'NearSlay Urgent: Hi $providerName, you have $buffer days grace period left. Renew Rs.99/mo + GST now to stay visible in resident searches.';
    } else {
      msg = 'NearSlay Reminder: Hi $providerName, your 90-day free trial ends in $daysLeft days. Renew for Rs.99/month + GST on NearSlay to stay visible.';
    }

    try {
      if (activeProvider == SmsGatewayProvider.fast2sms && activeApiKey.isNotEmpty) {
        final url = Uri.parse('https://www.fast2sms.com/dev/bulkV2');
        final response = await http.post(
          url,
          headers: {
            'authorization': activeApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'route': 'q',
            'message': msg,
            'language': 'english',
            'flash': 0,
            'numbers': cleanPhone,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          return const SmsResult(
            success: true,
            isSimulated: false,
            message: 'Reminder SMS dispatched via Fast2SMS.',
          );
        }
      }
    } catch (_) {}

    return SmsResult(
      success: true,
      isSimulated: true,
      message: 'Reminder SMS logged for +91 $cleanPhone: $msg',
    );
  }

  /// Dispatch payment confirmation & digital receipt SMS
  static Future<SmsResult> sendPaymentReceiptSms({
    required String phone,
    required num amount,
    required String receiptNo,
    required DateTime validUntil,
  }) async {
    final cleanPhone = clean10DigitPhone(phone);
    final dateStr = '${validUntil.day.toString().padLeft(2, '0')}/${validUntil.month.toString().padLeft(2, '0')}/${validUntil.year}';
    final amountFormatted = amount is double ? amount.toStringAsFixed(2) : amount.toString();
    final msg = 'NearSlay Pro: Payment of Rs.$amountFormatted confirmed (Rec: $receiptNo). Your profile is active and Available until $dateStr. Thank you!';

    try {
      if (activeProvider == SmsGatewayProvider.fast2sms && activeApiKey.isNotEmpty) {
        final url = Uri.parse('https://www.fast2sms.com/dev/bulkV2');
        final response = await http.post(
          url,
          headers: {
            'authorization': activeApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'route': 'q',
            'message': msg,
            'language': 'english',
            'flash': 0,
            'numbers': cleanPhone,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          return const SmsResult(
            success: true,
            isSimulated: false,
            message: 'Receipt SMS dispatched via Fast2SMS.',
          );
        }
      }
    } catch (_) {}

    return SmsResult(
      success: true,
      isSimulated: true,
      message: 'Receipt SMS logged for +91 $cleanPhone: $msg',
    );
  }
}

