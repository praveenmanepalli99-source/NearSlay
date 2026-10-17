# Proguard & R8 Optimization Rules for NearFix / NearSlay

# 1. Flutter Framework Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 2. Razorpay Android SDK Rules
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
    public void onPaymentSuccess(java.lang.String);
    public void onPaymentError(int, java.lang.String);
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface

# 3. Google Firebase Rules
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# 4. Google Generative AI (Gemini) Rules
-dontwarn com.google.ai.client.generativeai.**
-keep class com.google.ai.client.generativeai.** { *; }

# 5. AndroidX Fragment & Lifecycle (Solves outdated SDK warning)
-dontwarn androidx.fragment.app.**
-keep class androidx.fragment.app.** { *; }
-dontwarn androidx.activity.**
-keep class androidx.activity.** { *; }
-dontwarn androidx.lifecycle.**
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.browser.**
-keep class androidx.browser.** { *; }

# 6. Serialization & Annotations
-keepattributes Signature
-keepattributes Exceptions
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 7. Play Core / Deferred Components (Required by Flutter engine in AGP 8.x)
-dontwarn com.google.android.play.core.**
