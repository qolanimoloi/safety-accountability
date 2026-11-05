package com.example.safety_accountability

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

object QuickSosPrefs {
    const val NAME = "quick_sos"
    const val KEY_ENABLED = "enabled"
    const val KEY_BASE_URL = "base_url"
}

/**
 * Foreground service that watches for the screen switching on/off.
 * Pressing the power button three times quickly gives three screen events
 * (off, on, off) inside a couple of seconds. On that pattern it starts a
 * 5-second countdown; if it is not cancelled it sends the alert to the
 * Django backend with the current location.
 */
class QuickSosService : Service() {

    companion object {
        const val ACTION_START = "com.example.safety_accountability.quicksos.START"
        const val ACTION_CANCEL = "com.example.safety_accountability.quicksos.CANCEL"
        const val EXTRA_DEADLINE = "deadline"

        private const val CH_STATUS = "quick_sos_status"
        private const val CH_ALERT = "quick_sos_alert"
        private const val ID_STATUS = 7101
        private const val ID_ALERT = 7102

                private const val PRESS_WINDOW_MS = 3000L
        private const val REQUIRED_PRESSES = 2
        private const val MIN_GAP_MS = 120L
        private const val COUNTDOWN_SECONDS = 3
        private const val COOLDOWN_MS = 30_000L

        fun hasLocationPermission(ctx: Context): Boolean =
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

        fun start(ctx: Context) {
            ContextCompat.startForegroundService(
                ctx,
                Intent(ctx, QuickSosService::class.java).setAction(ACTION_START)
            )
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, QuickSosService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val presses = ArrayDeque<Long>()
    private var countdownActive = false
    private var remaining = 0
    private var deadlineWall = 0L
    private var busyUntil = 0L
    private var receiverRegistered = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != Intent.ACTION_SCREEN_OFF && intent.action != Intent.ACTION_SCREEN_ON) return
            val now = SystemClock.elapsedRealtime()
            if (countdownActive || now < busyUntil) {
                presses.clear()
                return
            }
                       // Some phones send two broadcasts for one press; ignore the echo.
            if (presses.isNotEmpty() && now - presses.last() < MIN_GAP_MS) return
            presses.addLast(now)
            while (presses.isNotEmpty() && now - presses.first() > PRESS_WINDOW_MS) presses.removeFirst()
            if (presses.size >= REQUIRED_PRESSES) {
                presses.clear()
                beginCountdown()
            }
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            if (!countdownActive) return
            remaining -= 1
            if (remaining <= 0) {
                countdownActive = false
                busyUntil = SystemClock.elapsedRealtime() + COOLDOWN_MS
                vibrate(longArrayOf(0, 700))
                postResult("Sending SOS to admin…", "Getting your location and sending the alert.", ongoing = true)
                sendAlert()
            } else {
                postCountdownNotification()
                vibrate(longArrayOf(0, 70))
                handler.postDelayed(this, 1000)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            cancelCountdown()
            return START_STICKY
        }

        createChannels()
        try {
            val notification = buildStatusNotification()
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(ID_STATUS, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(ID_STATUS, notification)
            }
        } catch (e: Exception) {
            // Missing location permission (Android 14 refuses) or similar.
            stopSelf()
            return START_NOT_STICKY
        }

        if (!receiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
            }
            ContextCompat.registerReceiver(this, screenReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (receiverRegistered) {
            try { unregisterReceiver(screenReceiver) } catch (_: Exception) {}
            receiverRegistered = false
        }
        super.onDestroy()
    }

    // ---------- countdown ----------

    private fun beginCountdown() {
        countdownActive = true
        remaining = COUNTDOWN_SECONDS
        deadlineWall = System.currentTimeMillis() + COUNTDOWN_SECONDS * 1000L
        postCountdownNotification()
        vibrate(longArrayOf(0, 200, 100, 200))
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, 1000)
    }

    private fun cancelCountdown() {
        if (!countdownActive) return
        countdownActive = false
        handler.removeCallbacks(tick)
        busyUntil = SystemClock.elapsedRealtime() + 3000L
        presses.clear()
        notificationManager().cancel(ID_ALERT)
        vibrate(longArrayOf(0, 100, 80, 100))
    }

    // ---------- sending ----------

