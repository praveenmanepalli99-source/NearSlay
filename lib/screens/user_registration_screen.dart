import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../state/nearfix_state.dart';
import '../models/colony_model.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_helper.dart';
import '../widgets/colony_picker_modal.dart';

class UserRegistrationScreen extends StatefulWidget {
  final String? prefilledPhone;
  final String? prefilledName;
  final String? prefilledAvatar;

  const UserRegistrationScreen({
    super.key,
    this.prefilledPhone,
    this.prefilledName,
    this.prefilledAvatar,
  });

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _flatController = TextEditingController();
  final TextEditingController _colonyController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isAutoLocating = false;
  String _selectedAvatar = AvatarHelper.defaultAvatar;

  final List<String> _sampleAvatars = AvatarHelper.sampleAvatars;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<NearFixState>(context, listen: false);

    if (widget.prefilledAvatar != null && widget.prefilledAvatar!.isNotEmpty) {
      _selectedAvatar = widget.prefilledAvatar!;
    }

    // Colony and City start empty for user entry

    if (widget.prefilledName != null && widget.prefilledName!.isNotEmpty) {
      _nameController.text = widget.prefilledName!;
    }

    final phone = widget.prefilledPhone ?? (state.currentUser?.phone ?? '');
    _phoneController.text = phone.replaceAll('+91', '').trim();

    // Check if user already exists with this phone number and restore details
    final account = state.checkExistingAccount(phone);
    if (account['exists'] == true && account['role'] == AppRole.resident) {
      final res = account['resident'];
      _nameController.text = res.name;
      _flatController.text = res.flatAddress;
      _colonyController.text = res.colonyName;
      _cityController.text = res.city;
    } else if (state.currentUser != null) {
      _nameController.text = state.currentUser!.name;
      _flatController.text = state.currentUser!.flatAddress;
      _colonyController.text = state.currentUser!.colonyName;
      _cityController.text = state.currentUser!.city;
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
    _flatController.dispose();
    _colonyController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
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

  void _submit() async {
    final name = _nameController.text.trim();
    final flat = _flatController.text.trim();
    final colonyName = _colonyController.text.trim();
    final state = Provider.of<NearFixState>(context, listen: false);
    final cityName = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : (state.currentColony.city.isNotEmpty ? state.currentColony.city : 'Current Location');
    final phone = _phoneController.text.trim();

    if (name.isEmpty || flat.isEmpty || colonyName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields (Name, Colony, House Address & Phone).'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final formattedPhone = phone.startsWith('+91') ? phone : '+91 $phone';

    final colony = ColonyModel(
      id: 'colony_${colonyName.hashCode}',
      name: colonyName,
      landmark: flat,
      city: cityName,
      pincode: '',
      latitude: state.currentColony.latitude,
      longitude: state.currentColony.longitude,
      activeProvidersCount: 0,
    );

    await state.registerResident(
      name: name,
      colony: colony,
      flatAddress: flat,
      phone: formattedPhone,
      avatarUrl: _selectedAvatar,
    );

    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome $name! Registered in $colonyName, $cityName.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User / Resident Registration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Info Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.home_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Register as a colony resident to find local plumbers, electricians & mechanics.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryDark,
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
              'Profile Photo (Optional)',
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

            // Field 1: Full Name
            const Text(
              '1. Full Name',
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
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),

            // Field 2: Colony / Area (Auto-filled via GPS with 1-tap button)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '2. Colony / Area Name (Auto-Filled)',
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

            // Field 3: City
            const Text(
              '3. City',
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

            // Field 4: Flat / House Address
            const Text(
              '4. House / Flat Number & Street Address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _flatController,
              decoration: const InputDecoration(
                hintText: 'e.g. Flat 302, Palm Heights',
                prefixIcon: Icon(Icons.apartment_rounded, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),

            // Field 5: Mobile Number
            const Text(
              '5. Mobile Number',
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
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save & Continue to NearSlay',
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
