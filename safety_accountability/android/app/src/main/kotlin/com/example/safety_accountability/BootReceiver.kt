package com.example.safety_accountability

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restarts Quick SOS after the phone reboots or the app is updated. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val enabled = context.getSharedPreferences(QuickSosPrefs.NAME, Context.MODE_PRIVATE)
            .getBoolean(QuickSosPrefs.KEY_ENABLED, false)
        if (enabled && QuickSosService.hasLocationPermission(context)) {
            try {
                QuickSosService.start(context)
            } catch (_: Exception) {
                // Some phones block this; the app restarts it the next time it opens.
            }
        }
    }
}