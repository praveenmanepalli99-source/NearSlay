import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/nearfix_state.dart';
import '../theme/app_colors.dart';
import '../services/sms_service.dart';
import 'otp_verification_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Proactively request location permission on app open across all devices (Vivo, Samsung, Xiaomi, etc.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = Provider.of<NearFixState>(context, listen: false);
        state.ensureLocationPermissionPrompt();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final state = Provider.of<NearFixState>(context, listen: false);
    final formattedPhone = phone.startsWith('+91') ? phone : '+91 $phone';
    final generatedOtp = state.requestOtp(formattedPhone);

    // Trigger live mobile dispatch asynchronously in background
    final smsFuture = SmsService.sendOtpSms(phone: formattedPhone, otp: generatedOtp);

    // Trigger cloud sync asynchronously in background without blocking UI
    state.syncWithCloud(showIndicator: false);

    // Snappy visual feedback (under 250ms) then navigate immediately
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      setState(() => _isSending = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            phoneNumber: formattedPhone,
            generatedOtp: generatedOtp,
            initialSmsFuture: smsFuture,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topSpacing = screenHeight > 750 ? 20.0 : 12.0;
    final middleSpacing = screenHeight > 750 ? 30.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: topSpacing),

                      // App Logo with dynamic sizing
                      Container(
                        width: screenHeight > 700 ? 110 : 90,
                        height: screenHeight > 700 ? 110 : 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // App Name & Tagline
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'NearSlay',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Instant Neighborhood Services & Verified Providers',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: middleSpacing),

                      // Mobile Input Container
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enter Mobile Number',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'We\'ll send a 6-digit OTP to verify your account.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Phone Number Input
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                              decoration: InputDecoration(
                                prefixText: '+91 ',
                                prefixStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                counterText: '',
                                hintText: '98450 XXXXX',
                                prefixIcon: const Icon(Icons.phone_android_rounded,
                                    color: AppColors.primary),
                                filled: true,
                                fillColor: AppColors.surfaceVariant.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _isSending ? null : _sendOtp(),
                            ),
                            const SizedBox(height: 20),

                            // Send OTP Button - Dynamic Fitted Layout
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSending ? null : _sendOtp,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSending
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Get OTP Verification Code',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 18),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Trust Badges - Dynamic Wrap layout to prevent overflow on all screen ratios
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildTrustItem(Icons.verified_user_rounded, 'Verified Local Pros'),
                          _buildTrustItem(Icons.phone_in_talk_rounded, 'Direct Phone Calls'),
                        ],
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildTrustItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
