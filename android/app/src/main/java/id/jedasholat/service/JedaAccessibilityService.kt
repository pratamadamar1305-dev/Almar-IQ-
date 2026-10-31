package id.jedasholat.service

import android.accessibilityservice.AccessibilityService
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.content.res.ColorStateList
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.WindowInsets
import android.widget.ProgressBar
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.FrameLayout
import android.widget.ScrollView
import android.widget.TextView
import id.jedasholat.app.JedaApplication
import id.jedasholat.app.R
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
    private var progressBar: ProgressBar? = null
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
        android.util.Log.i("JedaService", "service connected")
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
        android.util.Log.d("JedaService", "event pkg=$pkg")
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
        android.util.Log.d("JedaService", "evaluate foreground=$foreground decision=$decision sessions=${sessions.size} enabled=${settings.protectionEnabled} consent=${settings.accessibilityConsent} selected=${settings.selectedPackages}")
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
            val mint = Color.rgb(220, 237, 228)
            val ink = Color.rgb(18, 61, 48)
            val muted = Color.rgb(212, 231, 218)
            val semibold = runCatching { resources.getFont(R.font.plus_jakarta_sans_semibold) }.getOrDefault(Typeface.DEFAULT_BOLD)
            val regular = runCatching { resources.getFont(R.font.plus_jakarta_sans_regular) }.getOrDefault(Typeface.DEFAULT)
            val overlayBackground = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.rgb(22, 79, 65), Color.rgb(10, 47, 39)))
            val content = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
                setPadding(dp(28), dp(32), dp(28), dp(32))
                isClickable = true; isFocusable = true
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            }
            fun label(text: String, size: Float, color: Int = Color.rgb(243, 247, 241)) = TextView(context).apply {
                this.text = text; textSize = size; setTextColor(color); gravity = Gravity.CENTER
                typeface = regular; setLineSpacing(dp(4).toFloat(), 1f); setPadding(0, dp(6), 0, dp(6))
            }
            fun action(text: String, primary: Boolean, onClick: () -> Unit) = Button(context).apply {
                this.text = text; isAllCaps = false; textSize = 16f; typeface = semibold
                setTextColor(if (primary) ink else Color.WHITE)
                val shape = GradientDrawable().apply {
                    cornerRadius = dp(16).toFloat()
                    setColor(if (primary) mint else Color.argb(24, 255, 255, 255))
                    if (!primary) setStroke(dp(1), Color.argb(110, 255, 255, 255))
                }
                background = RippleDrawable(ColorStateList.valueOf(Color.argb(55, 255, 255, 255)), shape, null)
                minimumHeight = dp(56); setPadding(dp(16), dp(12), dp(16), dp(12))
                setOnClickListener { onClick() }
                content.addView(this, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(10) })
            }
            content.addView(label("JEDA SHOLAT", 12f, Color.rgb(217, 185, 120)).apply { typeface = semibold; letterSpacing = 0.16f })
            content.addView(label(if (strict) "MODE TEGAS" else "PENGINGAT", 11f, muted).apply {
                typeface = semibold
                background = GradientDrawable().apply { cornerRadius = dp(20).toFloat(); setColor(Color.argb(30, 255, 255, 255)) }
                setPadding(dp(14), dp(6), dp(14), dp(6))
            }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8); bottomMargin = dp(8) })
            titleText = label("Waktunya jeda sebentar.", 30f).apply { typeface = semibold }
            content.addView(titleText)
            content.addView(label("Tarik napas. Hanya aplikasi pilihanmu yang sedang dibatasi.", 15f, muted))
            timerText = label("", 56f).apply { typeface = semibold; fontFeatureSettings = "tnum" }
            content.addView(timerText)
            content.addView(label("sampai jeda selesai", 12f, muted))
            progressBar = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
                max = 1000; progressTintList = ColorStateList.valueOf(mint); progressBackgroundTintList = ColorStateList.valueOf(Color.argb(45, 255, 255, 255))
            }
            content.addView(progressBar, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(5)).apply { topMargin = dp(12); bottomMargin = dp(18) })
            if (!strict) {
                action(if (!session.snoozeUsed) "Tunda 5 menit (1×)" else "Lanjut tanpa pengingat", false) {
                    if (!session.snoozeUsed) scope.launch { runCatching { container.coordinator.snooze(session.id) } }
                    else { dismissed.add(session.id); hide(); evaluate() }
                }
            }
            action("Kembali ke layar utama", true) { hide(); performGlobalAction(GLOBAL_ACTION_HOME) }
            action("Buka telepon / darurat", false) {
                hide(); runCatching { startActivity(Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
            }
            content.addView(label(if (strict) "Mode Tegas bukan kunci permanen. Izin Android tetap dapat dicabut." else "Kamu tetap memegang kendali. Jeda selesai otomatis.", 12f, muted).apply { setPadding(0, dp(18), 0, 0) })
            val root = ScrollView(context).apply {
                isFillViewport = true; this.background = overlayBackground
                addView(content, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT))
                setOnApplyWindowInsetsListener { _, insets ->
                    val bars = if (android.os.Build.VERSION.SDK_INT >= 30) insets.getInsets(WindowInsets.Type.systemBars())
                    else android.graphics.Insets.of(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
                    content.setPadding(dp(28) + bars.left, dp(28) + bars.top, dp(28) + bars.right, dp(28) + bars.bottom)
                    insets
                }
            }
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.OPAQUE).apply { gravity = Gravity.CENTER }
            runCatching {
                getSystemService(WindowManager::class.java).addView(root, params)
                android.util.Log.d("JedaService", "overlay added for $foreground session=${session.id}")
                overlay = root
                handler.removeCallbacks(ticker); handler.post(ticker)
            }.onFailure { android.util.Log.e("JedaService", "overlay add failed", it); hide() }
        }
        val now = System.currentTimeMillis()
        val remaining = max(0L, session.end - now)
        val seconds = (remaining + 999L) / 1000L
        timerText?.text = "%02d:%02d".format(seconds / 60, seconds % 60)
        titleText?.text = if (strict) "Jeda ${session.prayer.label}" else "Waktunya jeda sebentar."
        progressBar?.progress = ((remaining * 1000L) / (session.end - session.start).coerceAtLeast(1L)).toInt().coerceIn(0, 1000)
        val minutes = (seconds / 60).toInt()
        if (minutes != lastAnnouncedMinute) {
            lastAnnouncedMinute = minutes
            overlay?.announceForAccessibility("Jeda ${session.prayer.label}, tersisa $minutes menit")
        }
    }
    private fun hide() {
        handler.removeCallbacks(ticker)
        overlay?.let { runCatching { getSystemService(WindowManager::class.java).removeViewImmediate(it) } }
        overlay = null; timerText = null; titleText = null; progressBar = null; shownKey = ""; lastAnnouncedMinute = -1
    }
}
