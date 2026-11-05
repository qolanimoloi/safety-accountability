package com.example.safety_accountability

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.ceil

/**
 * Full-screen red countdown shown over the lock screen. It only DISPLAYS the
 * countdown; the service owns the real timer. Cancel tells the service to stop.
 */
class CountdownActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private var deadline = 0L
    private lateinit var numberView: TextView
    private lateinit var subtitleView: TextView
    private var finishing = false

    private val updater = object : Runnable {
        override fun run() {
            val left = deadline - System.currentTimeMillis()
            if (left <= 0) {
                numberView.text = "…"
                subtitleView.text = "Sending your alert and location now"
                if (!finishing) {
                    finishing = true
                    handler.postDelayed({ finish() }, 4000)
                }
                return
            }
            numberView.text = ceil(left / 1000.0).toInt().toString()
            handler.postDelayed(this, 200)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        deadline = intent.getLongExtra(QuickSosService.EXTRA_DEADLINE, System.currentTimeMillis() + 3000)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#B91C1C"))
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = "SOS ALERT"
            setTextColor(Color.WHITE)
            textSize = 26f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        subtitleView = TextView(this).apply {
            text = "Sending your live location to admin"
            setTextColor(Color.parseColor("#FEE2E2"))
            textSize = 16f
            gravity = Gravity.CENTER
        }
        numberView = TextView(this).apply {
            text = "3"
            setTextColor(Color.WHITE)
            textSize = 120f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        val cancel = Button(this).apply {
            text = "CANCEL"
            textSize = 22f
            setTextColor(Color.parseColor("#B91C1C"))
            setBackgroundColor(Color.WHITE)
            setPadding(40, 36, 40, 36)
            setOnClickListener {
                startService(Intent(this@CountdownActivity, QuickSosService::class.java).setAction(QuickSosService.ACTION_CANCEL))
                finish()
            }
        }

        root.addView(title)
        root.addView(numberView)
        root.addView(subtitleView)
        root.addView(
            cancel,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = 72
            }
        )
        setContentView(root)
        handler.post(updater)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    // Back does nothing: only CANCEL stops the alert, so it can't be dismissed by accident.
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {}
}