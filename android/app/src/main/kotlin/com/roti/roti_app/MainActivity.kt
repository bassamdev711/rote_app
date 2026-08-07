package com.roti.roti_app

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.roti.roti_app/signature"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSignature") {
                try {
                    val signature = getAppSignature()
                    result.success(signature)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get signature: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getAppSignature(): String {
        val pm = context.packageManager
        val packageName = context.packageName
        
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            @Suppress("DEPRECATION")
            info.signatures
        }
        
        if (signatures == null || signatures.isEmpty()) {
            return ""
        }
        
        val md = MessageDigest.getInstance("SHA-256")
        md.update(signatures[0].toByteArray())
        val digest = md.digest()
        
        // Convert to lowercase hex string
        return digest.joinToString("") { "%02x".format(it) }
    }
}
