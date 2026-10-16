import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/colony_model.dart';
import '../services/location_service.dart';
import '../state/nearfix_state.dart';
import '../theme/app_colors.dart';

class ColonyPickerModal extends StatefulWidget {
  final bool returnOnly;

  const ColonyPickerModal({
    super.key,
    this.returnOnly = false,
  });

  /// Open modal and return the selected [ColonyModel] if any
  static Future<ColonyModel?> show(BuildContext context, {bool returnOnly = false}) {
    return showModalBottomSheet<ColonyModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ColonyPickerModal(returnOnly: returnOnly),
    );
  }

  @override
  State<ColonyPickerModal> createState() => _ColonyPickerModalState();
}

class _ColonyPickerModalState extends State<ColonyPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  String _searchFilter = '';
  bool _isSearchingOnline = false;
  List<ColonyModel> _onlineResults = [];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchFilter = val.trim();
    });

    _debounceTimer?.cancel();
    if (_searchFilter.length >= 2) {
      setState(() => _isSearchingOnline = true);
      _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
        final results = await LocationService.searchLocations(_searchFilter);
        if (mounted) {
          setState(() {
            _onlineResults = results;
            _isSearchingOnline = false;
          });
        }
      });
    } else {
      setState(() {
        _onlineResults = [];
        _isSearchingOnline = false;
      });
    }
  }

  void _selectLocation(ColonyModel colony) {
    final state = Provider.of<NearFixState>(context, listen: false);
    if (!widget.returnOnly) {
      state.setColony(colony);
    }
    Navigator.pop(context, colony);
  }

  void _showManualLocationDialog() {
    final colonyTextController = TextEditingController(text: _searchFilter);
    final cityTextController = TextEditingController();
    final landmarkTextController = TextEditingController();
    final pinTextController = TextEditingController();

    // If search text matches a known colony, prefill details
    final qLower = _searchFilter.toLowerCase().trim();
    for (final entry in LocationService.knownColonies.entries) {
      if (qLower == entry.key || qLower.contains(entry.key) || entry.key.contains(qLower)) {
        cityTextController.text = entry.value['city'] as String;
        landmarkTextController.text = entry.value['landmark'] as String;
        pinTextController.text = entry.value['pin'] as String;
        break;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.edit_location_alt_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Enter Location Manually',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: colonyTextController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Colony / Area / Society Name *',
                    hintText: 'e.g. KPHB Colony, Kukatpally, Banjara Hills',
                    prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: cityTextController,
                  decoration: const InputDecoration(
                    labelText: 'City / Town *',
                    hintText: 'e.g. Hyderabad, Palvancha, Kothagudem',
                    prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: landmarkTextController,
                  decoration: const InputDecoration(
                    labelText: 'Landmark / Street (Optional)',
                    hintText: 'e.g. Near Metro Station, Phase 1',
                    prefixIcon: Icon(Icons.map_rounded, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: pinTextController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pincode (Optional)',
                    hintText: 'e.g. 500072',
                    prefixIcon: Icon(Icons.pin_drop_rounded, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = colonyTextController.text.trim();
                      final city = cityTextController.text.trim();
                      final landmark = landmarkTextController.text.trim();
                      final pin = pinTextController.text.trim();

                      if (name.isEmpty || city.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter both Colony Name and City.'),
                            backgroundColor: AppColors.errorRed,
                          ),
                        );
                        return;
                      }

                      // Check known coordinates first
                      double lat = 0.0;
                      double lng = 0.0;
                      final nLower = name.toLowerCase().trim();
                      for (final entry in LocationService.knownColonies.entries) {
                        if (nLower == entry.key || nLower.contains(entry.key) || entry.key.contains(nLower)) {
                          lat = entry.value['lat'] as double;
                          lng = entry.value['lng'] as double;
                          break;
                        }
                      }

                      final customColony = ColonyModel(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        landmark: landmark.isNotEmpty ? landmark : '$name, $city',
                        city: city,
                        pincode: pin.isNotEmpty ? pin : '500072',
                        latitude: lat,
                        longitude: lng,
                        activeProvidersCount: 0,
                      );

                      Navigator.pop(ctx);
                      _selectLocation(customColony);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Confirm & Select Location'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<NearFixState>(context);

    // Filter local registered colonies
    final localColonies = state.colonies.where((c) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.city.toLowerCase().contains(q) ||
          c.landmark.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row: Title & GPS Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Search & Select Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (state.isGpsLocating)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await state.detectLiveGpsLocation();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? '📍 Live GPS detected: ${state.currentColony.name}, ${state.currentColony.city}'
                              : 'Could not access GPS. Please check location permissions.'),
                          backgroundColor: ok ? AppColors.primary : AppColors.errorRed,
                        ),
                      );
                      if (ok) {
                        _selectLocation(state.currentColony);
                      }
                    }
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 14),
                  label: const Text('Live GPS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Input Field
          TextField(
            controller: _searchController,
            autofocus: false,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Type any colony, locality, area or city...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSearchingOnline)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  if (_searchFilter.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Manual Entry Banner
          InkWell(
            onTap: _showManualLocationDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_location_alt_rounded, color: AppColors.primaryDark, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Can\'t find your place? Enter location manually',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primaryDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Direct "Use '[searchQuery]' as Custom Location" option if typing
          if (_searchFilter.isNotEmpty) ...[
            InkWell(
              onTap: () {
                final customColony = ColonyModel(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: _searchFilter,
                  landmark: 'Area in $_searchFilter',
                  city: 'India',
                  pincode: '500001',
                  latitude: 0.0,
                  longitude: 0.0,
                  activeProvidersCount: 0,
                );
                _selectLocation(customColony);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select "$_searchFilter"',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'Use this as your manual colony / location name',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            ),
          ],

          if (!widget.returnOnly) ...[
            // Location Scope Filter (Distance Radius Filter)
            Row(
              children: [
                const Text(
                  'Radius:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildScopeChip(
                          label: 'Nearby Radius (5km)',
                          isSelected: state.locationScope == LocationFilterScope.nearbyCity,
                          onTap: () => state.setLocationScope(LocationFilterScope.nearbyCity),
                        ),
                        const SizedBox(width: 6),
                        _buildScopeChip(
                          label: 'Exact Colony Only',
                          isSelected: state.locationScope == LocationFilterScope.exactColony,
                          onTap: () => state.setLocationScope(LocationFilterScope.exactColony),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          const Divider(height: 1, color: AppColors.cardBorder),

          // Search Results & Colonies List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // 1. Live Online OpenStreetMap search results
                if (_onlineResults.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 10, 4, 6),
                    child: Text(
                      'ONLINE SEARCH RESULTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  ...List.generate(_onlineResults.length, (idx) {
                    final res = _onlineResults[idx];
                    return _buildLocationTile(
                      colony: res,
                      isSelected: res.name.toLowerCase() == state.currentColony.name.toLowerCase(),
                      isOnlineResult: true,
                    );
                  }),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.cardBorder),
                ],

                // 2. Local / Saved Colonies
                if (localColonies.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                    child: Text(
                      _searchFilter.isEmpty ? 'COLONIES & AREAS' : 'SAVED LOCATIONS',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  ...List.generate(localColonies.length, (idx) {
                    final colony = localColonies[idx];
                    final isSelected = colony.id == state.currentColony.id ||
                        colony.name.toLowerCase() == state.currentColony.name.toLowerCase();
                    return _buildLocationTile(
                      colony: colony,
                      isSelected: isSelected,
                      isOnlineResult: false,
                    );
                  }),
                ],

                if (localColonies.isEmpty && _onlineResults.isEmpty && !_isSearchingOnline) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    child: Column(
                      children: [
                        const Icon(Icons.location_off_rounded, size: 42, color: AppColors.textMuted),
                        const SizedBox(height: 10),
                        Text(
                          'No exact matches found for "$_searchFilter"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'You can tap "Enter Location Manually" above to use any colony or city you want.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile({
    required ColonyModel colony,
    required bool isSelected,
    required bool isOnlineResult,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isOnlineResult ? Icons.travel_explore_rounded : Icons.location_on_rounded,
          color: isSelected ? AppColors.primary : (isOnlineResult ? AppColors.primaryDark : AppColors.textMuted),
          size: 19,
        ),
      ),
      title: Text(
        colony.name,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${colony.landmark} • ${colony.city} (${colony.pincode})',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 18,
            )
          : const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppColors.cardBorder,
            ),
      onTap: () => _selectLocation(colony),
    );
  }

  Widget _buildScopeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
