import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../state/nearfix_state.dart';
import '../models/colony_model.dart';
import '../models/service_category.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_helper.dart';
import '../widgets/colony_picker_modal.dart';

class ProviderRegistrationScreen extends StatefulWidget {
  final String? prefilledPhone;
  final String? prefilledName;
  final String? prefilledAvatar;

  const ProviderRegistrationScreen({
    super.key,
    this.prefilledPhone,
    this.prefilledName,
    this.prefilledAvatar,
  });

  @override
  State<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends State<ProviderRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _colonyController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isAutoLocating = false;

  String _selectedAvatar =
      'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200';
  ServiceCategory _selectedCategory =
      ServiceCategory.defaultCategories[1]; // Plumber

  final List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=200',
    'https://images.unsplash.com/photo-1566492031773-4f4e44671857?w=200',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
  ];

  @override
  void initState() {
    super.initState();
    final state = Provider.of<NearFixState>(context, listen: false);

    // Colony and City start empty for provider entry

    if (widget.prefilledName != null && widget.prefilledName!.isNotEmpty) {
      _nameController.text = widget.prefilledName!;
    }
    if (widget.prefilledAvatar != null && widget.prefilledAvatar!.isNotEmpty) {
      _selectedAvatar = widget.prefilledAvatar!;
    }

    final phone = widget.prefilledPhone ?? (state.currentProvider?.realPhone ?? '');
    _phoneController.text = phone.replaceAll('+91', '').trim();

    // Check if provider already exists and restore details
    final account = state.checkExistingAccount(phone);
    if (account['exists'] == true && account['role'] == AppRole.provider) {
      final p = account['provider'];
      _nameController.text = p.name;
      _rateController.text = p.hourlyRate > 0 ? p.hourlyRate.toString() : '';
      _colonyController.text = p.colonyName;
      _cityController.text = p.city;
      _bioController.text = p.bio;
      _selectedAvatar = p.avatarUrl;
      _selectedCategory = ServiceCategory.defaultCategories.firstWhere(
        (c) => c.type == p.category,
        orElse: () => ServiceCategory.defaultCategories[1],
      );
    } else if (state.currentProvider != null) {
      final p = state.currentProvider!;
      _nameController.text = p.name;
      _rateController.text = p.hourlyRate > 0 ? p.hourlyRate.toString() : '';
      _colonyController.text = p.colonyName;
      _cityController.text = p.city;
      _bioController.text = p.bio;
      _selectedAvatar = p.avatarUrl;
      _selectedCategory = ServiceCategory.defaultCategories.firstWhere(
        (c) => c.type == p.category,
        orElse: () => ServiceCategory.defaultCategories[1],
      );
    }

    // Auto-fetch live GPS location on startup if not already restored from an existing account
    if (_colonyController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFetchGpsOnStartup();
      });
    }
  }

  Future<void> _autoFetchGpsOnStartup() async {
    final state = Provider.of<NearFixState>(context, listen: false);
    final success = await state.detectLiveGpsLocation(silent: true);
    if (mounted && success && _colonyController.text.isEmpty) {
      setState(() {
        _colonyController.text = state.currentColony.name;
        _cityController.text = state.currentColony.city;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    _colonyController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final rateStr = _rateController.text.trim();
    final colonyName = _colonyController.text.trim();
    final state = Provider.of<NearFixState>(context, listen: false);
    final cityName = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : (state.currentColony.city.isNotEmpty ? state.currentColony.city : 'Current Location');
    final phone = _phoneController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty || rateStr.isEmpty || colonyName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields (Name, Trade, Rate, Colony & Phone).'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final hourlyRate = int.tryParse(rateStr) ?? 250;
    final formattedPhone = phone.startsWith('+91') ? phone : '+91 $phone';

    final colony = ColonyModel(
      id: 'colony_${colonyName.hashCode}',
      name: colonyName,
      landmark: 'Colony Area',
      city: cityName,
      pincode: '560001',
      latitude: state.currentColony.latitude,
      longitude: state.currentColony.longitude,
      activeProvidersCount: 1,
    );

    final isEditing = state.currentProvider != null &&
        state.currentProvider!.realPhone.contains(_phoneController.text.trim());

    if (isEditing) {
      await state.updateProviderProfile(
        name: name,
        avatarUrl: _selectedAvatar,
        category: _selectedCategory.type,
        categoryTitle: _selectedCategory.title,
        hourlyRate: hourlyRate,
        colony: colony,
        phone: formattedPhone,
        bio: bio.isNotEmpty ? bio : 'Local technician available for colony repair.',
      );
    } else {
      await state.registerServiceProvider(
        name: name,
        avatarUrl: _selectedAvatar,
        category: _selectedCategory.type,
        categoryTitle: _selectedCategory.title,
        hourlyRate: hourlyRate,
        colony: colony,
        phone: formattedPhone,
        bio: bio.isNotEmpty ? bio : 'Local technician available for colony repair.',
      );
    }

    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Welcome $name! Registered in $colonyName, $cityName with starting price ₹$hourlyRate.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ServiceCategory.defaultCategories
        .where((c) => c.type != ServiceType.all)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Provider Registration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Info Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.handyman_rounded, color: AppColors.secondary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Set your charge or base rate. Customers will contact you directly via NearSlay.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Profile Picture Selection
            const Text(
              '1. Choose Profile Photo / Avatar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 400,
                      maxHeight: 400,
                      imageQuality: 80,
                    );
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setState(() {
                        _selectedAvatar = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                      });
                    }
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: AvatarHelper.getImageProvider(_selectedAvatar),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_a_photo_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 400,
                        maxHeight: 400,
                        imageQuality: 80,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setState(() {
                          _selectedAvatar = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                        });
                      }
                    },
                    icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Pick from Gallery',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _sampleAvatars.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final avatar = _sampleAvatars[index];
                  final isPicked = _selectedAvatar == avatar;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAvatar = avatar;
                      });
                    },
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
                        radius: 22,
                        backgroundImage: NetworkImage(avatar),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Provider Name
            const Text(
              '2. Full Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person_rounded, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),

            // Work Category
            const Text(
              '3. Work Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
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
                  items: categories.map((cat) {
                    return DropdownMenuItem<ServiceCategory>(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(cat.icon, size: 18, color: cat.color),
                          const SizedBox(width: 10),
                          Text(
                            cat.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Starting Charge
            const Text(
              '4. Base Service Starting Price (₹)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _rateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: 'Starts from ₹ ',
                hintText: 'e.g. 250',
                prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),

            // Colony / Location (Auto-filled with 1-tap GPS)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '5. Colony / Service Area (Auto-Filled)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
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
              '6. City',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
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

            // Phone Number
            const Text(
              '7. Mobile Number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
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
                prefixIcon: Icon(Icons.phone_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),

            // Bio / Experience
            const Text(
              '8. Experience / Short Bio',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bioController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. 5+ years experience in pipe leak repairs and sanitary fittings...',
              ),
            ),
            // Free Trial Guarantee Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, color: Color(0xFF059669), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '90 Days Free Trial Included',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        Text(
                          'Start receiving colony resident calls immediately with zero upfront fees.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start 90-Day Free Trial & Register',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
