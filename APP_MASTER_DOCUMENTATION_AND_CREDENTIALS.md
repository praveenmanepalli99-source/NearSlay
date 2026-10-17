# 📘 NearFix (NearSlay) — Master System Specifications & Credentials Vault

> **Summary:** Complete in-and-out technical documentation, credentials vault, endpoints, and static data for **NearFix (NearSlay)** before publishing to Google Play Store.

---

## 📱 1. Frontend Architecture & Mobile App

| Parameter | Specification / Value | File Reference |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.24+ (Channel Stable) | [pubspec.yaml](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/pubspec.yaml) |
| **Language** | Dart SDK `>=3.4.3 <4.0.0` | [pubspec.yaml](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/pubspec.yaml) |
| **Design System** | Material 3 (`useMaterial3: true`) + Outfit & Inter Google Fonts | [lib/main.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/main.dart) |
| **State Management** | **Provider Pattern** (`ChangeNotifierProvider<NearFixState>`) | [lib/state/nearfix_state.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/state/nearfix_state.dart) |
| **Offline Persistence** | `SharedPreferences` session cache + Offline pending registration queue | [lib/services/session_service.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/session_service.dart) |
| **Geolocation Engine** | Live GPS tracking, Haversine 5km/10km radius filtering & reverse geocoding | [lib/services/location_service.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/location_service.dart) |

### Installed Packages & Versions
- `provider: ^6.1.2` — Reactive state management
- `geolocator: ^12.0.0` — High-accuracy GPS location acquisition
- `geocoding: ^3.0.0` — Reverse geocoding coordinates to Colony/City names
- `google_fonts: ^6.2.1` — Dynamic font loader (Outfit, Inter)
- `image_picker: ^1.1.2` — Profile and technician avatar image capture & selection
- `shared_preferences: ^2.2.3` — Offline session and pending queue persistence
- `http: ^1.2.2` — REST API calls to Firebase RTDB & SMS Gateways
- `url_launcher: ^6.3.0` — Native phone dialer (`tel:`) and mail (`mailto:`) intents
- `uuid: ^4.4.0` — Unique ID generator for residents and providers
- `google_generative_ai: ^0.4.6` — Gemini 1.5 Flash AI Assistant integration
- `intl: ^0.19.0` — Date, time & currency formatting
- `cupertino_icons: ^1.0.6` — iOS styled icon support

### Core Screen Components (9 Screens)
1. [HomeScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/home_screen.dart): Nearby technician discovery, 5km primary/10km fallback radius, category filter chips, search, AI triage modal.
2. [PhoneAuthScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/phone_auth_screen.dart): Mobile number entry, OTP generation, automatic role detection.
3. [OtpVerificationScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/otp_verification_screen.dart): 6-digit OTP code verification, bypass OTP support.
4. [NewUserRoleChoiceScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/new_user_role_choice_screen.dart): Unregistered user flow selection (Resident vs Service Provider).
5. [UserRegistrationScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/user_registration_screen.dart): Resident name, phone, colony selection, house/flat address.
6. [ProviderRegistrationScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/provider_registration_screen.dart): Technician profile creation, trade category, hourly rate, bio, photo.
7. [ProviderDashboardScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/provider_dashboard_screen.dart): Technician availability toggle (Active/Busy), rate updater, customer leads.
8. [MyProfileScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/my_profile_screen.dart): Profile management, colony switcher, role switching, admin console link, account deletion.
9. [AuthRoleSelectionScreen](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/screens/auth_role_selection_screen.dart): Initial role routing.

---

## 🤖 2. Android & Google Play Store Publishing Parameters

