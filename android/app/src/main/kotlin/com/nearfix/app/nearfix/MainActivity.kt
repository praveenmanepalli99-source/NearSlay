package com.nearfix.app.nearfix

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseException
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.PhoneAuthCredential
import com.google.firebase.auth.PhoneAuthOptions
import com.google.firebase.auth.PhoneAuthProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity: FlutterActivity() {
    private val APP_INFO_CHANNEL = "com.nearfix.app/app_info"
    private val FIREBASE_AUTH_CHANNEL = "com.nearfix.app/firebase_auth"

    companion object {
        private const val PREFS_NAME = "nearfix_auth_prefs"
        private const val KEY_VERIFICATION_ID = "stored_verification_id"
        private const val KEY_AUTO_VERIFIED = "is_auto_verified"
        private const val KEY_AUTO_CODE = "auto_verified_code"

        var staticVerificationId: String? = null
        var staticResendToken: PhoneAuthProvider.ForceResendingToken? = null
        var staticIsAutoVerified: Boolean = false
        var staticAutoVerifiedCode: String? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // 1. App Info Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_INFO_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAppInfo") {
                try {
                    val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                    val versionName = pInfo.versionName ?: "1.0.17"
                    val versionCode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        pInfo.longVersionCode.toString()
                    } else {
                        @Suppress("DEPRECATION")
                        pInfo.versionCode.toString()
                    }
                    result.success(mapOf(
                        "version" to versionName,
                        "buildNumber" to versionCode
                    ))
                } catch (e: Exception) {
                    result.success(mapOf(
                        "version" to "1.0.17",
                        "buildNumber" to "22"
                    ))
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Firebase Phone Auth Channel (Real SMS Dispatch via Google Play Services)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FIREBASE_AUTH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendFirebaseOtp" -> {
                    val rawPhone = (call.argument<String>("phoneNumber") ?: "").trim()
                    val digits = rawPhone.replace("\\D".toRegex(), "")
                    val phone = if (digits.length >= 10) "+91${digits.takeLast(10)}" else if (rawPhone.startsWith("+")) rawPhone else "+$digits"
                    val isResend = call.argument<Boolean>("isResend") ?: false

                    if (digits.length < 10) {
                        result.success(mapOf(
                            "success" to false,
                            "message" to "Valid 10-digit mobile number is required"
                        ))
                        return@setMethodCallHandler
                    }

                    android.util.Log.d("NearFixAuth", "sendFirebaseOtp initiated for: $phone (isResend: $isResend)")

                    staticIsAutoVerified = false
                    staticAutoVerifiedCode = null
                    prefs.edit()
                        .remove(KEY_VERIFICATION_ID)
                        .remove(KEY_AUTO_VERIFIED)
                        .remove(KEY_AUTO_CODE)
                        .apply()

                    try {
                        if (FirebaseApp.getApps(this).isEmpty()) {
                            FirebaseApp.initializeApp(this)
                        }
                        val auth = FirebaseAuth.getInstance()
                        auth.useAppLanguage()
                        var callbackDispatched = false

                        val callbacks = object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
                            override fun onVerificationCompleted(credential: PhoneAuthCredential) {
                                val smsCode = credential.smsCode ?: ""
                                android.util.Log.d("NearFixAuth", "onVerificationCompleted autoVerified, code: $smsCode")

                                staticIsAutoVerified = true
                                staticAutoVerifiedCode = smsCode
                                prefs.edit()
                                    .putBoolean(KEY_AUTO_VERIFIED, true)
                                    .putString(KEY_AUTO_CODE, smsCode)
                                    .apply()

                                auth.signInWithCredential(credential)
                                    .addOnCompleteListener { signInTask ->
                                        if (signInTask.isSuccessful) {
                                            android.util.Log.d("NearFixAuth", "Auto sign-in successful: ${auth.currentUser?.uid}")
                                        }
                                    }

                                if (!callbackDispatched) {
                                    callbackDispatched = true
                                    runOnUiThread {
                                        result.success(mapOf(
                                            "success" to true,
                                            "autoVerified" to true,
                                            "smsCode" to smsCode,
                                            "message" to "Auto-verified via Google Play Services"
                                        ))
                                    }
                                }
                            }

                            override fun onVerificationFailed(e: FirebaseException) {
                                val errType = (e as? com.google.firebase.auth.FirebaseAuthException)?.errorCode ?: e.javaClass.simpleName
                                val errMsg = e.localizedMessage ?: "Firebase verification failed"
                                val fullMsg = "$errType: $errMsg"
                                android.util.Log.e("NearFixAuth", "onVerificationFailed: $fullMsg", e)
                                if (!callbackDispatched) {
                                    callbackDispatched = true
                                    runOnUiThread {
                                        result.success(mapOf(
                                            "success" to false,
                                            "message" to fullMsg,
                                            "errorCode" to errType
                                        ))
                                    }
                                }
                            }

                            override fun onCodeSent(
                                verificationId: String,
                                token: PhoneAuthProvider.ForceResendingToken
                            ) {
                                android.util.Log.d("NearFixAuth", "onCodeSent verificationId: $verificationId")
                                staticVerificationId = verificationId
                                staticResendToken = token
                                prefs.edit().putString(KEY_VERIFICATION_ID, verificationId).apply()

                                if (!callbackDispatched) {
                                    callbackDispatched = true
                                    runOnUiThread {
                                        result.success(mapOf(
                                            "success" to true,
                                            "verificationId" to verificationId,
                                            "message" to "Real SMS verification code dispatched from Firebase"
                                        ))
                                    }
                                }
                            }

                            override fun onCodeAutoRetrievalTimeOut(verificationId: String) {
                                android.util.Log.d("NearFixAuth", "onCodeAutoRetrievalTimeOut: $verificationId")
                                staticVerificationId = verificationId
                                prefs.edit().putString(KEY_VERIFICATION_ID, verificationId).apply()
                            }
                        }

                        val optionsBuilder = PhoneAuthOptions.newBuilder(auth)
                            .setPhoneNumber(phone)
                            .setTimeout(60L, TimeUnit.SECONDS)
                            // Note: Omit setActivity(this) so Firebase never opens a Chrome Custom Tab browser window
                            .setCallbacks(callbacks)

                        if (isResend && staticResendToken != null) {
                            optionsBuilder.setForceResendingToken(staticResendToken!!)
                        }

                        PhoneAuthProvider.verifyPhoneNumber(optionsBuilder.build())
                    } catch (e: Exception) {
                        android.util.Log.e("NearFixAuth", "Exception starting PhoneAuth: ${e.localizedMessage}", e)
                        runOnUiThread {
                            result.success(mapOf(
                                "success" to false,
                                "message" to (e.localizedMessage ?: "Failed to initiate Firebase SMS")
                            ))
                        }
                    }
                }
                "verifyFirebaseCode" -> {
                    val rawCode = call.argument<String>("code") ?: ""
                    val code = rawCode.replace("\\D".toRegex(), "").trim()
                    val argId = (call.argument<String>("verificationId") ?: "").trim()

                    val verificationId = if (argId.isNotEmpty()) {
                        argId
                    } else if (!staticVerificationId.isNullOrEmpty()) {
                        staticVerificationId!!
                    } else {
                        prefs.getString(KEY_VERIFICATION_ID, "") ?: ""
                    }

                    val wasAuto = staticIsAutoVerified || prefs.getBoolean(KEY_AUTO_VERIFIED, false)
                    val autoCode = staticAutoVerifiedCode ?: prefs.getString(KEY_AUTO_CODE, "") ?: ""

                    // 1. If Google Play Services already auto-verified this phone
                    if (wasAuto && (code == autoCode || autoCode.isEmpty() || code.length == 6)) {
                        android.util.Log.d("NearFixAuth", "verifyFirebaseCode: Already auto-verified by Play Services")
                        runOnUiThread { result.success(true) }
                        return@setMethodCallHandler
                    }

                    // 2. If Firebase currentUser is already authenticated
                    try {
                        val auth = FirebaseAuth.getInstance()
                        val currentUser = auth.currentUser
                        if (currentUser != null && !currentUser.phoneNumber.isNullOrEmpty()) {
                            android.util.Log.d("NearFixAuth", "verifyFirebaseCode: Firebase currentUser active (${currentUser.phoneNumber})")
                            runOnUiThread { result.success(true) }
                            return@setMethodCallHandler
                        }
                    } catch (_: Exception) {}

                    if (verificationId.isEmpty() || code.length != 6) {
                        runOnUiThread { result.success(false) }
                        return@setMethodCallHandler
                    }

                    // 3. Verify the carrier SMS code with Firebase
                    try {
                        val credential = PhoneAuthProvider.getCredential(verificationId, code)
                        val auth = FirebaseAuth.getInstance()
                        auth.signInWithCredential(credential)
                            .addOnCompleteListener { task ->
                                runOnUiThread {
                                    if (task.isSuccessful) {
                                        val user = auth.currentUser
                                        android.util.Log.d("NearFixAuth", "signInWithCredential SUCCESS. UID: ${user?.uid}")
                                        prefs.edit().putBoolean(KEY_AUTO_VERIFIED, true).apply()
                                        staticIsAutoVerified = true
                                        result.success(true)
                                    } else {
                                        val errMsg = task.exception?.localizedMessage ?: ""
                                        android.util.Log.w("NearFixAuth", "signInWithCredential failed: $errMsg")

                                        // If code was already consumed by background auto-verify, accept it
                                        val alreadyUsed = errMsg.contains("already", ignoreCase = true) ||
                                                errMsg.contains("consumed", ignoreCase = true)
                                        if (alreadyUsed && auth.currentUser != null) {
                                            result.success(true)
                                        } else {
                                            result.success(false)
                                        }
                                    }
                                }
                            }
                    } catch (e: Exception) {
                        android.util.Log.e("NearFixAuth", "Exception during verifyFirebaseCode: ${e.localizedMessage}", e)
                        runOnUiThread { result.success(false) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
