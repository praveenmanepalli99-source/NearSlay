import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
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
  late RazorpayService _razorpayService;

  bool _isProcessing = false;

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
              content: Text('Payment cancelled. Please tap Pay to retry.'),
              backgroundColor: AppColors.busyOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${response.message ?? "Could not initialize checkout"}. Please try again.'),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onExternalWallet: (ExternalWalletResponse response) {
        setState(() => _isProcessing = false);
      },
    );
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
            Tab(icon: Icon(Icons.star_rounded, size: 18), text: 'Plan & Payment'),
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
      statusTitle = 'Pending Verification';
      statusSubtitle = 'Payment processing • Awaiting confirmation';
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
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
                const SizedBox(height: 6),
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
                    _buildPaymentBadge('CRED UPI', const Color(0xFF1E293B)),
                    _buildPaymentBadge('All UPI Apps', const Color(0xFF475569)),
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
                const Text(
                  'Tax & Price Breakdown',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('Base Subscription Plan (1 Month)', '₹99.00'),
                _buildSummaryRow('CGST (9.0%)', '₹8.91'),
                _buildSummaryRow('SGST (9.0%)', '₹8.91'),
                _buildSummaryRow('Total GST (18%)', '₹17.82', color: const Color(0xFF475569)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Payable Amount',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${finalPayable.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 19,
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

          // 5. Single Unified Pay Button (Routes through Razorpay with UPI Apps intent)
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
                      Icons.lock_outline_rounded,
                      size: 20,
                    ),
              label: Text(
                _isProcessing
                    ? 'Processing Payment...'
                    : 'Pay ₹${finalPayable.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 6. Security Footer Badge (Aligned & Responsive)
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 6),
                Text(
                  'Bank-Grade Security • Instant Activation • Tax Invoice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
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
          // Section Header: My Payment Invoices
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

          // List of payments or empty state
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
                    'When you renew your NearSlay Pro monthly subscription, your official tax invoices and receipts will appear here.',
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
