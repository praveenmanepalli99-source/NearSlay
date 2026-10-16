import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/nearfix_state.dart';
import '../models/provider_model.dart';
import '../models/payment_model.dart';
import '../services/subscription_service.dart';
import '../services/razorpay_service.dart';
import '../theme/app_colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _historyUtrSearchController = TextEditingController();
  late RazorpayService _razorpayService;

  bool _isProcessing = false;

  // Real-time UTR lookup state in History tab
  PaymentModel? _searchedPayment;
  bool _isSearchingUtr = false;
  String? _searchUtrMessage;
  bool _searchUtrSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _razorpayService = RazorpayService();
    final state = Provider.of<NearFixState>(context, listen: false);
    if (state.currentProvider != null) {
      state.loadProviderPayments(state.currentProvider!.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _historyUtrSearchController.dispose();
    _razorpayService.dispose();
    super.dispose();
  }


  /// Launch seamless 1-tap Razorpay Standard Checkout (UPI / Cards / NetBanking)
  void _processRazorpayPayment(double finalPayable) {
    if (_isProcessing) return;
    final state = Provider.of<NearFixState>(context, listen: false);
    final provider = state.currentProvider ??
        (state.verifiedPhone.isNotEmpty
            ? state.allProviders.where((p) => p.realPhone == state.verifiedPhone || p.id == state.verifiedPhone).firstOrNull
            : null);

    final effectiveName = (provider?.name.isNotEmpty == true) ? provider!.name : 'NearSlay Partner';
    final effectivePhone = (provider?.realPhone.isNotEmpty == true)
        ? provider!.realPhone
        : (state.verifiedPhone.isNotEmpty ? state.verifiedPhone : '9876543210');

    setState(() => _isProcessing = true);
    final now = DateTime.now();
    final recNumber = 'NS-REC-${now.millisecondsSinceEpoch.toString().substring(5)}';

    _razorpayService.openCheckout(
      amount: finalPayable,
      providerName: effectiveName,
      providerPhone: effectivePhone,
      receiptNumber: recNumber,
      onSuccess: (PaymentSuccessResponse response) async {
        final payId = response.paymentId ?? 'pay_${now.millisecondsSinceEpoch}';

        // Auto-activate subscription immediately via Razorpay verified payment
        final result = await state.renewSubscription(
          gateway: 'Razorpay UPI',
          amount: finalPayable,
          transactionId: payId,
          utrNumber: payId,
          autoBilling: true,
          requireAdminVerification: false,
        );

        setState(() => _isProcessing = false);

        if (!mounted) return;
        if (result['success'] == true) {
          final payment = result['payment'] as PaymentModel?;
          if (payment != null) {
            _showSuccessReceiptDialog(payment);
          }
        }
      },
      onFailure: (PaymentFailureResponse response) {
        setState(() => _isProcessing = false);
        if (!mounted) return;
        if (response.code == Razorpay.PAYMENT_CANCELLED) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled. You can retry or choose direct UPI.'),
              backgroundColor: AppColors.busyOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          _showPaymentFallbackDialog(
            finalPayable,
            response.message ?? 'Checkout could not be initialized',
          );
        }
      },
      onExternalWallet: (ExternalWalletResponse response) {
        setState(() => _isProcessing = false);
      },
    );
  }

  /// Launch Direct UPI App (Google Pay / PhonePe / Paytm / BHIM)
  Future<void> _launchDirectUpi(double finalPayable) async {
    final state = Provider.of<NearFixState>(context, listen: false);
    final provider = state.currentProvider;
    final now = DateTime.now();
    final recNumber = 'NS-REC-${now.millisecondsSinceEpoch.toString().substring(5)}';

    final upiUrl = SubscriptionService.generateUpiUri(
      amount: finalPayable,
      receiptNumber: recNumber,
      providerName: provider?.name ?? 'NearSlay Partner',
    );

    final uri = Uri.parse(upiUrl);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
      if (mounted) {
        _showUtrPromptDialog(finalPayable, recNumber);
      }
    } catch (e) {
      if (mounted) {
        _showPaymentFallbackDialog(finalPayable, 'Could not open UPI app directly: $e');
      }
    }
  }

  /// Dialog when Razorpay has an issue or key is pending
  void _showPaymentFallbackDialog(double finalPayable, String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payment_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Payment Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Online checkout message: $reason.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pay ₹116.82 instantly with any UPI app (Google Pay, PhonePe, Paytm, BHIM):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_rounded, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'UPI ID: pandupraveennani58@ybl\nPayee: NearSlay Services',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _launchDirectUpi(finalPayable);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Pay via UPI App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Prompt for UTR verification after direct UPI payment
  void _showUtrPromptDialog(double finalPayable, String receiptNumber) {
    final utrController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'After completing payment in Google Pay / PhonePe / Paytm, enter the UPI Reference ID / UTR below to verify your subscription:',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: utrController,
              decoration: InputDecoration(
                hintText: 'e.g. 423456789012',
                labelText: 'UPI UTR / Reference ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              final utr = utrController.text.trim();
              if (utr.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid Reference / UTR Number')),
                );
                return;
              }
              Navigator.pop(ctx);
              final state = Provider.of<NearFixState>(context, listen: false);
              final res = await state.renewSubscription(
                gateway: 'Direct UPI',
                amount: finalPayable,
                transactionId: utr,
                utrNumber: utr,
                autoBilling: false,
                requireAdminVerification: true,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['success'] == true
                        ? 'Payment submitted! UTR is under verification.'
                        : 'Submission saved.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Submit UTR'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkVerificationStatus() async {
    final state = Provider.of<NearFixState>(context, listen: false);
    final provider = state.currentProvider;
    if (provider == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking subscription status...'),
        duration: Duration(seconds: 1),
      ),
    );

    await state.syncWithCloud();

    final updated = state.currentProvider;
    if (!mounted) return;

    if (updated != null && updated.subscriptionStatus == 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 NearSlay Pro is Active!'),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription verification in progress or inactive.'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccessReceiptDialog(PaymentModel payment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.all(22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'NearSlay Pro Activated!',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your profile is now Available & visible across colonies.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('Tax Invoice No', payment.receiptNumber),
                  _buildReceiptRow('Base Plan Price', '₹99.00'),
                  _buildReceiptRow('GST (18%)', '₹17.82'),
                  _buildReceiptRow('Total Paid', payment.formattedAmount,
                      valueColor: const Color(0xFF059669), isBold: true),
                  _buildReceiptRow('Payment Method', payment.gateway),
                  _buildReceiptRow('Transaction Ref', payment.transactionId),
                  _buildReceiptRow('Valid Until', payment.formattedExpiryDate),
                  _buildReceiptRow('Status', 'Active Pro',
                      valueColor: const Color(0xFF059669), isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text:
                              'NearSlay Tax Invoice: ${payment.receiptNumber}\nAmount: ${payment.formattedAmount} (Base ₹99 + 18% GST)\nValid Until: ${payment.formattedExpiryDate}\nStatus: Active'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tax invoice copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Invoice'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUtrInCloud(NearFixState state) async {
    final query = _historyUtrSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchUtrMessage = 'Please enter a Reference ID or Receipt Number.';
        _searchUtrSuccess = false;
        _searchedPayment = null;
      });
      return;
    }

    setState(() {
      _isSearchingUtr = true;
      _searchUtrMessage = null;
      _searchedPayment = null;
    });

    try {
      final payment = await state.checkPaymentByUtr(query);
      if (!mounted) return;
      if (payment != null) {
        setState(() {
          _isSearchingUtr = false;
          _searchedPayment = payment;
          _searchUtrSuccess = true;
          _searchUtrMessage = 'Payment record found and verified!';
        });
      } else {
        setState(() {
          _isSearchingUtr = false;
          _searchedPayment = null;
          _searchUtrSuccess = false;
          _searchUtrMessage = 'No matching payment found for "$query".';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearchingUtr = false;
        _searchedPayment = null;
        _searchUtrSuccess = false;
        _searchUtrMessage = 'Failed to check payment status: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<NearFixState>(context);
    final provider = state.currentProvider;

    if (provider == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription Plan')),
        body: const Center(
          child: Text('Please log in as a Service Provider.'),
        ),
      );
    }

    const double finalPayable = SubscriptionService.totalPlanPriceInr; // Fixed ₹116.82 (₹99 + 18% GST)

    return Scaffold(
      appBar: AppBar(
        title: const Text('NearSlay Pro Subscription'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.star_rounded, size: 18), text: 'Plan & Direct UPI'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Invoices & History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPaymentTab(state, provider, finalPayable),
          _buildHistoryTab(state),
        ],
      ),
    );
  }

  Widget _buildPaymentTab(
      NearFixState state, ProviderModel provider, double finalPayable) {
    final days = provider.daysRemaining;
    final isExpired = provider.isExpired;
    final isGrace = provider.isWithinGracePeriod;

    Color statusColor = const Color(0xFF059669);
    String statusTitle = '90-Day Free Trial Active';
    String statusSubtitle = '$days days remaining';

    if (provider.subscriptionStatus == 'pending_verification') {
      statusColor = const Color(0xFFD97706);
      statusTitle = 'Pending Admin Verification';
      statusSubtitle = 'UTR submitted • Awaiting approval from Admin Dashboard';
    } else if (isExpired) {
      statusColor = const Color(0xFFDC2626);
      statusTitle = 'Subscription Expired';
      statusSubtitle = 'Hidden from resident search • Renew ₹99 + GST to reactivate';
    } else if (isGrace) {
      statusColor = const Color(0xFFD97706);
      statusTitle = 'Grace Period Active (3 Days)';
      statusSubtitle = '${days.abs()} days overdue • Pay to avoid being hidden';
    } else if (provider.subscriptionStatus == 'active') {
      statusColor = const Color(0xFF059669);
      statusTitle = 'NearSlay Pro Active';
      statusSubtitle = 'Renews on ${provider.subscriptionEndDate.isNotEmpty ? provider.formattedDistance : "$days days remaining"}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dynamic Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor.withOpacity(0.08), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExpired
                            ? Icons.error_outline_rounded
                            : (isGrace ? Icons.warning_amber_rounded : Icons.verified_rounded),
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusSubtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: isExpired
                        ? 1.0
                        : (days > 0 ? (90 - days).clamp(0, 90) / 90.0 : 1.0),
                    backgroundColor: statusColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trial / Cycle: 90 Days',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                    Text(
                      isExpired
                          ? 'Expired'
                          : (isGrace ? 'Grace Period' : '$days Days Left'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (provider.subscriptionStatus == 'pending_verification') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Payment Under Admin Verification',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your submitted UTR reference is currently being verified against our SBI account statement. Tap below to check if admin has approved your payment.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _checkVerificationStatus,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Check Verification Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // 2. Plan Card (₹99 Base + 18% GST)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NearSlay Pro Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Uninterrupted colony visibility & direct calls',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '₹99 + GST',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _buildBenefitRow(Icons.visibility_rounded, 'Stay 100% visible in Colony & 10km radius searches'),
                _buildBenefitRow(Icons.phone_in_talk_rounded, 'Receive direct phone calls & WhatsApp requests from residents'),
                _buildBenefitRow(Icons.verified_user_rounded, 'Verified Technician Badge on profile card'),
                _buildBenefitRow(Icons.percent_rounded, 'Zero commission - Keep 100% of your labor earnings'),
                _buildBenefitRow(Icons.auto_awesome_rounded, 'AI Diagnostic lead matching to your trade category'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Payment Method: Razorpay UPI (GPay / PhonePe / Paytm / BHIM)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Select Payment Method',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Razorpay UPI (GPay / PhonePe / Paytm / BHIM)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Instant automated 1-tap checkout • All UPI Apps & Cards supported',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),

                // Supported apps badge row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPaymentBadge('PhonePe', const Color(0xFF5F259F)),
                    _buildPaymentBadge('Google Pay', const Color(0xFF1A73E8)),
                    _buildPaymentBadge('Paytm', const Color(0xFF00BAF2)),
                    _buildPaymentBadge('BHIM UPI', const Color(0xFF059669)),
                    _buildPaymentBadge('Debit/Credit Cards', const Color(0xFF334155)),
                    _buildPaymentBadge('NetBanking', const Color(0xFF475569)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '256-bit Bank-Grade Encryption • RBI Authorized Razorpay Gateway',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Detailed Tax Breakdown Summary (₹99 Base + 18% GST)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tax & Price Breakdown',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _buildSummaryRow('Base Subscription Plan (1 Month)', '₹99.00'),
                _buildSummaryRow('CGST (9.0%)', '₹8.91'),
                _buildSummaryRow('SGST (9.0%)', '₹8.91'),
                _buildSummaryRow('Total GST (18%)', '₹17.82', color: const Color(0xFF475569)),
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Payable Amount',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${finalPayable.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 7. Instant Pay & Activate Button (Razorpay Seamless Checkout)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () => _processRazorpayPayment(finalPayable),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(
                      Icons.flash_on_rounded,
                      size: 20,
                    ),
              label: Text(
                _isProcessing
                    ? 'Launching Razorpay...'
                    : 'Pay ₹${finalPayable.toStringAsFixed(2)} via Razorpay (UPI)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 8. Direct UPI Apps Button (Google Pay / PhonePe / Paytm / BHIM)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _launchDirectUpi(finalPayable),
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 19, color: Color(0xFF2563EB)),
              label: const Text(
                'Pay via UPI Apps (Google Pay / PhonePe / Paytm)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '🔒 Bank-Grade Security • Automated Verification • Instant Tax Invoice',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String amount,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? AppColors.textSecondary,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(NearFixState state) {
    final payments = state.myPayments;

    return RefreshIndicator(
      onRefresh: () async {
        if (state.currentProvider != null) {
          await state.loadProviderPayments(state.currentProvider!.id);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Live UTR Verification & Lookup Tool
          _buildUtrVerificationCard(state),
          const SizedBox(height: 20),

          // 2. Section Header: My Payment Invoices
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Payment Invoices',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (state.currentProvider != null)
                IconButton(
                  icon: const Icon(Icons.sync_rounded, size: 20, color: AppColors.primary),
                  tooltip: 'Sync latest receipts',
                  onPressed: () {
                    state.loadProviderPayments(state.currentProvider!.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing latest receipts...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. List of payments or empty state
          if (payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        size: 40, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No Payment Receipts Yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When you renew your ₹99 + GST monthly subscription via UPI, your official tax invoices and receipts will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...payments.map((payment) => _buildPaymentItemCard(payment)),
        ],
      ),
    );
  }

  Widget _buildUtrVerificationCard(NearFixState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.search_rounded,
                    color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check Payment by UTR / Reference No.',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Verify payment status using your UPI UTR or reference number',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _historyUtrSearchController,
                  decoration: InputDecoration(
                    hintText: 'Enter Reference No. or Receipt No.',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.receipt_rounded, size: 18),
                    suffixIcon: _historyUtrSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              setState(() {
                                _historyUtrSearchController.clear();
                                _searchedPayment = null;
                                _searchUtrMessage = null;
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null && data!.text!.isNotEmpty) {
                    setState(() {
                      _historyUtrSearchController.text = data.text!.trim();
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.content_paste_rounded, size: 14, color: AppColors.textPrimary),
                      SizedBox(width: 4),
                      Text(
                        'Paste',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Check UTR Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSearchingUtr ? null : () => _checkUtrInCloud(state),
              icon: _isSearchingUtr
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_user_rounded, size: 17),
              label: Text(
                _isSearchingUtr ? 'Verifying Reference...' : 'Check & Verify UTR',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // Display Result
          if (_searchUtrMessage != null) ...[
            const SizedBox(height: 12),
            if (_searchUtrSuccess && _searchedPayment != null)
              _buildFoundPaymentCard(_searchedPayment!, state)
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _searchUtrMessage!,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoundPaymentCard(PaymentModel p, NearFixState state) {
    final isCurrentProvider = state.currentProvider != null &&
        (state.currentProvider!.id == p.providerId ||
            state.currentProvider!.realPhone.replaceAll(RegExp(r'\D'), '') ==
                p.providerPhone.replaceAll(RegExp(r'\D'), ''));
    final isProfileActive = state.currentProvider?.subscriptionStatus == 'active';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'MATCHED & VERIFIED',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                p.formattedAmount,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDetailField('Transaction Ref:', p.transactionId),
          _buildDetailField('Receipt No:', p.receiptNumber),
          _buildDetailField('Provider:', '${p.providerName} (${p.providerPhone})'),
          _buildDetailField('Paid Date:', p.formattedDate),
          _buildDetailField('Active Until:', p.formattedExpiryDate),
          _buildDetailField('Payment Gateway:', p.gateway),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showSuccessReceiptDialog(p),
                  icon: const Icon(Icons.receipt_long_rounded, size: 15),
                  label: const Text('View Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF065F46),
                    side: const BorderSide(color: Color(0xFF059669)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (isCurrentProvider && !isProfileActive) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await state.applyVerifiedCloudPayment(p);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Subscription activated successfully from verified payment!'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    },
                    icon: const Icon(Icons.flash_on_rounded, size: 15),
                    label: const Text('Activate Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF064E3B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItemCard(PaymentModel payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        color: Color(0xFF059669), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.receiptNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        payment.formattedDate,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                payment.formattedAmount,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Valid: ${payment.formattedDate} - ${payment.formattedExpiryDate}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              InkWell(
                onTap: () => _showSuccessReceiptDialog(payment),
                child: const Row(
                  children: [
                    Text(
                      'View Tax Invoice',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
