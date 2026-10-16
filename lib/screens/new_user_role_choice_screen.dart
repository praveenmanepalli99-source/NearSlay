import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'user_registration_screen.dart';
import 'provider_registration_screen.dart';

class NewUserRoleChoiceScreen extends StatelessWidget {
  final String phoneNumber;
  final String? googleName;
  final String? googleAvatar;

  const NewUserRoleChoiceScreen({
    super.key,
    required this.phoneNumber,
    this.googleName,
    this.googleAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Choose Account Type'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Title
              Text(
                googleName != null && googleName!.isNotEmpty
                    ? 'Welcome, $googleName!'
                    : 'Welcome to NearSlay!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Signed in with $phoneNumber. Choose how you want to use NearSlay:',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Option 1: Resident / User Registration
              _buildChoiceCard(
                context: context,
                icon: Icons.home_repair_service_rounded,
                iconBg: AppColors.primaryLight,
                iconColor: AppColors.primary,
                title: 'Colony Resident / User',
                subtitle:
                    'Find and contact local plumbers, electricians, mechanics & repair technicians in your neighborhood.',
                badgeText: 'LOOKING FOR REPAIRS',
                buttonLabel: 'Register as Resident →',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserRegistrationScreen(
                        prefilledPhone: phoneNumber,
                        prefilledName: googleName,
                        prefilledAvatar: googleAvatar,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // Option 2: Service Provider Registration
              _buildChoiceCard(
                context: context,
                icon: Icons.handyman_rounded,
                iconBg: AppColors.secondaryLight,
                iconColor: AppColors.secondary,
                title: 'Service Provider / Technician',
                subtitle:
                    'List your repair trade, set your starting price (Starts from ₹...), and receive direct calls from colony residents.',
                badgeText: 'OFFERING SERVICES',
                buttonLabel: 'Register as Service Provider →',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProviderRegistrationScreen(
                        prefilledPhone: phoneNumber,
                        prefilledName: googleName,
                        prefilledAvatar: googleAvatar,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: iconColor.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: iconColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