| Setting | Configured Value | Location |
| :--- | :--- | :--- |
| **Application ID / Package Name** | `com.nearfix.app.nearfix` | [android/app/build.gradle](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/android/app/build.gradle#L47) |
| **App Name / Label** | `NearSlay` (NearFix) | [AndroidManifest.xml](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/android/app/src/main/AndroidManifest.xml#L11) |
| **App Version** | `1.0.21` | [pubspec.yaml](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/pubspec.yaml#L19) |
| **Version Code / Build Number** | `26` | [pubspec.yaml](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/pubspec.yaml#L19) |
| **Minimum SDK** | `API 24` (Android 7.0 Nougat) | [android/app/build.gradle](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/android/app/build.gradle#L48) |
| **Target SDK** | `API 36` (Android 15+) | [android/app/build.gradle](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/android/app/build.gradle#L49) |
| **Compile SDK** | `API 34` | [android/app/build.gradle](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/android/app/build.gradle#L34) |
| **Cleartext Traffic Policy** | `android:usesCleartextTraffic="false"` (Strict HTTPS Play Store Compliance) | [AndroidManifest.xml](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/android/app/src/main/AndroidManifest.xml#L14) |
| **Production Build Command** | `flutter build appbundle --release` | Terminal |

### Registered SHA Certificate Fingerprints in Firebase
- **Google Play App Signing (Play Store / Production):**
  - SHA-1: `44:B4:88:78:27:CC:50:65:54:C2:2A:52:64:0C:7C:F8:F0:1D:53:67`
  - SHA-256: `FD:7D:97:AA:48:F4:9D:FE:D4:91:D6:40:73:40:FC:D0:F9:E1:F6:9F:D5:21:5B:80:3E:EF:0F:64:C7:07:46:62`
- **Release Keystore (`upload-keystore.jks` / Direct APK installs):**
  - SHA-1: `68:5D:99:01:8F:A7:A9:CE:CB:D9:65:89:1C:EC:68:9E:DD:04:6E:34`
  - SHA-256: `C4:B0:FB:0B:4B:6A:FF:2F:8E:A2:84:78:DE:F1:00:EE:DF:AC:D1:BA:C7:2A:B9:DA:E9:49:F2:50:CD:D3:ED:08`
- **Google Play Internal App Sharing:**
  - SHA-1: `E0:CB:62:57:F5:26:61:83:1E:7A:97:A5:76:8C:A9:CD:96:6A:04:B7`

### Declared Android Permissions
- `android.permission.INTERNET` — Network connectivity for Firebase REST DB & SMS.
- `android.permission.ACCESS_NETWORK_STATE` — Network availability detection.
- `android.permission.ACCESS_FINE_LOCATION` — High-accuracy GPS for 5km/10km radius calculation.
- `android.permission.ACCESS_COARSE_LOCATION` — Approximate cell/WiFi network location.

---

## ☁️ 3. Cloud Database & Backend Endpoints

| Resource | Protocol | Endpoint URL | Description |
| :--- | :--- | :--- | :--- |
| **Production Cloud Database** | HTTPS REST | `https://nearslay-default-rtdb.firebaseio.com` | Google Firebase Realtime Database (24/7 Global Single Source of Truth). |
| **Providers Node** | HTTPS REST | `https://nearslay-default-rtdb.firebaseio.com/providers.json` | Technician profile registration, real-time availability & ratings. |
| **Residents Node** | HTTPS REST | `https://nearslay-default-rtdb.firebaseio.com/residents.json` | Resident registration, colony addresses & phone directory. |
| **Local Admin Server** | HTTP REST | `http://localhost:5000/api` | Python management server (`admin_portal/server.py`) on Port 5000. |
| **Local DB Mirror** | Local File | `admin_portal/cloud_db.json` | Persistent local mirror of providers and residents. |
| **Public HTTPS Tunnel** | HTTPS | `admin_portal/cloudflared.exe` | Zero-configuration Cloudflare Tunnel for remote testing. |

---

## 🔑 4. API Keys & Master Credentials Vault

| Service / Tool | Credential Key / Value | Portal / Config Location | Notes |
| :--- | :--- | :--- | :--- |
| **Firebase Identity Toolkit Web API Key** | `AIzaSyBPkvHZceFr6JaDortv6K8FNtOOHaI77N0` | [Firebase Console](https://console.firebase.google.com) / [sms_service.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/sms_service.dart) | Primary 100% Free OTP Gateway (10,000 Free SMS per month globally). |
| **Master Test Bypass OTP** | `112233` | [nearfix_state.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/state/nearfix_state.dart) | Universal test OTP for instant login on any mobile without SMS cost. |
| **Admin Portal Master PIN** | `9999` (or `1234`) | `admin_portal/index.html` | Master administrator unlock PIN for the web dashboard. |
| **Fast2SMS Gateway API Key** | `3KHacTMhRe0EmKK55nZUYKQ1YRP8wKR2K6UrcJNlSK3bCYemH9JxVdGpNpuQ` | [Fast2SMS](https://www.fast2sms.com) / [sms_service.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/sms_service.dart) | Active Fast2SMS gateway key with ₹93+ balance & 370+ SMS credits. |
| **2Factor.in Gateway API Key** | `c22862fa-ab7c-11f1-9cb1-0200cd936042` | [2Factor](https://2factor.in) / [sms_service.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/sms_service.dart) | Tertiary backup Indian SMS & Voice OTP delivery gateway. |
| **Google Gemini AI Assistant** | `gemini-1.5-flash` | [Google AI Studio](https://aistudio.google.com) / [gemini_service.dart](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/gemini_service.dart) | Smart issue diagnosis, technician category matching & labor cost estimates. |

---

## 📋 5. Static Details, Predefined Categories & Colony Nodes

### 13 Preconfigured Service Categories & Standard Pricing
| Category Icon & Title | Service Type Identifier | Default Labor Rate | Typical Services |
| :--- | :--- | :--- | :--- |
| 🍽️ **Catering** | `ServiceType.catering` | ₹499 / meal | Event catering, party food orders, buffets & meal boxes |
| 🔧 **Plumber** | `ServiceType.plumber` | ₹199 / hr | Tap leakages, pipe blockages, motor fittings & sanitary repairs |
| ⚡ **Electrician** | `ServiceType.electrician` | ₹249 / hr | Short circuit, fan fitting, MCB switch repairs & home wiring |
| 🛠️ **Mechanic** | `ServiceType.mechanic` | ₹299 / hr | Bike & car repairs, puncture, oil change & tune-ups |
| 🩺 **Doctor** | `ServiceType.doctor` | ₹499 / consult | Home visits, general physicians & clinic consultations |
| 🏨 **Hotel** | `ServiceType.hotel` | ₹999 / room | Hotels, rooms, lodges & guest accommodations |
| 🍴 **Restaurant** | `ServiceType.restaurant` | ₹299 / meal | Dining, family restaurants, catering & food takeaway |
| 🎉 **Decoration** | `ServiceType.decoration` | ₹1,499 / event | Event & stage decor, balloon & flower decoration |
| 🎪 **Tent House** | `ServiceType.tentHouse` | ₹1,999 / event | Shamiana, tent, sound, stage & chairs rental for events |
| 🪚 **Carpenter** | `ServiceType.carpenter` | ₹249 / hr | Door hinge fixes, furniture assembly, lock replacement |
| 📺 **Appliance Repair** | `ServiceType.applianceRepair` | ₹349 / hr | AC servicing, washing machine, fridge & microwave fix |
| 🎨 **Painter** | `ServiceType.painter` | ₹399 / hr | Wall touchups, waterproofing, door polish |
| 🎧 **DJ & Sound System** | `ServiceType.djSound` | ₹1,499 / event | DJ setup, party sound systems, speakers & event audio |

### Predefined Colony Seed Nodes
| Colony Name | City | Latitude | Longitude | Pincode | Landmark |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **KPHB Colony** | Hyderabad | `17.4933` | `78.3995` | 500072 | Near KPHB Metro Station |
| **Kukatpally** | Hyderabad | `17.4849` | `78.4138` | 500072 | Near Metro Station |
| **KTPS** | Palvancha | `17.5980` | `80.6970` | 507115 | Near Power Station |
| **Banjara Hills** | Hyderabad | `17.4156` | `78.4350` | 500034 | Road No 12 |
| **My Live Location** | Current Location | Dynamic GPS | Dynamic GPS | Auto | Real-time GPS Geolocation |

### Virtual Masked Number Scheme
- **Format:** `+91 80 XXXX XXXX`
- **Purpose:** Protects technician privacy while allowing residents to place calls and open direct WhatsApp chats without exposing private personal phone numbers.

---

## 🛡️ 6. Privacy Policy & Compliance Documents

| Document | Location | Purpose |
| :--- | :--- | :--- |
| **In-App Markdown Policy** | [PRIVACY_POLICY.md](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/PRIVACY_POLICY.md) | Built into Flutter app asset bundle. |
| **Hosted Web Privacy Policy** | `admin_portal/privacy.html` | Web page for Google Play Console Privacy Policy URL submission. |
| **Safety Guidelines** | `admin_portal/safety.html` | Safety guidelines for residents and service providers. |

---

## 📊 7. Admin Portal Web Dashboard

- **Access URL:** [http://localhost:5000](http://localhost:5000)
- **New Tab Added:** **"System Specs & Master Credentials"** tab with 1-click **Copy buttons**, live search, and full export capabilities (.xlsx / .csv).

---

## 💰 8. Google AdMob & Firebase Remote Config Native Ads (Preserved / Inactive)

> 💡 **Release Status:** **100% Clean & Ad-Free Production Release.** All ad units and SDK calls are decoupled from active screens for a pure, fast, ad-free initial store launch. The complete Native Ad integration module is preserved aside and ready for instant 1-click activation whenever requested.

| Parameter | Configuration / Value | Status / Location |
| :--- | :--- | :--- |
| **Current Build Mode** | `Clean Ad-Free` | No ads loaded on user screens |
| **Preserved Native Ad Unit (Android)**| `ca-app-pub-3940256099942544/2247696110` | Saved in [AdService](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/ad_service.dart) |
| **Preserved Native Ad Unit (iOS)** | `ca-app-pub-3940256099942544/3986624511` | Saved in [AdService](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/ad_service.dart) |
| **Remote Config Switch** | `show_ads` (Boolean) | Configured in [RemoteConfigService](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/services/remote_config_service.dart) |
| **In-Feed Native Card Widget** | [NativeAdCard](file:///c:/Users/user/.gemini/antigravity-ide/scratch/Nearfix/lib/widgets/native_ad_card.dart) | Modular card ready for feed injection |



