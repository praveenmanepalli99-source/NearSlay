import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nearfix/main.dart';
import 'package:nearfix/models/colony_model.dart';
import 'package:nearfix/models/service_category.dart';
import 'package:nearfix/services/gemini_service.dart';
import 'package:nearfix/services/location_service.dart';
import 'package:nearfix/services/session_service.dart';
import 'package:nearfix/services/sms_service.dart';
import 'package:nearfix/services/firebase_service.dart';
import 'package:nearfix/models/provider_model.dart';
import 'package:nearfix/models/payment_model.dart';
import 'package:nearfix/services/subscription_service.dart';
import 'package:nearfix/services/razorpay_service.dart';
import 'package:nearfix/screens/subscription_screen.dart';
import 'package:provider/provider.dart';
import 'package:nearfix/state/nearfix_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NearFix Real Data, Session Persistence & Location Tests', () {
    late NearFixState state;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = NearFixState();
    });

    test('1. Initial state starts clean with 0 dummy providers & unregistered role', () {
      expect(state.allProviders.isEmpty, true);
      expect(state.filteredProviders.isEmpty, true);
      expect(state.currentUser, isNull);
      expect(state.currentProvider, isNull);
      expect(state.isLoggedIn, false);
      expect(state.activeRole, AppRole.unregistered);
      expect(state.colonies.isNotEmpty, true);
    });

    test('2. Mobile OTP Request & Verification flow with Existing Account Recognition', () async {
      // 1. Register a provider with phone +91 98450 11223
      await state.registerServiceProvider(
        name: 'Rajesh Sharma',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colony: state.colonies[0],
        phone: '+91 98450 11223',
        bio: 'Plumber in colony',
      );

      // 2. Logout
      state.logout();
      expect(state.isLoggedIn, false);

      // 3. Login with same mobile number
      final otp = state.requestOtp('+91 98450 11223');
      final ok = state.verifyOtp(otp);

      expect(ok, true);
      expect(state.isLoggedIn, true);
      expect(state.activeRole, AppRole.provider);
      expect(state.currentProvider != null, true);
      expect(state.currentProvider!.name, 'Rajesh Sharma');
      expect(state.currentProvider!.hourlyRate, 300);
    });

    test('3. Resident User Registration saves real user profile and can log in with same phone', () async {
      final colony = state.colonies[0];
      await state.registerResident(
        name: 'John Resident',
        colony: colony,
        flatAddress: 'Flat 101, Palm Heights',
        phone: '+91 98765 43210',
      );

      expect(state.currentUser != null, true);
      expect(state.currentUser!.name, 'John Resident');
      expect(state.activeRole, AppRole.resident);

      // Logout and re-login
      state.logout();
      final otp = state.requestOtp('9876543210');
      
      // Random OTP must be rejected
      final bad = state.verifyOtp('999999');
      expect(bad, false);

      // Exact generated OTP succeeds
      final ok = state.verifyOtp(otp);

      expect(ok, true);
      expect(state.activeRole, AppRole.resident);
      expect(state.currentUser!.name, 'John Resident');
      expect(state.currentUser!.flatAddress, 'Flat 101, Palm Heights');
    });

    test('4. Location Matching ensures resident sees provider in same location', () {
      // Provider registers in Green Glen Layout
      state.registerServiceProvider(
        name: 'Rajesh Plumber',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colony: const ColonyModel(
          id: 'colony_1',
          name: 'Green Glen Layout',
          landmark: 'Bellandur',
          city: 'Bengaluru',
          pincode: '560103',
          latitude: 12.9298,
          longitude: 77.6749,
          activeProvidersCount: 1,
        ),
        phone: '+91 98450 99887',
        bio: 'Plumber',
      );

      // Resident sets location to Green Glen Layout
      state.setColony(const ColonyModel(
        id: 'colony_custom_99',
        name: 'Green Glen Layout',
        landmark: 'Near Ring Road',
        city: 'Bengaluru',
        pincode: '560103',
        latitude: 12.9298,
        longitude: 77.6749,
        activeProvidersCount: 0,
      ));

      // Provider is visible to resident!
      expect(state.filteredProviders.length, 1);
      expect(state.filteredProviders.first.name, 'Rajesh Plumber');
      expect(state.filteredProviders.first.hourlyRate, 300);
    });

    test('5. Location Filter Scope (Exact Colony vs Nearby in City)', () {
      final kukatpally = state.colonies.firstWhere((c) => c.name.toLowerCase().contains('kukatpally'));
      final banjaraHills = state.colonies.firstWhere((c) => c.name.toLowerCase().contains('banjara hills'));

      // Register a provider in Kukatpally, Hyderabad
      state.registerServiceProvider(
        name: 'Ramesh Plumber',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 250,
        colony: kukatpally,
        phone: '+91 98450 11111',
        bio: 'Plumber',
      );

      // Switch resident location to Banjara Hills (same city Hyderabad, ~8km)
      state.setColony(banjaraHills);

      // In "Nearby in City" mode, provider in Kukatpally is visible with distance
      state.setLocationScope(LocationFilterScope.nearbyCity);
      expect(state.filteredProviders.length, 1);

      // In "Exact Colony" mode, only exact Banjara Hills providers show (0)
      state.setLocationScope(LocationFilterScope.exactColony);
      expect(state.filteredProviders.length, 0);

      // Switch back to "Nearby in City"
      state.setLocationScope(LocationFilterScope.nearbyCity);
      expect(state.filteredProviders.length, 1);
    });

    test('6. LocationService distance calculation', () {
      final d = LocationService.calculateDistanceMeters(
        startLat: 12.9298,
        startLng: 77.6749,
        endLat: 12.9784,
        endLng: 77.6408,
      );
      expect(d > 1000, true);
    });

    test('7. Logout resets active session to unregistered', () {
      state.setRole(AppRole.resident);
      expect(state.isLoggedIn, true);

      state.logout();
      expect(state.isLoggedIn, false);
      expect(state.activeRole, AppRole.unregistered);
      expect(state.currentUser, isNull);
    });

    test('8. Gemini AI Colony Diagnostic Service categorizes problems accurately', () async {
      final plumbingDiagnosis =
          await GeminiService.diagnoseIssue('Kitchen tap leaking water from pipe');
      expect(plumbingDiagnosis.recommendedCategory, ServiceType.plumber);
      expect(plumbingDiagnosis.categoryTitle, 'Plumber');
    });

    test('9. Update profile details modifies state and persists', () {
      state.registerResident(
        name: 'Praveen',
        colony: state.colonies[0],
        flatAddress: 'Flat 101',
        phone: '+91 96408 02522',
      );

      state.updateResidentProfile(
        name: 'Praveen Kumar',
        avatarUrl: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200',
        colony: state.colonies[0],
        flatAddress: 'Rahul Gandhi Nagar, Palvancha',
        phone: '+91 96408 02522',
      );

      expect(state.currentUser!.name, 'Praveen Kumar');
      expect(state.currentUser!.flatAddress, 'Rahul Gandhi Nagar, Palvancha');
      expect(state.currentUser!.avatarUrl,
          'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200');
    });

    test('10. Admin dashboard user deletion removes provider and resident accounts', () async {
      state.registerServiceProvider(
        name: 'Electrician Suresh',
        avatarUrl: '',
        category: ServiceType.electrician,
        categoryTitle: 'Electrician',
        hourlyRate: 350,
        colony: state.colonies[0],
        phone: '9845011111',
        bio: 'Fast repair',
      );

      state.registerResident(
        name: 'Resident Anil',
        colony: state.colonies[0],
        flatAddress: 'House 55',
        phone: '9845022222',
      );

      expect(state.allProviders.length, 1);
      expect(state.allResidents.length, 1);

      final provId = state.allProviders[0].id;
      await state.deleteProviderByAdmin(provId);
      expect(state.allProviders.isEmpty, true);

      await state.deleteResidentByAdmin('9845022222');
      expect(state.allResidents.isEmpty, true);
    });

    test('11. 5km to 10km cascading range auto-expansion', () {
      // Register a technician 7 km away from KTPS center
      state.registerServiceProvider(
        name: 'Plumber 7km Away',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 200,
        colony: const ColonyModel(
          id: 'colony_far',
          name: 'Outer Area',
          landmark: '7km away',
          city: 'Palvancha',
          pincode: '507115',
          latitude: 17.6600, // ~6.88 km from KTPS (17.5980)
          longitude: 80.6970,
          activeProvidersCount: 1,
        ),
        phone: '9912345678',
        bio: '7km away technician',
      );

      // A Resident in KTPS (phone: 9848099999) views the feed
      final ktps = state.colonies.firstWhere((c) => c.id == 'colony_ktps');
      state.registerResident(
        name: 'Resident in KTPS',
        colony: ktps,
        flatAddress: 'Flat 1',
        phone: '9848099999',
      );

      // Filtered providers should automatically expand to 10km and find the technician!
      final providers = state.filteredProviders;
      expect(providers.length, 1);
      expect(state.isRadiusExpandedTo10Km, true);
      expect(state.activeRadiusKm, 10);
    });

    test('12. Self User Account Deletion removes BOTH provider and resident accounts and resets session', () async {
      // 1. Register as Resident
      await state.registerResident(
        name: 'Dual User',
        colony: state.colonies[0],
        flatAddress: 'Flat 99',
        phone: '+91 99999 88888',
      );

      // 2. Also register as Provider with same phone
      await state.registerServiceProvider(
        name: 'Dual User',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 350,
        colony: state.colonies[0],
        phone: '+91 99999 88888',
        bio: 'Plumbing services',
      );

      expect(state.isLoggedIn, true);
      expect(state.allResidents.length, 1);
      expect(state.allProviders.length, 1);

      // 3. Perform self deletion
      await state.deleteCurrentAccount();

      expect(state.isLoggedIn, false);
      expect(state.currentUser, isNull);
      expect(state.currentProvider, isNull);
      expect(state.allResidents.isEmpty, true);
      expect(state.allProviders.isEmpty, true);
      expect(state.activeRole, AppRole.unregistered);
    });

    test('13. Service Provider Availability & Busy State Contact status', () {
      state.registerServiceProvider(
        name: 'Electrician Ramesh',
        avatarUrl: '',
        category: ServiceType.electrician,
        categoryTitle: 'Electrician',
        hourlyRate: 300,
        colony: state.colonies[0],
        phone: '9848012345',
        bio: 'Local expert electrician',
      );

      expect(state.allProviders.first.isAvailable, true);

      // Toggle availability to Busy
      state.toggleMyAvailability();
      expect(state.allProviders.first.isAvailable, false);
      expect(state.currentProvider!.isAvailable, false);

      // Toggle back to Available
      state.toggleMyAvailability();
      expect(state.allProviders.first.isAvailable, true);
      expect(state.currentProvider!.isAvailable, true);
    });

    test('14. Bidirectional Role Switching between Resident and Provider Mode', () async {
      SharedPreferences.setMockInitialValues({});
      final state = NearFixState();
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Register as Resident first
      await state.registerResident(
        name: 'Praveen',
        colony: state.colonies[0],
        flatAddress: 'Flat 302, Green Glen',
        phone: '9988776655',
      );
      expect(state.activeRole, AppRole.resident);
      expect(state.hasRegisteredResidentProfile, true);
      expect(state.hasRegisteredProviderProfile, false);

      // Attempt switch to provider before registering provider profile -> returns false
      final switchedPre = state.switchToRole(AppRole.provider);
      expect(switchedPre, false);
      expect(state.activeRole, AppRole.resident);

      // 2. Register as Provider
      await state.registerServiceProvider(
        name: 'Praveen Manepalli',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 350,
        colony: state.colonies[0],
        phone: '9988776655',
        bio: 'Expert colony plumber',
      );
      expect(state.activeRole, AppRole.provider);
      expect(state.hasRegisteredProviderProfile, true);

      // 3. Switch back to Resident Mode
      final switchedToResident = state.switchToRole(AppRole.resident);
      expect(switchedToResident, true);
      expect(state.activeRole, AppRole.resident);
      expect(state.currentUser!.phone, '9988776655');

      // 4. Switch back to Provider Mode
      final switchedToProvider = state.switchToRole(AppRole.provider);
      expect(switchedToProvider, true);
      expect(state.activeRole, AppRole.provider);
      expect(state.currentProvider!.hourlyRate, 350);
    });

    test('15. Strict 10km Range Rule: Only technicians within 10km are displayed; otherwise empty', () async {
      SharedPreferences.setMockInitialValues({});
      final state = NearFixState();
      await Future.delayed(const Duration(milliseconds: 50));

      // Provider registers in Hyderabad (~300 km away from KTPS Palvancha)
      await state.registerServiceProvider(
        name: 'Ramesh Hyderabad Electrician',
        avatarUrl: '',
        category: ServiceType.electrician,
        categoryTitle: 'Electrician',
        hourlyRate: 500,
        colony: const ColonyModel(
          id: 'colony_hyd',
          name: 'Hitech City',
          landmark: 'Cyber Towers',
          city: 'Hyderabad',
          pincode: '500081',
          latitude: 17.4435,
          longitude: 78.3772,
          activeProvidersCount: 1,
        ),
        phone: '9876543210',
        bio: 'Hitech city master electrician',
      );

      // A Resident in KTPS Palvancha (phone: 9944332211) opens the app
      final ktps = state.colonies.firstWhere((c) => c.id == 'colony_ktps');
      await state.registerResident(
        name: 'Resident in KTPS',
        colony: ktps,
        flatAddress: 'Flat 1',
        phone: '9944332211',
      );

      // Strict Standard: If no technicians within 10km range, returns empty list []!
      final providers = state.filteredProviders;
      expect(providers.isEmpty, true);
      expect(state.activeRadiusKm, 10);

      // When resident switches colony to Hyderabad (within 10km of provider)
      final hydColony = state.colonies.firstWhere((c) => c.id == 'colony_hyd');
      state.setColony(hydColony);

      final hydProviders = state.filteredProviders;
      expect(hydProviders.isNotEmpty, true);
      expect(hydProviders.first.name, 'Ramesh Hyderabad Electrician');
    });

    test('16. Offline-first Pending Sync Queue & 5-minute Auto Sync resilience', () async {
      SharedPreferences.setMockInitialValues({});
      final state = NearFixState();
      await Future.delayed(const Duration(milliseconds: 50));

      // Register offline provider
      await state.registerServiceProvider(
        name: 'Offline Tech Test',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 400,
        colony: state.colonies[0],
        phone: '9112233445',
        bio: 'Offline plumber test',
      );

      // Provider is preserved in persistent session and pending queue
      final pendingProvs = await SessionService.getPendingProviders();
      expect(pendingProvs.any((p) => p.realPhone == '9112233445' || p.name == 'Offline Tech Test'), true);

      // Background sync retry triggers without error
      await state.syncWithCloud(showIndicator: false);
      expect(state.allProviders.any((p) => p.name == 'Offline Tech Test'), true);
    });

    test('17. Profile Name Synchronization across Resident and Provider accounts', () async {
      SharedPreferences.setMockInitialValues({});
      final state = NearFixState();
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Register Resident with initial name 'Original Name'
      await state.registerResident(
        name: 'Original Name',
        colony: state.colonies[0],
        flatAddress: 'Flat 101',
        phone: '9848011111',
      );

      // 2. Also register Provider with same phone
      await state.registerServiceProvider(
        name: 'Original Name',
        avatarUrl: '',
        category: ServiceType.electrician,
        categoryTitle: 'Electrician',
        hourlyRate: 200,
        colony: state.colonies[0],
        phone: '9848011111',
        bio: 'Electrician bio',
      );

      expect(state.currentUser!.name, 'Original Name');
      expect(state.currentProvider!.name, 'Original Name');

      // 3. User updates name to 'Updated Name' in Resident Profile
      state.updateResidentProfile(
        name: 'Updated Name',
        avatarUrl: '',
        colony: state.colonies[0],
        flatAddress: 'Flat 101',
        phone: '9848011111',
      );

      // Both profiles must reflect the new name 'Updated Name'
      expect(state.currentUser!.name, 'Updated Name');
      expect(state.currentProvider!.name, 'Updated Name');
      expect(state.allResidents.firstWhere((r) => r.phone == '9848011111').name, 'Updated Name');
      expect(state.allProviders.firstWhere((p) => p.realPhone == '9848011111').name, 'Updated Name');

      // 4. User updates name to 'Final Name' in Provider Profile
      await state.updateProviderProfile(
        name: 'Final Name',
        avatarUrl: '',
        category: ServiceType.electrician,
        categoryTitle: 'Electrician',
        hourlyRate: 250,
        colony: state.colonies[0],
        phone: '9848011111',
        bio: 'Electrician bio',
      );

      // Both profiles must reflect 'Final Name'
      expect(state.currentUser!.name, 'Final Name');
      expect(state.currentProvider!.name, 'Final Name');
      expect(state.allResidents.firstWhere((r) => r.phone == '9848011111').name, 'Final Name');
      expect(state.allProviders.firstWhere((p) => p.realPhone == '9848011111').name, 'Final Name');
    });

    test('18. Self User Profile Restriction: Provider cannot see their own technician card in resident listings', () async {
      SharedPreferences.setMockInitialValues({});
      final state = NearFixState();

      // 1. Register a technician 'Colony Electrician' (different phone)
      await state.registerServiceProvider(
        name: 'Colony Electrician',
        avatarUrl: '',
        category: ServiceType.electrician,
        categoryTitle: 'Electrician',
        hourlyRate: 200,
        colony: state.colonies[0],
        phone: '9848022222',
        bio: 'Other technician',
      );

      // 2. Register Self as Provider 'Self Provider' (phone: 9848033333)
      await state.registerServiceProvider(
        name: 'Self Provider',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colony: state.colonies[0],
        phone: '9848033333',
        bio: 'My own plumbing service',
      );

      // 3. Register Self as Resident
      await state.registerResident(
        name: 'Self Provider',
        colony: state.colonies[0],
        flatAddress: 'Flat 505',
        phone: '9848033333',
      );

      // 4. Switch to Resident Mode
      state.switchToRole(AppRole.resident);
      state.selectCategory(ServiceType.all);
      expect(state.activeRole, AppRole.resident);

      // In filteredProviders, 'Self Provider' must NOT be visible to self!
      final visibleProviders = state.filteredProviders;
      expect(visibleProviders.any((p) => p.name == 'Self Provider'), false);
      expect(visibleProviders.any((p) => p.realPhone == '9848033333'), false);

      // The other technician must still be visible
      expect(visibleProviders.any((p) => p.name == 'Colony Electrician'), true);
    });

    test('19. SMS Gateway Phone Cleaning, Firebase Phone Auth, Fast2SMS & 112233 Test OTP Verification', () async {
      SharedPreferences.setMockInitialValues({});
      await SmsService.init();

      // Check default provider is Firebase Phone Auth (10,000 free SMS/month)
      expect(SmsService.activeProvider, SmsGatewayProvider.firebaseAuth);

      // Test Indian mobile phone cleaning
      expect(SmsService.clean10DigitPhone('+91 98450 11223'), '9845011223');
      expect(SmsService.clean10DigitPhone('09845011223'), '9845011223');
      expect(SmsService.clean10DigitPhone('9845011223'), '9845011223');
      expect(SmsService.clean10DigitPhone('12345'), '12345');

      // Test default login OTP 112233 is accepted for testing purpose
      state.requestOtp('9845011223');
      expect(state.verifyOtp('112233'), true);

      // Test configuration saving with Fast2SMS switch
      await SmsService.saveConfiguration(
        apiKey: 'test_key_123',
        provider: SmsGatewayProvider.fast2sms,
      );
      expect(SmsService.activeApiKey, 'test_key_123');
      expect(SmsService.activeProvider, SmsGatewayProvider.fast2sms);

      // Test simulated / invalid phone validation
      final badResult = await SmsService.testSmsConnection(
        apiKey: 'test_key',
        provider: SmsGatewayProvider.fast2sms,
        testPhone: '123',
      );
      expect(badResult.success, false);
      expect(badResult.message.contains('10-digit'), true);
    });

    test('20. Default Verified Technician Seed Directory contains real verified technicians', () {
      final seeds = FirebaseService.defaultSeedProviders;
      expect(seeds.length, 10);
      expect(seeds.any((p) => p.name == 'Ramesh Kumar' && p.category == ServiceType.electrician), true);
      expect(seeds.any((p) => p.name == 'Suresh Reddy' && p.category == ServiceType.plumber), true);
      expect(seeds.any((p) => p.name == 'Praveen Manepalli' && p.category == ServiceType.plumber), true);
      expect(seeds.any((p) => p.name == 'Srikanth' && p.category == ServiceType.applianceRepair), true);
      expect(seeds.any((p) => p.name == 'Mahesh Babu' && p.city == 'Bengaluru'), true);
      expect(seeds.any((p) => p.name == 'Krishna Murthy' && p.category == ServiceType.painter), true);
      expect(seeds.any((p) => p.name == 'Venkat Rao' && p.city == 'Hyderabad'), true);
      expect(seeds.any((p) => p.name == 'Anil Sharma' && p.category == ServiceType.carpenter), true);
      expect(seeds.any((p) => p.name == 'sai Chand' && p.category == ServiceType.electrician), true);
      expect(seeds.any((p) => p.name == 'karthik pati' && p.category == ServiceType.plumber), true);
    });

    test('21. OTP Privacy: SmsResult message does not leak raw OTP digits to user popup', () async {
      SharedPreferences.setMockInitialValues({});
      await SmsService.saveConfiguration(
        apiKey: '',
        provider: SmsGatewayProvider.testMode,
      );

      final result = await SmsService.sendOtpSms(
        phone: '+91 98450 12345',
        otp: '849201',
      );

      expect(result.success, true);
      // Message must NOT expose the OTP digits '849201'
      expect(result.message.contains('849201'), false);
      expect(result.message.contains('Verification code sent'), true);
    });

    test('22. Strict Location Filtering: KPHB Colony selection strictly excludes KTPS technicians', () async {
      SharedPreferences.setMockInitialValues({});
      final state = NearFixState();

      // Seed with default providers (contains KTPS, Kukatpally/Hyderabad, Bengaluru)
      for (final p in FirebaseService.defaultSeedProviders) {
        state.allProviders.add(p);
      }

      // Find KPHB Colony
      final kphbColony = state.colonies.firstWhere((c) => c.name.toLowerCase().contains('kphb'));
      state.setColony(kphbColony);
      state.setLocationScope(LocationFilterScope.nearbyCity);
      state.selectCategory(ServiceType.all);

      final providers = state.filteredProviders;

      // Must find Hyderabad technicians (Kukatpally is ~1.7km from KPHB)
      expect(providers.isNotEmpty, true);
      expect(providers.any((p) => p.city.toLowerCase() == 'hyderabad'), true);

      // Must STRICTLY exclude KTPS (Palvancha is >240km away)
      expect(providers.any((p) => p.colonyName.toLowerCase().contains('ktps')), false);
      expect(providers.any((p) => p.city.toLowerCase().contains('palvancha')), false);
      // Must STRICTLY exclude Bengaluru
      expect(providers.any((p) => p.city.toLowerCase().contains('bengaluru')), false);
    });

    test('23. Strict Location Filtering: KTPS Colony selection strictly excludes Hyderabad and Bengaluru technicians', () async {
      SharedPreferences.setMockInitialValues({});
      final state = NearFixState();

      for (final p in FirebaseService.defaultSeedProviders) {
        state.allProviders.add(p);
      }

      // Find KTPS Colony
      final ktpsColony = state.colonies.firstWhere((c) => c.name.toLowerCase().contains('ktps'));
      state.setColony(ktpsColony);
      state.setLocationScope(LocationFilterScope.nearbyCity);
      state.selectCategory(ServiceType.all);

      final providers = state.filteredProviders;

      // Must find KTPS technicians
      expect(providers.isNotEmpty, true);
      expect(providers.every((p) => p.city.toLowerCase() == 'palvancha' || p.colonyName.toLowerCase() == 'ktps'), true);

      // Must STRICTLY exclude Hyderabad / Kukatpally
      expect(providers.any((p) => p.city.toLowerCase().contains('hyderabad')), false);
      expect(providers.any((p) => p.colonyName.toLowerCase().contains('kukatpally')), false);
    });

    test('18. Catering and DJ & Sound System Category Registration and Diagnostic Matching', () async {
      final colony = state.colonies[0];
      await state.registerServiceProvider(
        name: 'Royal Feast Catering',
        avatarUrl: '',
        category: ServiceType.catering,
        categoryTitle: 'Catering',
        hourlyRate: 599,
        colony: colony,
        phone: '+91 99988 77766',
        bio: 'Professional event catering and party food orders with 10+ years experience',
      );

      expect(state.currentProvider != null, true);
      expect(state.currentProvider!.category, ServiceType.catering);
      expect(state.currentProvider!.categoryTitle, 'Catering');

      // Test AI smart diagnostic for catering
      final diag = await GeminiService.diagnoseIssue('I need catering for a party dinner of 20 guests at my home');
      expect(diag.recommendedCategory, ServiceType.catering);
      expect(diag.categoryTitle, 'Catering');

      // Test defaultCategories includes Catering
      final caterCat = ServiceCategory.defaultCategories.firstWhere((c) => c.type == ServiceType.catering);
      expect(caterCat.title, 'Catering');
      expect(caterCat.averagePrice, 499);

      // Test defaultCategories includes DJ & Sound System
      final djCat = ServiceCategory.defaultCategories.firstWhere((c) => c.type == ServiceType.djSound);
      expect(djCat.title, 'DJ & Sound System');
      expect(djCat.averagePrice, 1499);

      // Test AI smart diagnostic for DJ & Sound System
      final djDiag = await GeminiService.diagnoseIssue('Need DJ and sound system with speakers for birthday party');
      expect(djDiag.recommendedCategory, ServiceType.djSound);
      expect(djDiag.categoryTitle, 'DJ & Sound System');
    });

    test('24. Provider Free Trial: New provider gets 90 days free trial automatically upon registration', () async {
      final colony = state.colonies[0];
      await state.registerServiceProvider(
        name: 'Sunil Electrician',
        avatarUrl: '',
        category: ServiceType.electrician,
        categoryTitle: 'Electrician',
        hourlyRate: 350,
        colony: colony,
        phone: '+91 98765 43210',
        bio: 'Residential electrician',
      );

      final p = state.currentProvider!;
      expect(p.subscriptionStatus, 'trial');
      expect(p.isAvailable, true);
      expect(p.autoBilling, true);
      expect(p.trialEndDate.isNotEmpty, true);

      // Verify trial end date is 90 days in future
      final trialEnd = p.trialEndDateTime;
      final now = DateTime.now();
      final diffDays = trialEnd.difference(now).inDays;
      expect(diffDays >= 89 && diffDays <= 91, true);
      expect(p.isSubscriptionActive, true);
      expect(p.isExpired, false);
      expect(p.subscriptionStatusDisplay, '90-Day Free Trial');
    });

    test('25. Expiry & Validity Check: Active -> 3-day Grace Period -> Expired & Auto-Hide', () {
      final now = DateTime.now();

      // Case A: Active within 90 days
      final pActive = ProviderModel(
        id: 'p_active',
        name: 'Ravi Plumber',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colonyId: 'col_1',
        colonyName: 'KTPS',
        distanceMeters: 300,
        isAvailable: true,
        isVerified: true,
        realPhone: '+91 9900011122',
        maskedVirtualNumber: '',
        trialEndDate: now.add(const Duration(days: 45)).toIso8601String(),
        subscriptionStatus: 'trial',
      );
      final evalActive = SubscriptionService.evaluateProviderSubscription(pActive);
      expect(evalActive.subscriptionStatus, 'trial');
      expect(evalActive.isAvailable, true);
      expect(evalActive.isSubscriptionActive, true);
      expect(evalActive.isExpired, false);

      // Case B: In 3-day Grace Period (e.g. 2 days overdue)
      final pGrace = ProviderModel(
        id: 'p_grace',
        name: 'Ravi Plumber',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colonyId: 'col_1',
        colonyName: 'KTPS',
        distanceMeters: 300,
        isAvailable: true,
        isVerified: true,
        realPhone: '+91 9900011122',
        maskedVirtualNumber: '',
        trialEndDate: now.subtract(const Duration(days: 2)).toIso8601String(),
        subscriptionStatus: 'trial',
      );
      final evalGrace = SubscriptionService.evaluateProviderSubscription(pGrace);
      expect(evalGrace.subscriptionStatus, 'grace_period');
      expect(evalGrace.isAvailable, true);
      expect(evalGrace.isWithinGracePeriod, true);
      expect(evalGrace.isExpired, false);

      // Case C: Expired past 3-day Grace Period (e.g. 5 days overdue) -> Auto-Hide & Marked Busy
      final pExpired = ProviderModel(
        id: 'p_expired',
        name: 'Ravi Plumber',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colonyId: 'col_1',
        colonyName: 'KTPS',
        distanceMeters: 300,
        isAvailable: true,
        isVerified: true,
        realPhone: '+91 9900011122',
        maskedVirtualNumber: '',
        trialEndDate: now.subtract(const Duration(days: 5)).toIso8601String(),
        subscriptionStatus: 'trial',
      );
      final evalExpired = SubscriptionService.evaluateProviderSubscription(pExpired);
      expect(evalExpired.subscriptionStatus, 'expired');
      expect(evalExpired.isAvailable, false); // Auto-marked as Busy / hidden!
      expect(evalExpired.isExpired, true);
      expect(evalExpired.isSubscriptionActive, false);
      expect(evalExpired.subscriptionStatusDisplay, 'Expired - Hidden');
    });

    test('26. Reminder Triggers: 75 days (15d left) and 85 days (5d left) alerts', () {
      final now = DateTime.now();

      // 15 days left (day 75 of 90)
      final p15DaysLeft = ProviderModel(
        id: 'p_15',
        name: 'Ramesh AC',
        avatarUrl: '',
        category: ServiceType.applianceRepair,
        categoryTitle: 'Appliance Repair',
        hourlyRate: 400,
        colonyId: 'col_1',
        colonyName: 'KTPS',
        distanceMeters: 300,
        isAvailable: true,
        isVerified: true,
        realPhone: '+91 9876543211',
        maskedVirtualNumber: '',
        trialEndDate: now.add(const Duration(days: 15)).toIso8601String(),
        subscriptionStatus: 'trial',
      );
      final reminder15 = SubscriptionService.getSubscriptionReminder(p15DaysLeft);
      expect(reminder15 != null, true);
      expect(reminder15!.triggerDay, 75);
      expect(reminder15.urgency, 'warning');

      // 5 days left (day 85 of 90)
      final p5DaysLeft = ProviderModel(
        id: 'p_5',
        name: 'Ramesh AC',
        avatarUrl: '',
        category: ServiceType.applianceRepair,
        categoryTitle: 'Appliance Repair',
        hourlyRate: 400,
        colonyId: 'col_1',
        colonyName: 'KTPS',
        distanceMeters: 300,
        isAvailable: true,
        isVerified: true,
        realPhone: '+91 9876543211',
        maskedVirtualNumber: '',
        trialEndDate: now.add(const Duration(days: 5)).toIso8601String(),
        subscriptionStatus: 'trial',
      );
      final reminder5 = SubscriptionService.getSubscriptionReminder(p5DaysLeft);
      expect(reminder5 != null, true);
      expect(reminder5!.triggerDay, 85);
      expect(reminder5.urgency, 'urgent');

      // In Grace period
      final pInGrace = ProviderModel(
        id: 'p_g',
        name: 'Ramesh AC',
        avatarUrl: '',
        category: ServiceType.applianceRepair,
        categoryTitle: 'Appliance Repair',
        hourlyRate: 400,
        colonyId: 'col_1',
        colonyName: 'KTPS',
        distanceMeters: 300,
        isAvailable: true,
        isVerified: true,
        realPhone: '+91 9876543211',
        maskedVirtualNumber: '',
        trialEndDate: now.subtract(const Duration(days: 2)).toIso8601String(),
        subscriptionStatus: 'grace_period',
      );
      final reminderGrace = SubscriptionService.getSubscriptionReminder(pInGrace);
      expect(reminderGrace != null, true);
      expect(reminderGrace!.triggerDay, 90);
      expect(reminderGrace.urgency, 'critical');
    });

    test('27. Customer Search Filtering: Expired / Hidden providers are excluded from customer view', () async {
      final now = DateTime.now();

      // Register an active technician
      await state.registerServiceProvider(
        name: 'Active Technician',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colony: state.colonies[0],
        phone: '+91 91111 22222',
        bio: 'Active technician',
      );

      // Add an expired technician to list
      final expiredTech = ProviderModel(
        id: 'prov_expired_999',
        name: 'Expired Technician',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colonyId: state.colonies[0].id,
        colonyName: state.colonies[0].name,
        city: state.colonies[0].city,
        latitude: state.colonies[0].latitude,
        longitude: state.colonies[0].longitude,
        distanceMeters: 200,
        isAvailable: false,
        isVerified: true,
        realPhone: '+91 93333 44444',
        maskedVirtualNumber: '',
        trialEndDate: now.subtract(const Duration(days: 10)).toIso8601String(),
        subscriptionStatus: 'expired',
      );
      state.allProviders.add(expiredTech);

      // Switch to Resident Mode to browse
      state.switchToRole(AppRole.resident);

      // Check filtered providers
      final list = state.filteredProviders;
      final names = list.map((p) => p.name).toList();

      expect(names.contains('Expired Technician'), false);
    });

    test('28. Monthly Subscription Renewal: Payment of ₹99 generates receipt, extends 30 days and reactivates provider', () async {
      final now = DateTime.now();

      // 1. Create an expired provider
      await state.registerServiceProvider(
        name: 'Kiran Carpenter',
        avatarUrl: '',
        category: ServiceType.carpenter,
        categoryTitle: 'Carpenter',
        hourlyRate: 400,
        colony: state.colonies[0],
        phone: '+91 94444 55555',
        bio: 'Furniture work',
      );

      // Simulate expiry (set trial end date 5 days in past)
      final expired = state.currentProvider!.copyWith(
        trialEndDate: now.subtract(const Duration(days: 5)).toIso8601String(),
        subscriptionStatus: 'expired',
        isAvailable: false,
      );
      state.updateProviderProfile(
        name: expired.name,
        avatarUrl: expired.avatarUrl,
        category: expired.category,
        categoryTitle: expired.categoryTitle,
        hourlyRate: expired.hourlyRate,
        colony: state.colonies[0],
        phone: expired.realPhone,
        bio: expired.bio,
      );

      // 2. Perform ₹99 + 18% GST (₹116.82) Subscription Renewal
      final res = await state.renewSubscription(
        gateway: 'Direct UPI / QR',
        amount: 116.82,
        autoBilling: true,
      );

      expect(res['success'], true);
      final pUpdated = state.currentProvider!;
      expect(pUpdated.subscriptionStatus, 'active');
      expect(pUpdated.isAvailable, true); // Status flipped back to Available!
      expect(pUpdated.paymentId.isNotEmpty, true);
      expect(pUpdated.subscriptionEndDate.isNotEmpty, true);

      // Verify payment receipt created
      final payment = res['payment'] as PaymentModel;
      expect(payment.amount, 116.82);
      expect(payment.currency, 'INR');
      expect(payment.gateway, 'Direct UPI / QR');
      expect(payment.receiptNumber.startsWith('NS-REC-'), true);
      expect(payment.status, 'success');
      expect(state.myPayments.isNotEmpty, true);
    });

    test('29. Auto-Billing Preference: Toggle and persistence of recurring auto-renew', () async {
      await state.registerServiceProvider(
        name: 'Gopal Painter',
        avatarUrl: '',
        category: ServiceType.painter,
        categoryTitle: 'Painter',
        hourlyRate: 350,
        colony: state.colonies[0],
        phone: '+91 96666 77777',
        bio: 'Home painter',
      );

      expect(state.currentProvider!.autoBilling, true);

      // Toggle auto-billing off
      state.toggleProviderAutoBilling(false);
      expect(state.currentProvider!.autoBilling, false);

      // Toggle auto-billing back on
      state.toggleProviderAutoBilling(true);
      expect(state.currentProvider!.autoBilling, true);
    });
  });

  group('NearSlay Auth UI Widget Tests', () {
    testWidgets('NearFixApp opens with PhoneAuthScreen asking for mobile number first',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const NearFixApp());
      await tester.pump();

      expect(find.text('NearSlay'), findsOneWidget);
      expect(find.text('Enter Mobile Number'), findsOneWidget);
      expect(find.text('Get OTP Verification Code'), findsOneWidget);
      expect(find.text('Verified Local Pros'), findsOneWidget);
      expect(find.text('Direct Phone Calls'), findsOneWidget);
    });

    testWidgets('Vivo V19 (392x872) & Compact (360x780) screen ratio responsive rendering without overflow',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      // Set physical size for Vivo V19 (20:9 aspect ratio)
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75; // ~392 x 872 logical pixels

      await tester.pumpWidget(const NearFixApp());
      await tester.pump();

      expect(find.text('NearSlay'), findsOneWidget);
      expect(find.text('Get OTP Verification Code'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Reset view after test
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('30. Subscription UI Screen: Shows 90-day trial status, Razorpay UPI Checkout, and GST breakdown',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = NearFixState();
      await state.registerServiceProvider(
        name: 'Mohan Repair',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 300,
        colony: state.colonies[0],
        phone: '+91 98888 11223',
        bio: 'Plumber',
      );

      expect(state.currentProvider != null, true);

      await tester.pumpWidget(
        ChangeNotifierProvider<NearFixState>.value(
          value: state,
          child: const MaterialApp(
            home: SubscriptionScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('NearSlay Pro Subscription'), findsOneWidget);
      expect(find.text('NearSlay Pro Plan'), findsOneWidget);
      expect(find.text('₹99 + GST'), findsOneWidget);
      expect(find.text('Select Payment Method'), findsOneWidget);
      expect(find.text('Tax & Price Breakdown'), findsOneWidget);
      expect(find.text('Total GST (18%)'), findsOneWidget);

      // Verify there is EXACTLY ONE primary Pay button on the subscription tab
      expect(find.text('Pay ₹116.82'), findsOneWidget);
      expect(find.text('Razorpay UPI (GPay / PhonePe / Paytm / BHIM)'), findsOneWidget);
    });

    test('31. Production UPI UTR Strict Validation', () {
      // Valid Indian UPI UTR numbers
      expect(SubscriptionService.isValidUtr('427819283719'), true);
      expect(SubscriptionService.isValidUtr('312984719283'), true);
      expect(SubscriptionService.isValidUtr('AXIS001928371'), true);
      expect(SubscriptionService.isValidUtr('HDFC192837465'), true);

      // Invalid / Dummy formats must be rejected
      expect(SubscriptionService.isValidUtr(null), false);
      expect(SubscriptionService.isValidUtr(''), false);
      expect(SubscriptionService.isValidUtr('123'), false);
      expect(SubscriptionService.isValidUtr('test'), false);
      expect(SubscriptionService.isValidUtr('TEST_UTR_12345'), false);
      expect(SubscriptionService.isValidUtr('DEMO123456789'), false);
      expect(SubscriptionService.isValidUtr('000000000000'), false);
      expect(SubscriptionService.isValidUtr('111111111111'), false);
      expect(SubscriptionService.isValidUtr('123456789012'), false);
    });

    test('32. Razorpay Production Configuration & Amount in Paise Validation', () {
      // 1. Validate ₹99 + 18% GST calculation in paise
      const double payable = 116.82;
      final int amountInPaise = (payable * 100).round();
      expect(amountInPaise, 11682);

      // 2. Validate Razorpay Key ID format
      expect(RazorpayService.razorpayKeyId.startsWith('rzp_'), true);
    });

    test('33. Deleted or Cleared User triggers registration screen and rejects auto-login', () async {
      final state = NearFixState();
      final colony = state.colonies[0];
      const testPhone = '9912525829';

      // 1. Register resident
      await state.registerResident(
        name: 'Praveen Manepalli',
        colony: colony,
        flatAddress: 'Flat 101',
        phone: testPhone,
      );
      expect(state.isLoggedIn, true);
      expect(state.currentUser != null, true);

      // 2. Admin or UI deletes account
      await state.deleteResidentByAdmin(testPhone);
      expect(state.isLoggedIn, false);
      expect(state.activeRole, AppRole.unregistered);
      expect(state.currentUser, isNull);

      // 3. User attempts to log in again with the same number
      final otp = state.requestOtp(testPhone);
      final account = state.checkExistingAccount(testPhone);
      expect(account['exists'], false);

      // 4. Verify OTP enters valid OTP code
      final ok = state.verifyOtp(otp);
      expect(ok, true);

      // 5. Must NOT be auto-logged in; role remains unregistered
      expect(state.isLoggedIn, false);
      expect(state.activeRole, AppRole.unregistered);
      expect(state.currentUser, isNull);
      expect(state.currentProvider, isNull);
    });

    test('34. Refreshing via syncWithCloud logs out active user if not found in database', () async {
      final state = NearFixState();
      final colony = state.colonies[0];
      const testPhone = '9912525829';

      // 1. User is registered and logged in
      await state.registerResident(
        name: 'Praveen Manepalli',
        colony: colony,
        flatAddress: 'Flat 101',
        phone: testPhone,
      );
      expect(state.isLoggedIn, true);
      expect(state.currentUser != null, true);

      // 2. Set forceTestUserAvailableInCloud = false (simulates user deleted from cloud database)
      FirebaseService.forceTestUserAvailableInCloud = false;

      // 3. User refreshes from app (e.g. pull to refresh or sync button)
      await state.syncWithCloud(showIndicator: true);

      // 4. Must immediately log out the user and clear active session
      expect(state.isLoggedIn, false);
      expect(state.activeRole, AppRole.unregistered);
      expect(state.currentUser, isNull);
      expect(state.currentProvider, isNull);

      // Reset test override
      FirebaseService.forceTestUserAvailableInCloud = null;
    });

    test('35. WhatsApp OTP formatting and delivery payload verification', () async {
      const phone = '9912525829';
      const otp = '781920';

      final res = await SmsService.sendWhatsAppOtp(phone: phone, otp: otp);

      expect(res['success'], true);
      expect(res['otp'], otp);
      expect(res['formattedMessage'], '$otp is your verification code for nearslay');
      expect(SmsService.lastSentOtpCode, otp);

      // Verify that verifyReceivedCode accepts this WhatsApp OTP code
      final verified = await SmsService.verifyReceivedCode(otp, expectedOtp: otp);
      expect(verified, true);
    });

    test('36. User Session Persistence: App close and reopen retains logged in resident and provider sessions without logout', () async {
      SharedPreferences.setMockInitialValues({});
      final state1 = NearFixState();
      final colony = state1.colonies[0];
      const testPhone = '9912525829';

      // 1. Resident registers and logs in
      await state1.registerResident(
        name: 'Praveen Manepalli',
        colony: colony,
        flatAddress: 'Flat 101, KTPS',
        phone: testPhone,
      );
      expect(state1.isLoggedIn, true);
      expect(state1.activeRole, AppRole.resident);
      expect(state1.currentUser != null, true);

      // 2. Simulate app close and reload from SharedPreferences
      final saved = await SessionService.loadSession();
      expect(saved != null, true);
      expect(saved!.isLoggedIn, true);
      expect(saved.role, AppRole.resident);
      expect(saved.user != null, true);
      expect(saved.user!.name, 'Praveen Manepalli');

      // 3. Simulate new state instance on app reopen
      final state2 = NearFixState();
      await state2.syncWithCloud(showIndicator: false);

      // Verify that syncWithCloud on reopen does NOT log out the user!
      final reloadedSession = await SessionService.loadSession();
      expect(reloadedSession != null, true);
      expect(reloadedSession!.isLoggedIn, true);
      expect(reloadedSession.role, AppRole.resident);

      // 4. Provider registration session persistence
      await state1.registerServiceProvider(
        name: 'Praveen Plumber',
        avatarUrl: '',
        category: ServiceType.plumber,
        categoryTitle: 'Plumber',
        hourlyRate: 299,
        colony: colony,
        phone: '9876543210',
        bio: 'Expert Plumber',
      );
      expect(state1.isLoggedIn, true);
      expect(state1.activeRole, AppRole.provider);

      final savedProv = await SessionService.loadSession();
      expect(savedProv != null, true);
      expect(savedProv!.isLoggedIn, true);
      expect(savedProv.role, AppRole.provider);
      expect(savedProv.provider != null, true);
      expect(savedProv.provider!.name, 'Praveen Plumber');

      // Reopening app and syncing must keep provider logged in
      await state2.syncWithCloud(showIndicator: false);
      final reloadedProvSession = await SessionService.loadSession();
      expect(reloadedProvSession!.isLoggedIn, true);
      expect(reloadedProvSession.role, AppRole.provider);

      // 5. Only explicit logout clears the session
      state1.logout();
      expect(state1.isLoggedIn, false);
      expect(state1.activeRole, AppRole.unregistered);
      final loggedOutSession = await SessionService.loadSession();
      expect(loggedOutSession!.isLoggedIn, false);
    });
  });
}
