package com.chastech.emojirain

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.chastech.emojirain/install_source"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInstallerPackage") {
                    try {
                        val installer: String? =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                // API 30+: getInstallSourceInfo is the modern API
                                val info = packageManager.getInstallSourceInfo(packageName)
                                info.initiatingPackageName ?: info.installingPackageName
                            } else {
                                // API 21–29: deprecated but still correct
                                @Suppress("DEPRECATION")
                                packageManager.getInstallerPackageName(packageName)
                            }
                        result.success(installer)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
