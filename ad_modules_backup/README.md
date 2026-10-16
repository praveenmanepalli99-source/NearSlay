# 📦 NearFix / NearSlay AdMob & Remote Config Module Archive

This directory contains the complete, tested, and ready-to-use Google AdMob Native Advanced Ads and Firebase Remote Config integration.

## 📁 Archived Files
- `ad_service.dart`: Handles AdMob initialization, Android & iOS Native Ad unit loaders (`ca-app-pub-3940256099942544/2247696110`), and NativeTemplateStyle.
- `native_ad_card.dart`: Custom Flutter widget that formats in-feed native ads to blend seamlessly with NearFix provider cards.
- `remote_config_service.dart`: Firebase Remote Config service managing `show_ads` dynamic boolean switches and VIP Purchaser audience rules.

## 🚀 How to Re-Activate
When requested by the user ("add ad changes" / "enable native ads"):
1. Add `google_mobile_ads: ^5.2.0` to `pubspec.yaml` and run `flutter pub get`.
2. Copy `ad_service.dart` to `lib/services/` and `native_ad_card.dart` to `lib/widgets/`.
3. Add AdMob Application ID metadata `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-3940256099942544~3347511713"/>` to `android/app/src/main/AndroidManifest.xml`.
4. Initialize `AdService.instance.init()` in `lib/main.dart` and add `NativeAdCard` into `lib/screens/home_screen.dart`.
