package com.nearfix.app.nearfix

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

    private var storedVerificationId: String? = null
    private var resendToken: PhoneAuthProvider.ForceResendingToken? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                    val phone = call.argument<String>("phoneNumber") ?: ""
                    val isResend = call.argument<Boolean>("isResend") ?: false

                    if (phone.isEmpty()) {
                        result.success(mapOf(
                            "success" to false,
                            "message" to "Phone number is required"
                        ))
                        return@setMethodCallHandler
                    }

                    android.util.Log.d("NearFixAuth", "sendFirebaseOtp initiated for: $phone (isResend: $isResend)")
                    try {
                        if (FirebaseApp.getApps(this).isEmpty()) {
                            FirebaseApp.initializeApp(this)
                        }
                        val auth = FirebaseAuth.getInstance()
                        var callbackDispatched = false

                        val callbacks = object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
                            override fun onVerificationCompleted(credential: PhoneAuthCredential) {
                                val smsCode = credential.smsCode
                                android.util.Log.d("NearFixAuth", "onVerificationCompleted autoVerified, code: $smsCode")
                                auth.signInWithCredential(credential)
                                    .addOnCompleteListener { signInTask ->
                                        if (signInTask.isSuccessful) {
                                            android.util.Log.d("NearFixAuth", "Auto sign-in successful: ${auth.currentUser?.uid}")
                                        }
                                    }
                                if (!callbackDispatched) {
                                    callbackDispatched = true
                                    result.success(mapOf(
                                        "success" to true,
                                        "autoVerified" to true,
                                        "smsCode" to (smsCode ?: ""),
                                        "message" to "Auto-verified via Google Play Services"
                                    ))
                                }
                            }

                            override fun onVerificationFailed(e: FirebaseException) {
                                android.util.Log.e("NearFixAuth", "onVerificationFailed: ${e.localizedMessage}", e)
                                if (!callbackDispatched) {
                                    callbackDispatched = true
                                    result.success(mapOf(
                                        "success" to false,
                                        "message" to (e.localizedMessage ?: "Firebase verification failed")
                                    ))
                                }
                            }

                            override fun onCodeSent(
                                verificationId: String,
                                token: PhoneAuthProvider.ForceResendingToken
                            ) {
                                android.util.Log.d("NearFixAuth", "onCodeSent verificationId: $verificationId")
                                storedVerificationId = verificationId
                                resendToken = token
                                if (!callbackDispatched) {
                                    callbackDispatched = true
                                    result.success(mapOf(
                                        "success" to true,
                                        "verificationId" to verificationId,
                                        "message" to "Real SMS verification code dispatched from Firebase"
                                    ))
                                }
                            }
                        }

                        val optionsBuilder = PhoneAuthOptions.newBuilder(auth)
                            .setPhoneNumber(phone)
                            .setTimeout(60L, TimeUnit.SECONDS)
                            .setActivity(this)
                            .setCallbacks(callbacks)

                        if (isResend && resendToken != null) {
                            optionsBuilder.setForceResendingToken(resendToken!!)
                        }

                        PhoneAuthProvider.verifyPhoneNumber(optionsBuilder.build())
                    } catch (e: Exception) {
                        android.util.Log.e("NearFixAuth", "Exception starting PhoneAuth: ${e.localizedMessage}", e)
                        result.success(mapOf(
                            "success" to false,
                            "message" to (e.localizedMessage ?: "Failed to initiate Firebase SMS")
                        ))
                    }
                }
                "verifyFirebaseCode" -> {
                    val code = call.argument<String>("code") ?: ""
                    val verificationId = call.argument<String>("verificationId") ?: storedVerificationId ?: ""

                    if (verificationId.isEmpty() || code.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    try {
                        val credential = PhoneAuthProvider.getCredential(verificationId, code)
                        val auth = FirebaseAuth.getInstance()
                        auth.signInWithCredential(credential)
                            .addOnCompleteListener { task ->
                                if (task.isSuccessful) {
                                    val user = auth.currentUser
                                    android.util.Log.d("NearFixAuth", "signInWithCredential SUCCESS. User UID: ${user?.uid}, Phone: ${user?.phoneNumber}")
                                    result.success(true)
                                } else {
                                    android.util.Log.e("NearFixAuth", "signInWithCredential FAILED: ${task.exception?.localizedMessage}")
                                    result.success(false)
                                }
                            }
                    } catch (e: Exception) {
                        android.util.Log.e("NearFixAuth", "Exception during verifyFirebaseCode: ${e.localizedMessage}", e)
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}


