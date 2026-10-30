package id.jedasholat.service

import android.accessibilityservice.AccessibilityService
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import id.jedasholat.app.JedaApplication
import id.jedasholat.core.*
import id.jedasholat.data.toDomain
import id.jedasholat.domain.AppCatalog
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlin.math.max

/**
 * User-confirmed digital wellbeing service, NOT a disability tool.
 * Only package names from window-state events are read. No window content, keys or gestures.
 * The overlay exists only while a selected app is covered by an active session.
 */
class JedaAccessibilityService : AccessibilityService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val handler = Handler(Looper.getMainLooper())
    private var settings = Settings()
    private var sessions = emptyList<Session>()
    private var foreground = ""
    private var shownKey = ""
    private var lastAnnouncedMinute = -1
    private var overlay: View? = null
    private var timerText: TextView? = null
    private var titleText: TextView? = null
    private var safety = emptySet<String>()
    private val dismissed = mutableSetOf<String>()
    private val container get() = (application as JedaApplication).container
    private val ticker = object : Runnable {
        override fun run() {
            if (overlay == null) return
            evaluate()
            if (overlay != null) handler.postDelayed(this, 1_000L)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        safety = AppCatalog.safetyPackages(this)
        scope.launch {
            settings = container.settings.settings.first()
            foreground = initialForeground()
            runCatching { container.coordinator.reconcile() }
            combine(container.settings.settings, container.database.sessions().observe()) { s, rows ->
                s to rows.map { it.toDomain() }
            }.collect { (s, rows) ->
                settings = s; sessions = rows
                evaluate()
            }
        }
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        foreground = pkg
        evaluate()
    }
    override fun onInterrupt() { hide() }
    override fun onDestroy() {
        hide(); scope.cancel(); super.onDestroy()
    }
    private fun initialForeground(): String {
        // Optional fallback is disclosed separately; never silently enable Usage Access.
        val ops = getSystemService(AppOpsManager::class.java)
        val allowed = runCatching { ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED }.getOrDefault(false)
        if (!allowed || !settings.usageConsent) return ""
        val now = System.currentTimeMillis()
        return runCatching {
            val events = getSystemService(UsageStatsManager::class.java).queryEvents(now - 60 * 60_000L, now)
            var result = ""; val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) result = event.packageName
            }
            result
        }.getOrDefault("")
    }
    private fun evaluate() {
        val now = System.currentTimeMillis()
        val locked = getSystemService(KeyguardManager::class.java).isKeyguardLocked
        val audio = getSystemService(AudioManager::class.java)
        val inCall = audio.mode == AudioManager.MODE_IN_CALL || audio.mode == AudioManager.MODE_IN_COMMUNICATION
        val decision = if (locked || inCall || !settings.accessibilityConsent) Decision.Allow else PolicyEngine.decide(
            foreground, packageName, safety, settings, sessions, now, dismissed)
        when (decision) {
            Decision.Allow -> hide()
            is Decision.Remind -> show(decision.session, false)
            is Decision.Block -> show(decision.session, true)
        }
    }
    private fun show(session: Session, strict: Boolean) {
        val key = "${session.id}:$strict:$foreground"
        if (overlay != null && shownKey != key) hide()
        shownKey = key
        if (overlay == null) {
            val context = this
            val density = resources.displayMetrics.density
            fun dp(value: Int) = (value * density).toInt()
            val content = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
                setPadding(dp(24), dp(28), dp(24), dp(28)); setBackgroundColor(Color.rgb(18, 63, 53))
                isClickable = true; isFocusable = true
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
            fun label(text: String, size: Float, color: Int = Color.rgb(245, 241, 232)) = TextView(context).apply {
                this.text = text; textSize = size; setTextColor(color); gravity = Gravity.CENTER
                setPadding(0, 12, 0, 12)
            }
            content.addView(label("JEDA SHOLAT", 13f, Color.rgb(201, 169, 106)))
            titleText = label("Waktunya jeda sebentar.", 28f).apply { typeface = Typeface.DEFAULT_BOLD }
            content.addView(titleText)
            content.addView(label("Tarik napas. Hanya aplikasi pilihanmu yang sedang dibatasi.", 16f))
            timerText = label("", 44f).apply { typeface = Typeface.MONOSPACE }
            content.addView(timerText)
            if (!strict) {
                content.addView(Button(context).apply {
                    text = if (!session.snoozeUsed) "Tunda 5 menit (1×)" else "Lanjut tanpa pengingat"
                    setOnClickListener {
                        if (!session.snoozeUsed) {
                            scope.launch { runCatching { container.coordinator.snooze(session.id) } }
                        } else {
                            dismissed.add(session.id); hide(); evaluate()
                        }
                    }
                })
            }
            content.addView(Button(context).apply {
                text = "Kembali ke layar utama"; setOnClickListener {
                    hide(); performGlobalAction(GLOBAL_ACTION_HOME)
                }
            })
            content.addView(Button(context).apply {
                text = "Buka telepon / darurat"; setOnClickListener {
                    hide(); runCatching { startActivity(Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                }
            })
            content.addView(label(if (strict) "Mode Tegas bukan kunci permanen. Izin Android tetap dapat dicabut." else "Kamu tetap memegang kendali. Jeda selesai otomatis.", 12f))
            val root = ScrollView(context).apply {
                isFillViewport = true; setBackgroundColor(Color.rgb(18, 63, 53)); addView(content)
            }
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.OPAQUE).apply { gravity = Gravity.CENTER }
            runCatching {
                getSystemService(WindowManager::class.java).addView(root, params)
                overlay = root
                handler.removeCallbacks(ticker); handler.post(ticker)
            }.onFailure { hide() }
        }
        val remaining = max(0L, session.end - System.currentTimeMillis())
        val seconds = (remaining + 999L) / 1000L
        timerText?.text = "%02d:%02d".format(seconds / 60, seconds % 60)
        titleText?.text = if (strict) "Jeda ${session.prayer.label}" else "Waktunya jeda sebentar."
        val minutes = (seconds / 60).toInt()
        if (minutes != lastAnnouncedMinute) {
            lastAnnouncedMinute = minutes
            overlay?.announceForAccessibility("Jeda ${session.prayer.label}, tersisa $minutes menit")
        }
    }
    private fun hide() {
        handler.removeCallbacks(ticker)
        overlay?.let { runCatching { getSystemService(WindowManager::class.java).removeViewImmediate(it) } }
        overlay = null; timerText = null; titleText = null; shownKey = ""; lastAnnouncedMinute = -1
    }
}