    private fun sendAlert() {
        thread {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val token = flutterPrefs.getString("flutter.auth_token", null)
            val base = getSharedPreferences(QuickSosPrefs.NAME, Context.MODE_PRIVATE)
                .getString(QuickSosPrefs.KEY_BASE_URL, null)?.trimEnd('/')

            if (token.isNullOrEmpty() || base.isNullOrEmpty()) {
                handler.post {
                    postResult("SOS NOT SENT", "You are signed out. Open the app and sign in.", ongoing = false)
                }
                return@thread
            }

            val loc = getLocationBlocking(8000)
            var reference: String? = null
            var unauthorized = false

            for (attempt in 1..4) {
                try {
                    val conn = URL("$base/api/emergencies/trigger/").openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.connectTimeout = 10_000
                    conn.readTimeout = 15_000
                    conn.doOutput = true
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("Authorization", "Token $token")

                    val body = JSONObject()
                        .put("incident_type", "other")
                        .put("location_description", "QUICK SOS - power button x2")
                    if (loc != null) {
                        body.put("latitude", Math.round(loc.latitude * 1e6) / 1e6)
                        body.put("longitude", Math.round(loc.longitude * 1e6) / 1e6)
                    }
                    conn.outputStream.use { it.write(body.toString().toByteArray()) }

                    val code = conn.responseCode
                    if (code in 200..299) {
                        val text = conn.inputStream.bufferedReader().use { it.readText() }
                        reference = try { JSONObject(text).optString("reference", "") } catch (_: Exception) { "" }
                        conn.disconnect()
                        break
                    }
                    if (code == 401 || code == 403) {
                        unauthorized = true
                        conn.disconnect()
                        break
                    }
                    conn.disconnect()
                } catch (_: Exception) {
                    // network problem: retry below
                }
                if (attempt < 4) Thread.sleep(4000)
            }

            handler.post {
                when {
                    reference != null -> {
                        vibrate(longArrayOf(0, 150, 100, 150, 100, 150))
                        val where = if (loc != null) "with your location" else "(location unavailable)"
                        val ref = if (reference.isNullOrEmpty()) "" else " Ref $reference."
                        postResult("SOS SENT TO ADMIN", "Alert sent $where.$ref", ongoing = false)
                    }
                    unauthorized -> postResult("SOS NOT SENT", "Your session expired. Open the app and sign in again.", ongoing = false)
                    else -> postResult("SOS NOT SENT", "No internet or server unreachable. Call 10111 now.", ongoing = false)
                }
            }
        }
    }

    private fun getLocationBlocking(timeoutMs: Long): Location? {
        if (!hasLocationPermission(this)) return null
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val best = AtomicReference<Location?>(null)
        val latch = CountDownLatch(1)

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                val cur = best.get()
                if (cur == null || location.accuracy < cur.accuracy) best.set(location)
                if (location.provider == LocationManager.GPS_PROVIDER || location.accuracy <= 50f) latch.countDown()
            }
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }

        try {
            for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                if (lm.isProviderEnabled(p)) {
                    lm.requestLocationUpdates(p, 0L, 0f, listener, Looper.getMainLooper())
                }
            }
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        } finally {
            try { lm.removeUpdates(listener) } catch (_: Exception) {}
        }

        if (best.get() == null) {
            // Fall back to the last position the phone knows about.
            try {
                best.set(
                    listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
                        .mapNotNull { try { lm.getLastKnownLocation(it) } catch (_: Exception) { null } }
                        .maxByOrNull { it.time }
                )
            } catch (_: Exception) {}
        }
        return best.get()
    }

    // ---------- notifications ----------

    private fun notificationManager() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun piFlags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = notificationManager()
        nm.createNotificationChannel(
            NotificationChannel(CH_STATUS, "Quick SOS status", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shows that Quick SOS is active"
                setShowBadge(false)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_ALERT, "Quick SOS alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "SOS countdown and result"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
        )
    }

    private fun openAppPendingIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        return PendingIntent.getActivity(this, 0, launch, piFlags())
    }

    private fun buildStatusNotification() =
        NotificationCompat.Builder(this, CH_STATUS)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Quick SOS is on")
            .setContentText("Double-press the power button quickly to alert admin.")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openAppPendingIntent())
            .build()

    private fun postCountdownNotification() {
        val cancelPi = PendingIntent.getService(
            this, 1,
            Intent(this, QuickSosService::class.java).setAction(ACTION_CANCEL),
            piFlags()
        )
        val fullPi = PendingIntent.getActivity(
            this, 2,
            Intent(this, CountdownActivity::class.java)
                .putExtra(EXTRA_DEADLINE, deadlineWall)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            piFlags()
        )
        val n = NotificationCompat.Builder(this, CH_ALERT)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("SOS in $remaining s")
            .setContentText("Sending your live location to admin. Tap CANCEL to stop.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setFullScreenIntent(fullPi, true)
            .setContentIntent(fullPi)
            .addAction(0, "CANCEL", cancelPi)
            .build()
        notificationManager().notify(ID_ALERT, n)
    }

    private fun postResult(title: String, text: String, ongoing: Boolean) {
        val n = NotificationCompat.Builder(this, CH_ALERT)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
            .setContentIntent(openAppPendingIntent())
            .build()
        notificationManager().notify(ID_ALERT, n)
    }

    private fun vibrate(pattern: LongArray) {
        try {
            val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
            if (Build.VERSION.SDK_INT >= 26) {
                v.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(pattern, -1)
            }
        } catch (_: Exception) {
        }
    }
}