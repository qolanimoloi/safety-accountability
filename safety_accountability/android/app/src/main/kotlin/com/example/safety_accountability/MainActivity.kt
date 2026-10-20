package com.example.safety_accountability

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "safety/quick_sos"
    private val notifRequestCode = 9001
    private var pendingNotifResult: MethodChannel.Result? = null

    private fun prefs() = getSharedPreferences(QuickSosPrefs.NAME, Context.MODE_PRIVATE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(prefs().getBoolean(QuickSosPrefs.KEY_ENABLED, false))

                "start" -> {
                    val baseUrl = call.argument<String>("baseUrl")
                    if (baseUrl.isNullOrEmpty() || !QuickSosService.hasLocationPermission(this)) {
                        result.success(false)
                    } else {
                        prefs().edit()
                            .putString(QuickSosPrefs.KEY_BASE_URL, baseUrl)
                            .putBoolean(QuickSosPrefs.KEY_ENABLED, true)
                            .apply()
                        try {
                            QuickSosService.start(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }

                "stop" -> {
                    prefs().edit().putBoolean(QuickSosPrefs.KEY_ENABLED, false).apply()
                    QuickSosService.stop(this)
                    result.success(true)
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        pendingNotifResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notifRequestCode)
                    } else {
                        result.success(true)
                    }
                }

                "allowFullScreenAlert" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= 34) {
                            val nm = getSystemService(NotificationManager::class.java)
                            if (!nm.canUseFullScreenIntent()) {
                                startActivity(
                                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))
                                )
                                result.success(false)
                                return@setMethodCallHandler
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "batteryExemption" -> {
                    try {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            try {
                                startActivity(
                                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
                                )
                            } catch (e: Exception) {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notifRequestCode) {
            pendingNotifResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingNotifResult = null
        }
    }
}