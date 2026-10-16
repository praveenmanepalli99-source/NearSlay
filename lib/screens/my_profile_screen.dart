import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/nearfix_state.dart';
import '../models/colony_model.dart';
import '../models/service_category.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_helper.dart';
import '../widgets/colony_picker_modal.dart';
import '../services/app_info_service.dart';
import 'provider_registration_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _colonyController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isAutoLocating = false;
  bool _isProcessing = false;
  String _selectedAvatar = AvatarHelper.defaultAvatar;
  ServiceCategory _selectedCategory = ServiceCategory.defaultCategories[1];
  String _appVersionDisplay = 'App v1.0.17';

  @override
  void initState() {
    super.initState();
    _fetchAppVersion();
    final state = Provider.of<NearFixState>(context, listen: false);

    if (state.activeRole == AppRole.provider && state.currentProvider != null) {
      final p = state.currentProvider!;
      _nameController.text = p.name;
      _selectedAvatar = p.avatarUrl.isNotEmpty ? p.avatarUrl : _selectedAvatar;
      _rateController.text = p.hourlyRate.toString();
      _colonyController.text = p.colonyName;
      _cityController.text = p.city;
      _phoneController.text = p.realPhone.replaceAll('+91', '').trim();
      _bioController.text = p.bio;
      _selectedCategory = ServiceCategory.defaultCategories.firstWhere(
        (c) => c.type == p.category,
        orElse: () => ServiceCategory.defaultCategories[1],
      );
    } else if (state.currentUser != null) {
      final u = state.currentUser!;
      _nameController.text = u.name;
      _selectedAvatar = u.avatarUrl.isNotEmpty ? u.avatarUrl : _selectedAvatar;
      _colonyController.text = u.colonyName;
      _cityController.text = u.city;
      _addressController.text = u.flatAddress;
      _phoneController.text = u.phone.replaceAll('+91', '').trim();
    } else {
      _phoneController.text = state.verifiedPhone.replaceAll('+91', '').trim();
    }
  }

  Future<void> _fetchAppVersion() async {
    try {
      final v = await AppInfoService.getFullDisplayVersion();
      if (mounted) {
        setState(() {
          _appVersionDisplay = v;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colonyController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _rateController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _selectedAvatar = base64String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Gallery Option
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 22),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: const Text('Pick any photo stored on your device', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              const Divider(height: 12),

              // Camera Option
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.amber.shade800, size: 22),
                ),
                title: const Text('Take a Photo (Camera)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: const Text('Click a new portrait now', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _autoDetectGps() async {
    setState(() => _isAutoLocating = true);
    final state = Provider.of<NearFixState>(context, listen: false);
    final success = await state.detectLiveGpsLocation(silent: false);

    setState(() {
      _isAutoLocating = false;
      if (success) {
        _colonyController.text = state.currentColony.name;
        _cityController.text = state.currentColony.city;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '📍 Auto-filled Current GPS Location: ${state.currentColony.name}, ${state.currentColony.city}'
              : 'Could not access GPS. Please check location permissions or search/type manually.'),
          backgroundColor: success ? AppColors.primary : AppColors.secondary,
        ),
      );
    }
  }

  void _saveProfile() {
    final name = _nameController.text.trim();
    final colonyName = _colonyController.text.trim();
    final state = Provider.of<NearFixState>(context, listen: false);
    final cityName = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : (state.currentColony.city.isNotEmpty ? state.currentColony.city : 'Current Location');
    final phone = _phoneController.text.trim();

    if (name.isEmpty || colonyName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final formattedPhone = phone.startsWith('+91') ? phone : '+91 $phone';

    final colony = ColonyModel(
      id: 'colony_${colonyName.hashCode}',
      name: colonyName,
      landmark: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : 'Area in $cityName',
      city: cityName,
      pincode: '',
      latitude: state.currentColony.latitude,
      longitude: state.currentColony.longitude,
      activeProvidersCount: 1,
    );

    if (state.activeRole == AppRole.provider) {
      final hourlyRate = int.tryParse(_rateController.text.trim()) ?? 250;
      state.updateProviderProfile(
        name: name,
        avatarUrl: _selectedAvatar,
        category: _selectedCategory.type,
        categoryTitle: _selectedCategory.title,
        hourlyRate: hourlyRate,
        colony: colony,
        phone: formattedPhone,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : 'Local technician in ${colony.name}.',
      );
    } else {
      state.updateResidentProfile(
        name: name,
        avatarUrl: _selectedAvatar,
        colony: colony,
        flatAddress: _addressController.text.trim(),
        phone: formattedPhone,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated and saved to cloud successfully!'),
        backgroundColor: AppColors.primary,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _showLogoutDialog() async {
    final state = Provider.of<NearFixState>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.errorRed, size: 22),
            SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out from NearSlay?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      state.logout();
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final state = Provider.of<NearFixState>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 24),
            SizedBox(width: 10),
            Text(
              'Delete Account?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.errorRed),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your NearSlay account?\n\nThis will remove your profile, registration, and phone number from both your device and the Cloud Database permanently. This action cannot be undone.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Account', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      await state.deleteCurrentAccount();
      if (mounted) {
        state.logout();
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted permanently from NearSlay.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text(
              'Privacy & Data Usage',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NearSlay Data & Privacy Disclosure',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Location Access: Foreground GPS is collected only when you tap "Auto-Fill GPS" to detect your colony/city and calculate 5km/10km proximity to nearby technicians. Background location is never accessed.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
                SizedBox(height: 8),
                Text(
                  '2. Contact Information: Your mobile number and name are used solely for account authentication and connecting you with local service providers.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
                SizedBox(height: 8),
                Text(
                  '3. Account Deletion: You can permanently erase all your account data at any time from this profile screen.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
                SizedBox(height: 8),
                Text(
                  '4. Support & Privacy: For questions, contact nearfix99@gmail.com.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }



  void _showSupportDialog() {
    final state = Provider.of<NearFixState>(context, listen: false);
    final phone = state.verifiedPhone.isNotEmpty
        ? state.verifiedPhone
        : (state.currentUser?.phone ?? state.currentProvider?.realPhone ?? '');
    final name = state.currentUser?.name ?? state.currentProvider?.name ?? 'NearSlay User';

    final TextEditingController emailController =
        TextEditingController(text: 'nearfix99@gmail.com');
    final TextEditingController nameController = TextEditingController(text: name);
    final TextEditingController phoneController = TextEditingController(text: phone);
    final TextEditingController messageController = TextEditingController();

    String selectedCategory = 'Technical Glitch / App Issue';
    final List<String> issueCategories = [
      'Technical Glitch / App Issue',
      'Account / Login Problem',
      'Service Provider Inquiry',
      'Location / GPS Issue',
      'New Category / Feature Request',
      'Other Feedback',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 26),
              SizedBox(width: 10),
              Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Official Support Email (Not Editable)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      prefixIcon: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                        tooltip: 'Copy Support Email',
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: 'nearfix99@gmail.com'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Support email copied to clipboard: nearfix99@gmail.com'),
                              backgroundColor: AppColors.primary,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13.5),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Registered User Contact',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          readOnly: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          readOnly: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Issue Category',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: issueCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Describe the Issue or Feedback',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Please describe the problem you encountered in detail...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final desc = messageController.text.trim();
                final userPhone = phoneController.text.trim();
                final userName = nameController.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);

                final subject = Uri.encodeComponent('NearSlay Support: $selectedCategory');
                final body = Uri.encodeComponent(
                  'User Name: $userName\n'
                  'Registered Phone: $userPhone\n'
                  'Issue Category: $selectedCategory\n\n'
                  'Description:\n${desc.isNotEmpty ? desc : 'No additional details provided.'}\n\n'
                  '-- Sent from NearSlay Mobile App --',
                );

                final mailtoUri = Uri.parse('mailto:nearfix99@gmail.com?subject=$subject&body=$body');

                try {
                  final launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
                  if (!launched) {
                    await launchUrl(mailtoUri);
                  }
                } catch (e) {
                  Clipboard.setData(const ClipboardData(text: 'nearfix99@gmail.com'));
                }

                if (mounted) {
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Thank you! Mail app opened to contact nearfix99@gmail.com'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Email', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<NearFixState>(context);
    final isProvider = state.activeRole == AppRole.provider;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isProvider ? 'Technician Profile' : 'Resident Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.primary),
            tooltip: 'Save Profile',
            onPressed: _isProcessing ? null : _saveProfile,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Deleting account permanently...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Picker Section
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showAvatarOptions,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: AppColors.primaryLight,
                                backgroundImage: AvatarHelper.getImageProvider(_selectedAvatar),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Action button to open Gallery directly
                        OutlinedButton.icon(
                          onPressed: _showAvatarOptions,
                          icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppColors.primary),
                          label: const Text(
                            'Change Photo / Pick from Gallery',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Sample Avatars Horizontal Strip
                        const Text(
                          'Or select preset avatar:',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            itemCount: AvatarHelper.sampleAvatars.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final av = AvatarHelper.sampleAvatars[index];
                              final isPicked = _selectedAvatar == av;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedAvatar = av),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isPicked ? AppColors.primary : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(av),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Field 1: Full Name
                  const Text(
                    'Full Name',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your name',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Provider specific: Category & Hourly Charge
                  if (isProvider) ...[
                    const Text(
                      'Work Trade / Category',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ServiceCategory>(
                          isExpanded: true,
                          value: _selectedCategory,
                          items: ServiceCategory.defaultCategories
                              .where((c) => c.type != ServiceType.all)
                              .map((cat) {
                            return DropdownMenuItem<ServiceCategory>(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(cat.icon, size: 18, color: cat.color),
                                  const SizedBox(width: 10),
                                  Text(cat.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Base Service Starting Price (₹)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: 'Starts from ₹ ',
                        hintText: 'e.g. 300',
                        prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Colony / Area with Live GPS Auto-Fill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Colony / Area Name',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await ColonyPickerModal.show(context, returnOnly: true);
                              if (picked != null) {
                                setState(() {
                                  _colonyController.text = picked.name;
                                  _cityController.text = picked.city;
                                });
                              }
                            },
                            icon: const Icon(Icons.search_rounded, size: 14, color: AppColors.primary),
                            label: const Text(
                              'Search Location',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: _isAutoLocating ? null : _autoDetectGps,
                            icon: _isAutoLocating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 14, color: AppColors.primary),
                            label: const Text(
                              'GPS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _colonyController,
                    decoration: InputDecoration(
                      hintText: 'Enter Colony / Area Name',
                      prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                        tooltip: 'Search & Pick Location',
                        onPressed: () async {
                          final picked = await ColonyPickerModal.show(context, returnOnly: true);
                          if (picked != null) {
                            setState(() {
                              _colonyController.text = picked.name;
                              _cityController.text = picked.city;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // City
                  const Text(
                    'City / Region',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      hintText: 'Enter City Name',
                      prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resident Address
                  if (!isProvider) ...[
                    const Text(
                      'House / Flat Number & Street Address',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Flat 302, Palm Heights',
                        prefixIcon: Icon(Icons.apartment_rounded, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Phone Number
                  const Text(
                    'Mobile Number',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      prefixText: '+91 ',
                      counterText: '',
                      hintText: '98450 XXXXX',
                      prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Provider Bio
                  if (isProvider) ...[
                    const Text(
                      'Short Bio / Experience',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _bioController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 5+ years experience in pipe leak repairs...',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 20),

                  // Save Profile Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isProvider ? AppColors.secondary : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Profile Changes',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ================= ACCOUNT ACTIONS SECTION =================
                  const Text(
                    'Account Actions',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  // 0. Mode Switcher Action Card (Switch to Resident / Provider)
                  Container(
                    decoration: BoxDecoration(
                      color: isProvider ? AppColors.primaryLight : AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: (isProvider ? AppColors.primary : AppColors.secondary).withOpacity(0.4)),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isProvider ? AppColors.primary : AppColors.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isProvider ? Icons.home_rounded : Icons.handyman_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        isProvider ? 'Switch to Resident Mode' : 'Switch to Provider Mode',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      subtitle: Text(
                        isProvider
                            ? 'Browse & book local repair technicians for your home'
                            : 'Offer your trade services & receive colony repair jobs',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.swap_horiz_rounded, color: AppColors.textPrimary),
                      onTap: () {
                        if (isProvider) {
                          state.switchToRole(AppRole.resident);
                          Navigator.popUntil(context, (route) => route.isFirst);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Switched to Resident Mode! You can now browse nearby technicians.'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        } else {
                          final success = state.switchToRole(AppRole.provider);
                          if (success) {
                            Navigator.popUntil(context, (route) => route.isFirst);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Switched to Service Provider Mode!'),
                                backgroundColor: AppColors.secondary,
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProviderRegistrationScreen(
                                  prefilledPhone: state.verifiedPhone,
                                  prefilledName: state.currentUser?.name,
                                  prefilledAvatar: state.currentUser?.avatarUrl,
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),



                  // 1. Privacy Policy & Data Safety Button (Google Play Requirement)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.privacy_tip_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: const Text('Privacy Policy & Data Safety', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Review permissions and data collection terms', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      onTap: _showPrivacyPolicyDialog,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Help & Support / Report Issue Tile
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text(
                        'Report an issue or write to nearfix99@gmail.com',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      onTap: _showSupportDialog,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Log Out Button (Moved to My Profile Page)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, color: AppColors.textPrimary, size: 20),
                      ),
                      title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Sign out from this phone session', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      onTap: _showLogoutDialog,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Self Account Delete Button (Requirement 4)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed, size: 20),
                      ),
                      title: const Text(
                        'Delete Account Permanently',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.errorRed),
                      ),
                      subtitle: const Text(
                        'Erase your profile & registrations from NearSlay',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.errorRed),
                      onTap: _showDeleteAccountDialog,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. App Version Footer
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _appVersionDisplay,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
