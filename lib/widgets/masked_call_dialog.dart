import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/provider_model.dart';
import '../models/service_category.dart';
import '../theme/app_colors.dart';

class MaskedCallDialog extends StatelessWidget {
  final ProviderModel provider;

  const MaskedCallDialog({super.key, required this.provider});

  static void show(BuildContext context, ProviderModel provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MaskedCallDialog(provider: provider),
    );
  }

  Future<void> _launchDialer(BuildContext context) async {
    final phoneToDial = provider.realPhone;
    final cleanedNumber = phoneToDial.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanedNumber');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dialing: $phoneToDial'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling $phoneToDial'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  String _getWhatsAppMessage() {
    switch (provider.category) {
      case ServiceType.catering:
        return 'Hello ${provider.name}, I found your catering profile on NearSlay in ${provider.colonyName}. I would like to inquire about event catering, party food orders, or meal packages. Are you available?';
      case ServiceType.djSound:
        return 'Hello ${provider.name}, I found your DJ & sound system service on NearSlay in ${provider.colonyName}. I would like to inquire about DJ setup, sound systems, and event audio bookings. Are you available?';
      case ServiceType.hotel:
        return 'Hello ${provider.name}, I found your hotel on NearSlay in ${provider.colonyName}. I would like to inquire about room availability, booking rates, and check-in options. Please share details.';
      case ServiceType.restaurant:
        return 'Hello ${provider.name}, I found your restaurant on NearSlay in ${provider.colonyName}. I would like to check your menu and inquire about placing a food order / table reservation.';
      case ServiceType.mechanic:
        return 'Hello ${provider.name}, I found your profile on NearSlay for mechanic service in ${provider.colonyName}. I need vehicle repair / breakdown assistance. Are you available?';
      case ServiceType.doctor:
        return 'Hello Dr. ${provider.name}, I found your profile on NearSlay in ${provider.colonyName}. I would like to inquire about consultation timings and appointment availability.';
      case ServiceType.decoration:
        return 'Hello ${provider.name}, I found your event decoration profile on NearSlay in ${provider.colonyName}. I would like to inquire about decoration packages and availability for an upcoming event.';
      case ServiceType.tentHouse:
        return 'Hello ${provider.name}, I found your tent house service on NearSlay in ${provider.colonyName}. I would like to inquire about tent, stage, sound, and event rental supplies.';
      default:
        return 'Hello ${provider.name}, I found your profile on NearSlay for ${provider.categoryTitle} service in ${provider.colonyName}. Are you available for doorstep service?';
    }
  }

  String _getSubtitleText() {
    switch (provider.category) {
      case ServiceType.catering:
        return 'Direct catering & party food order inquiry.';
      case ServiceType.djSound:
        return 'Direct DJ & event sound system booking inquiry.';
      case ServiceType.hotel:
        return 'Direct room booking & reservation inquiry.';
      case ServiceType.restaurant:
        return 'Direct food ordering & table reservation inquiry.';
      case ServiceType.mechanic:
        return 'Direct vehicle repair & breakdown assistance connection.';
      case ServiceType.doctor:
        return 'Direct doctor consultation & appointment inquiry.';
      case ServiceType.decoration:
      case ServiceType.tentHouse:
        return 'Direct event planning & equipment rental inquiry.';
      default:
        return 'Direct doorstep connection for your service request.';
    }
  }

  String _getPriceUnitText() {
    switch (provider.category) {
      case ServiceType.catering:
        return 'per plate / event';
      case ServiceType.djSound:
        return 'per event / day';
      case ServiceType.hotel:
        return 'per room / day';
      case ServiceType.restaurant:
        return 'approx / order';
      case ServiceType.doctor:
        return 'consultation';
      case ServiceType.decoration:
      case ServiceType.tentHouse:
        return 'starting pkg';
      default:
        return 'per 1 hr';
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final digits = provider.realPhone.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = digits.startsWith('91') ? digits : '91$digits';
    final messageText = _getWhatsAppMessage();
    final text = Uri.encodeComponent(messageText);
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed on this device.'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Shield Icon Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Connect with ${provider.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getSubtitleText(),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),

          // Provider Summary Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: Colors.white,
                        child: Image.network(
                          provider.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              provider.name.isNotEmpty ? provider.name[0] : 'P',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${provider.categoryTitle} • ${provider.colonyName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Starts from',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '₹${provider.hourlyRate}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (provider.bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1, right: 6),
                          child: Icon(Icons.handyman_rounded, size: 13, color: AppColors.secondary),
                        ),
                        Expanded(
                          child: Text(
                            provider.bio.trim(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Number Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_rounded, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Verified Contact Number',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  provider.realPhone,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Direct Phone Call & WhatsApp Inquiry',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action 1: Call Phone Dialer CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchDialer(context);
              },
              icon: const Icon(Icons.call_rounded, size: 18),
              label: Text('Call ${provider.name} (Direct Call)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action 2: WhatsApp Chat CTA
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchWhatsApp(context);
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF16A34A)),
              label: const Text(
                'Chat on WhatsApp',
                style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
