import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/nearfix_state.dart';
import '../models/provider_model.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../services/sms_service.dart';
import '../services/cloud_sync_service.dart';
import 'new_user_role_choice_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String generatedOtp;
  final Future<SmsResult>? initialSmsFuture;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.generatedOtp,
    this.initialSmsFuture,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  int _secondsRemaining = 30;
  Timer? _timer;
  late String _activeOtp;
  bool _isVerifying = false;
  bool _smsFailed = false;
  bool _smsSending = true;
  String? _smsFailureReason;
  bool _isSendingWhatsApp = false;

  @override
  void initState() {
    super.initState();
    _activeOtp = widget.generatedOtp;
    _startTimer();
    _listenToSmsDispatch();
  }

  void _listenToSmsDispatch() {
    if (widget.initialSmsFuture != null) {
      widget.initialSmsFuture!.then((result) {
        if (!mounted) return;
        setState(() {
          _smsSending = false;
          if (!result.success) {
            _smsFailed = true;
            _smsFailureReason = result.message;
          }
        });
        if (!result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _smsFailureReason != null && _smsFailureReason!.isNotEmpty
                          ? _smsFailureReason!
                          : 'Carrier SMS delayed or DLT restricted. Please tap Get via WhatsApp.',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.errorRed,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }).catchError((err) {
        if (!mounted) return;
        setState(() {
          _smsSending = false;
          _smsFailed = true;
          _smsFailureReason = 'Carrier SMS delivery delayed or DLT restricted.';
        });
      });
    } else {
      _smsSending = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final inputOtp = _otpController.text.trim();
    if (inputOtp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    final state = Provider.of<NearFixState>(context, listen: false);

    final cleanDigits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final pPhone = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
    final bool isTestEnv = WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');

    // 1. Authoritative Cloud Verification: if deleted from cloud, immediately purge local caches
    bool existsInCloud = true;
    if (!isTestEnv) {
      existsInCloud = await CloudSyncService.isUserAvailableInCloud(pPhone);
      if (!existsInCloud) {
        state.purgeUserByPhone(pPhone);
      }
    }

    // 2. Force live cloud sync to guarantee latest registered accounts from all devices are loaded
    await state.syncWithCloud(showIndicator: false);

    // 3. Universal OTP Verification across all gateways (Google Firebase Play Services carrier SMS, 2Factor.in, Fast2SMS, sent code, or test bypass 112233)
    final isCodeValid = await SmsService.verifyReceivedCode(inputOtp, expectedOtp: _activeOtp);
    final isValid = state.verifyOtp(inputOtp, firebaseVerified: isCodeValid, expectedOtp: _activeOtp);

    setState(() => _isVerifying = false);

    if (isValid) {
      // 4. Check if account already exists
      var account = state.checkExistingAccount(widget.phoneNumber);

      if (!isTestEnv && !existsInCloud) {
        state.purgeUserByPhone(pPhone);
        account = {'exists': false};
      }

      if (account['exists'] == true) {
        if (account['role'] == AppRole.provider) {
          final prov = account['provider'] as ProviderModel;
          state.setRole(AppRole.provider);
          state.detectLiveGpsLocation(silent: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Welcome back ${prov.name}! Logged in as Service Provider.'),
                backgroundColor: AppColors.primary,
              ),
            );
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          return;
        } else if (account['role'] == AppRole.resident) {
          final res = account['resident'] as UserModel;
          state.setRole(AppRole.resident);
          state.detectLiveGpsLocation(silent: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Welcome back ${res.name}! Logged in as Resident.'),
                backgroundColor: AppColors.primary,
              ),
            );
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          return;
        }
      }

      // NEW USER (not found in cloud or local database) -> Show role choice
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                NewUserRoleChoiceScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect OTP. Please enter the code sent to your mobile or tap Resend OTP.'),
            backgroundColor: AppColors.errorRed,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleGetViaWhatsApp() async {
    setState(() => _isSendingWhatsApp = true);

    await SmsService.sendWhatsAppOtp(
      phone: widget.phoneNumber,
      otp: _activeOtp,
    );

    if (!mounted) return;
    setState(() {
      _isSendingWhatsApp = false;
      _smsFailed = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Verification code dispatched to ${widget.phoneNumber}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E7E34),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Mobile OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),

                      // App Logo
                      Container(
                        width: 85,
                        height: 85,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Enter Verification Code',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Sent 6-digit OTP to ',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          Text(
                            widget.phoneNumber,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Carrier SMS DLT / Balance Failure Alert
                      if (_smsFailed) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Carrier SMS Delivery Issue',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _smsFailureReason?.contains('416') == true ||
                                              _smsFailureReason?.contains('balance') == true
                                          ? 'Carrier SMS dropped due to insufficient gateway balance / DLT. Please tap Get via WhatsApp below.'
                                          : 'Carrier SMS delayed or DLT restricted. Please tap Get via WhatsApp below.',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Prominent "Get via WhatsApp" Button when SMS failed
                      if (_smsFailed) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isSendingWhatsApp
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.chat_bubble_rounded, size: 18, color: Colors.white),
                            label: Text(
                              _isSendingWhatsApp ? 'Delivering OTP via WhatsApp...' : 'Get via WhatsApp',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isSendingWhatsApp ? null : _handleGetViaWhatsApp,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // OTP Input Box
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                          color: AppColors.primaryDark,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '• • • • • •',
                          hintStyle: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 8,
                            color: AppColors.textMuted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _verifyOtp(),
                      ),
                      const SizedBox(height: 20),

                      // Resend Timer & WhatsApp Option
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_secondsRemaining > 0)
                            Text(
                              'Resend SMS in ${_secondsRemaining}s',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            )
                          else
                            TextButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                              label: const Text(
                                'Resend SMS',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              onPressed: () async {
                                final state = Provider.of<NearFixState>(context, listen: false);
                                final newOtp = state.requestOtp(widget.phoneNumber);
                                _activeOtp = newOtp;
                                _startTimer();

                                final messenger = ScaffoldMessenger.of(context);
                                final smsResult = await SmsService.sendOtpSms(
                                  phone: widget.phoneNumber,
                                  otp: newOtp,
                                  isResend: true,
                                );

                                if (!mounted) return;
                                setState(() {
                                  if (!smsResult.success) {
                                    _smsFailed = true;
                                    _smsFailureReason = smsResult.message;
                                  } else {
                                    _smsFailed = false;
                                  }
                                });
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(smsResult.success
                                        ? 'Verification code resent to ${widget.phoneNumber}'
                                        : (smsResult.message.isNotEmpty
                                            ? smsResult.message
                                            : 'Failed to resend code. Please tap Get via WhatsApp.')),
                                    backgroundColor: smsResult.success ? AppColors.primary : AppColors.errorRed,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              },
                            ),
                          // Secondary WhatsApp Option (available if not already in failure prominent view)
                          if (!_smsFailed)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF25D366),
                                side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isSendingWhatsApp
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(color: Color(0xFF25D366), strokeWidth: 1.8),
                                    )
                                  : const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF25D366)),
                              label: Text(
                                _isSendingWhatsApp ? 'Sending...' : 'Get via WhatsApp',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E7E34),
                                ),
                              ),
                              onPressed: _isSendingWhatsApp ? null : _handleGetViaWhatsApp,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Verify OTP & Proceed',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
