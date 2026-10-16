import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/nearfix_state.dart';
import '../models/service_category.dart';
import '../theme/app_colors.dart';
import '../widgets/colony_picker_modal.dart';
import '../widgets/category_chip.dart';
import '../widgets/provider_card.dart';
import '../widgets/gemini_assistant_sheet.dart';
import '../widgets/avatar_helper.dart';
import 'my_profile_screen.dart';
import 'provider_registration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Proactively request location permission on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = Provider.of<NearFixState>(context, listen: false);
        state.ensureLocationPermissionPrompt();
      }
    });
  }

  void _handleSwitchToProvider(BuildContext context, NearFixState state) {
    final success = state.switchToRole(AppRole.provider);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched to Service Provider Mode!'),
          backgroundColor: AppColors.secondary,
          duration: Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<NearFixState>(context);
    final providers = state.filteredProviders;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: GestureDetector(
          onTap: () => ColonyPickerModal.show(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            state.currentColony.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    Text(
                      state.currentColony.city.isNotEmpty && state.currentColony.city != 'Current Location'
                          ? '${state.currentColony.city} • Local Services'
                          : 'Tap to set location',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.handyman_outlined, color: AppColors.secondary, size: 20),
            tooltip: 'Switch to Provider Mode',
            onPressed: () => _handleSwitchToProvider(context, state),
          ),
          IconButton(
            icon: state.isCloudSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.sync_rounded, color: AppColors.primary, size: 20),
            tooltip: 'Sync Cloud Providers',
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
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
                    SnackBar(
                      content: Text(
                          'Cloud Synced! ${state.filteredProviders.length} providers loaded.'),
                      duration: const Duration(seconds: 2),
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
              margin: const EdgeInsets.only(left: 6, right: 14),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: AvatarHelper.getImageProvider(state.currentUser?.avatarUrl),
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
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // Switch to Provider Mode Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: InkWell(
                  onTap: () => _handleSwitchToProvider(context, state),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Switch to Service Provider Mode',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondaryDark,
                                ),
                              ),
                              Text(
                                state.hasRegisteredProviderProfile
                                    ? 'Tap to switch directly to Provider Mode'
                                    : 'Register as Plumber, Electrician or Mechanic',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.secondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Search Bar with Gemini AI Trigger
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => state.setSearchQuery(val),
                        decoration: InputDecoration(
                          hintText: 'Search plumber, electrician...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          suffixIcon: state.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => state.setSearchQuery(''),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Gemini AI Smart Problem Diagnostic Button
                    InkWell(
                      onTap: () => GeminiAssistantSheet.show(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4285F4), Color(0xFF9B72CF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4285F4).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Service Categories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),

            // Horizontal Category List
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: ServiceCategory.defaultCategories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = ServiceCategory.defaultCategories[index];
                    final isSelected = state.selectedCategory == category.type;

                    return CategoryChip(
                      category: category,
                      isSelected: isSelected,
                      onTap: () => state.selectCategory(category.type),
                    );
                  },
                ),
              ),
            ),

            // Filter bar (Available Now toggle & Count)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: state.filterAvailableOnly
                                  ? Colors.white
                                  : AppColors.availableGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Available Now',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: state.filterAvailableOnly
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      selected: state.filterAvailableOnly,
                      onSelected: (selected) =>
                          state.toggleFilterAvailableOnly(),
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.availableGreen,
                      checkmarkColor: Colors.white,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: state.filterAvailableOnly
                              ? AppColors.availableGreen
                              : AppColors.cardBorder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Location Radius Filter Chip (5km primary, 10km auto-fallback, or Exact Colony)
                    ActionChip(
                      avatar: Icon(
                        state.locationScope == LocationFilterScope.exactColony
                            ? Icons.location_on_rounded
                            : (state.isRadiusExpandedTo10Km
                                ? Icons.radar_rounded
                                : Icons.near_me_rounded),
                        size: 13,
                        color: state.locationScope == LocationFilterScope.exactColony
                            ? AppColors.primaryDark
                            : (state.isRadiusExpandedTo10Km
                                ? Colors.amber.shade900
                                : AppColors.primary),
                      ),
                      label: Text(
                        state.locationScope == LocationFilterScope.exactColony
                            ? 'Exact Colony'
                            : (state.isRadiusExpandedTo10Km
                                ? '${state.activeRadiusKm}km Range'
                                : '5km Range'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: state.locationScope == LocationFilterScope.exactColony
                              ? AppColors.primaryDark
                              : (state.isRadiusExpandedTo10Km
                                  ? Colors.amber.shade900
                                  : AppColors.primaryDark),
                        ),
                      ),
                      backgroundColor: state.locationScope == LocationFilterScope.exactColony
                          ? AppColors.primaryLight
                          : (state.isRadiusExpandedTo10Km
                              ? Colors.amber.shade50
                              : AppColors.primaryLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: state.locationScope == LocationFilterScope.exactColony
                              ? AppColors.primary
                              : (state.isRadiusExpandedTo10Km
                                  ? Colors.amber.shade400
                                  : AppColors.primary),
                        ),
                      ),
                      onPressed: () {
                        if (state.locationScope == LocationFilterScope.nearbyCity) {
                          state.setLocationScope(LocationFilterScope.exactColony);
                        } else {
                          state.setLocationScope(LocationFilterScope.nearbyCity);
                        }
                      },
                    ),

                    const Spacer(),
                    Text(
                      '${providers.length} technicians',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Range Expansion Notice Banner when expanded beyond 5km
            if (state.locationScope == LocationFilterScope.nearbyCity &&
                state.isRadiusExpandedTo10Km &&
                providers.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.activeRadiusKm > 10
                              ? '0 technicians found within 10 km. Showing technicians across ${state.currentColony.city} (${state.activeRadiusKm} km range).'
                              : '0 technicians found within 5 km. Showing technicians within 10 km range of ${state.currentColony.name}.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Provider Cards List or Empty State
            if (providers.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No technicians in ${state.currentColony.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Currently searching within ${state.activeRadiusKm}km of ${state.currentColony.name}, ${state.currentColony.city}.\nPick another colony or sync with cloud.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => ColonyPickerModal.show(context),
                          icon: const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                          label: const Text('Change Colony / Area Location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            state.setSearchQuery('');
                            state.selectCategory(ServiceType.all);
                            if (state.filterAvailableOnly) state.toggleFilterAvailableOnly();
                            state.syncWithCloud(showIndicator: true);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
                          label: const Text('Reset Filters & Refresh', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final prov = providers[index];
                      return ProviderCard(
                        provider: prov,
                        margin: const EdgeInsets.only(bottom: 12),
                      );
                    },
                    childCount: providers.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: 30),
            ),
          ],
        ),
      ),
    );
  }
}
