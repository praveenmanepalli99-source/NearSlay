import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/nearfix_state.dart';
import '../theme/app_colors.dart';
import '../widgets/status_pill.dart';
import '../widgets/provider_card.dart';
import '../widgets/avatar_helper.dart';
import 'provider_registration_screen.dart';
import 'my_profile_screen.dart';
import '../models/provider_model.dart';
import 'subscription_screen.dart';
import '../services/subscription_service.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<NearFixState>(context);
    final provider = state.currentProvider;

    if (provider == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Provider Dashboard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Return to Resident Mode',
            onPressed: () => state.switchToRole(AppRole.resident),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => state.switchToRole(AppRole.resident),
              icon: const Icon(Icons.home_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Resident Mode',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Sync Cloud',
              onPressed: () => state.syncWithCloud(showIndicator: true),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.handyman_rounded, size: 54, color: AppColors.secondary),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Complete Provider Registration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set your trade category and hourly charge to start receiving repair calls. Includes 90 Days Free Trial!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProviderRegistrationScreen(
                          prefilledPhone: state.verifiedPhone,
                          prefilledName: state.currentUser?.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Register as Service Provider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => state.switchToRole(AppRole.resident),
                  icon: const Icon(Icons.home_outlined, size: 18, color: AppColors.primary),
                  label: const Text('Switch back to Resident Mode'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    void handleSwitchToResident() {
      state.switchToRole(AppRole.resident);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched to Resident Mode! You can now browse nearby repair technicians.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }

    final reminder = state.activeReminderAlert;
    final isExpired = provider.isExpired;
    final isGrace = provider.isWithinGracePeriod;
    final daysRemaining = provider.daysRemaining;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: AppColors.primary, size: 22),
            tooltip: 'Subscription Plan (₹99/mo)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined, color: AppColors.primary, size: 22),
            tooltip: 'Switch to Resident Mode',
            onPressed: handleSwitchToResident,
          ),
          IconButton(
            icon: state.isCloudSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.sync_rounded, color: AppColors.primary, size: 20),
            tooltip: 'Sync Cloud Database',
            onPressed: () async {
              await state.syncWithCloud(showIndicator: true);
              if (context.mounted) {
                if (!state.isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account not found in database. You have been logged out.'),
                      duration: Duration(seconds: 3),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cloud Synced! Latest registrations & status updated.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyProfileScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(left: 4, right: 16),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.secondaryLight,
                backgroundImage: AvatarHelper.getImageProvider(provider.avatarUrl),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await state.syncWithCloud(showIndicator: true);
          if (context.mounted && !state.isLoggedIn) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account not found in database. You have been logged out.'),
                duration: Duration(seconds: 3),
                backgroundColor: AppColors.errorRed,
              ),
            );
          }
        },
        color: AppColors.secondary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Dynamic Reminder Banner (75 days, 85 days, Grace Period, or Expired)
            if (reminder != null)
              _buildReminderAlertBanner(context, state, reminder),

            // 2. Switch to Resident Mode Banner
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: handleSwitchToResident,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Switch to Resident Mode',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Text(
                              'Switch to Resident Mode to find & call local technicians',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Subscription Status Card
            _buildSubscriptionCard(context, provider, daysRemaining, isExpired, isGrace),
            const SizedBox(height: 16),

            // 4. Provider Profile Banner & Availability Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.surfaceVariant,
                        backgroundImage: AvatarHelper.getImageProvider(provider.avatarUrl),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    provider.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${provider.categoryTitle} • ${provider.colonyName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Starts from ₹${provider.hourlyRate}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (provider.bio.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1, right: 6),
                            child: Icon(Icons.handyman_outlined, size: 13, color: AppColors.secondary),
                          ),
                          Expanded(
                            child: Text(
                              'Work: ${provider.bio.trim()}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  const SizedBox(height: 12),

                  // Real-time Availability Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: provider.isAvailable
                          ? AppColors.availableGreenBg
                          : AppColors.busyOrangeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        StatusPill(isAvailable: provider.isAvailable),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.isAvailable
                                ? 'Available for Calls'
                                : (isExpired ? 'Marked Busy (Expired)' : 'Marked as Busy'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: provider.isAvailable
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF9A3412),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch.adaptive(
                            value: provider.isAvailable,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              if (isExpired && val == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Your subscription has expired. Please renew ₹99/mo to become Available.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                                );
                                return;
                              }
                              state.toggleMyAvailability();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Direct Contact Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.phone_in_talk_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Direct Contact Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Colony residents can reach you directly via phone call or WhatsApp message at ${provider.realPhone} when your status is Available.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Card Preview (How Residents See You)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Card Preview in Colony Feed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyProfileScreen(),
                      ),
                    );
                  },
                  child: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProviderCard(provider: provider, margin: EdgeInsets.zero),

            const SizedBox(height: 20),

            // Quick Stats
            Row(
              children: [
                _buildStatCard('₹${provider.hourlyRate}', 'Starts from', AppColors.primary),
                const SizedBox(width: 10),
                _buildStatCard('4.9 ★', 'Rating', const Color(0xFFD97706)),
                const SizedBox(width: 10),
                _buildStatCard(provider.isAvailable ? 'Active' : 'Offline', 'Status',
                    provider.isAvailable ? AppColors.availableGreen : AppColors.busyOrange),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    ProviderModel provider,
    int daysRemaining,
    bool isExpired,
    bool isGrace,
  ) {
    Color cardColor = const Color(0xFF059669);
    String title = '90-Day Free Trial';
    String desc = '$daysRemaining days remaining before ₹99/month renewal';

    if (isExpired) {
      cardColor = const Color(0xFFDC2626);
      title = 'Subscription Expired';
      desc = 'Your profile is hidden from customer search. Renew ₹99/mo to become Available.';
    } else if (isGrace) {
      cardColor = const Color(0xFFD97706);
      title = 'Grace Period (3 Days)';
      desc = '${daysRemaining.abs()} days overdue. Renew ₹99/mo to avoid being hidden.';
    } else if (provider.subscriptionStatus == 'active') {
      cardColor = const Color(0xFF059669);
      title = 'NearSlay Pro Active';
      desc = 'Renews on ${provider.formattedDistance} • ₹99 + GST/month';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardColor.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.star_rounded, color: cardColor, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: cardColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExpired
                      ? 'Expired'
                      : (isGrace ? 'Grace Buffer' : '$daysRemaining Days Left'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cardColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: isExpired
                  ? 1.0
                  : (daysRemaining > 0 ? (90 - daysRemaining).clamp(0, 90) / 90.0 : 1.0),
              backgroundColor: cardColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(cardColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                    );
                  },
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: Text(
                    isExpired ? 'Reactivate Now (₹99)' : 'Manage Plan & Renew',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpired ? const Color(0xFFDC2626) : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderAlertBanner(
    BuildContext context,
    NearFixState state,
    SubscriptionReminderAlert reminder,
  ) {
    Color bg = const Color(0xFFFEF3C7);
    Color border = const Color(0xFFF59E0B);
    Color text = const Color(0xFF92400E);
    IconData icon = Icons.warning_amber_rounded;

    if (reminder.urgency == 'expired') {
      bg = const Color(0xFFFEE2E2);
      border = const Color(0xFFEF4444);
      text = const Color(0xFF991B1B);
      icon = Icons.error_outline_rounded;
    } else if (reminder.urgency == 'critical') {
      bg = const Color(0xFFFFEDD5);
      border = const Color(0xFFF97316);
      text = const Color(0xFF9A3412);
      icon = Icons.timer_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reminder.message,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: text.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: text,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Renew ₹99/mo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => state.dismissReminderAlert(),
                      style: TextButton.styleFrom(
                        foregroundColor: text,
                        minimumSize: const Size(40, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Dismiss', style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
