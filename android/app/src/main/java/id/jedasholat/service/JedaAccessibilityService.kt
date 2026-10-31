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
import id.jedasholat.domain.EnforcementDiagnostics
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlin.math.max

/**
 * User-confirmed digital wellbeing service, NOT a disability tool.
 * Only package names from window-state events are read. No window content, keys or gestures.
 * The overlay exists only while a selected app is covered by an active session.
 *
 * Foreground tracking is sticky: SystemUI, IME, recents, and our own overlay do not erase
 * the last real app. The ticker keeps running while the service is bound, even when the
 * overlay is hidden, so a transient window cannot permanently dismiss an active jeda.
 */
class JedaAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var bound: Boolean = false
            private set
    }

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
    private var classifier = ForegroundClassifier("", "")
    private val dismissed = mutableSetOf<String>()
    private var lastClassifierRefresh = 0L
    private var lastReconcile = 0L
    private var lastUsagePoll = 0L
    private var ticking = false
    private val container get() = (application as JedaApplication).container

    private val ticker = object : Runnable {
        override fun run() {
            if (!bound) { ticking = false; return }
            val now = System.currentTimeMillis()
            if (now - lastClassifierRefresh > 30_000L) refreshClassifier()
            pollUsageForeground(now)
            maybeReconcile(now)
            evaluate()
            val active = SessionEngine.active(sessions, now).isNotEmpty()
            handler.postDelayed(this, if (overlay != null || active) 1_000L else 3_000L)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        bound = true
        android.util.Log.i("JedaService", "service connected")
        EnforcementDiagnostics.update { it.copy(serviceBound = true, lastError = "") }
        EnforcementDiagnostics.note("service connected")
        refreshClassifier()
        startTicker()
        scope.launch {
            settings = container.settings.settings.first()
            foreground = initialForeground()
            runCatching { container.coordinator.reconcile() }
                .onFailure { recordError("reconcile", it) }
            combine(container.settings.settings, container.database.sessions().observe()) { s, rows ->
                s to rows.map { it.toDomain() }
            }.collect { (s, rows) ->
                settings = s; sessions = rows
                evaluate()
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !bound) return
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val pkg = event.packageName?.toString()
                val cls = event.className?.toString()
                val kind = classifier.classify(pkg, cls)
                EnforcementDiagnostics.update {
                    it.copy(lastEventType = "WINDOW_STATE_CHANGED", lastEventPackage = pkg.orEmpty(), lastEventClass = cls.orEmpty())
                }
                if (kind == ForegroundEvent.APP) {
                    foreground = pkg!!.trim()
                    EnforcementDiagnostics.note("foreground -> $foreground")
                } else {
                    EnforcementDiagnostics.note("ignored transient ${pkg.orEmpty()} ($kind), keep $foreground")
                }
                evaluate()
            }
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                EnforcementDiagnostics.update { it.copy(lastEventType = "WINDOWS_CHANGED") }
                pollUsageForeground(System.currentTimeMillis())
                evaluate()
            }
        }
    }

    override fun onInterrupt() {
        EnforcementDiagnostics.note("onInterrupt: re-evaluate instead of dropping active session")
        evaluate()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        bound = false
        EnforcementDiagnostics.update { it.copy(serviceBound = false) }
        EnforcementDiagnostics.note("service unbound")
        stopTicker(); hide("service_unbound")
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        bound = false
        EnforcementDiagnostics.update { it.copy(serviceBound = false) }
        stopTicker(); hide("service_destroyed"); scope.cancel()
        super.onDestroy()
    }

    private fun startTicker() {
        if (ticking) return
        ticking = true
        handler.removeCallbacks(ticker)
        handler.post(ticker)
    }

    private fun stopTicker() {
        ticking = false
        handler.removeCallbacks(ticker)
    }

    private fun refreshClassifier() {
        lastClassifierRefresh = System.currentTimeMillis()
        safety = AppCatalog.safetyPackages(this)
        classifier = ForegroundClassifier(
            ownPackage = packageName,
            ownActivity = "id.jedasholat.app.MainActivity",
            imePackages = AppCatalog.imePackages(this),
            safetyPackages = safety,
            launchablePackages = AppCatalog.launchablePackages(this),
        )
    }

    private fun usageAllowed(): Boolean {
        if (!settings.usageConsent) return false
        val ops = getSystemService(AppOpsManager::class.java)
        return runCatching {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
        }.getOrDefault(false)
    }

    private fun initialForeground(): String {
        if (!usageAllowed()) return ""
        val now = System.currentTimeMillis()
        return runCatching {
            val events = getSystemService(UsageStatsManager::class.java).queryEvents(now - 60 * 60_000L, now)
            var result = ""; val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND || event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    result = classifier.reduceUsage(result, event.packageName)
                }
            }
            result
        }.getOrDefault("")
    }

    private fun pollUsageForeground(now: Long) {
        if (!usageAllowed() || now - lastUsagePoll < 1_000L) return
        val from = if (lastUsagePoll == 0L) now - 10_000L else lastUsagePoll
        lastUsagePoll = now
        runCatching {
            val events = getSystemService(UsageStatsManager::class.java).queryEvents(from, now)
            var result = foreground; val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND || event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    result = classifier.reduceUsage(result, event.packageName)
                }
            }
            if (result != foreground) {
                foreground = result
                EnforcementDiagnostics.note("usage foreground -> $foreground")
            }
            EnforcementDiagnostics.update { it.copy(lastUsagePollAt = now, usageAccess = true) }
        }.onFailure { recordError("usage-poll", it) }
    }

    private fun maybeReconcile(now: Long) {
        if (!settings.protectionEnabled) return
        val due = sessions.any {
            (it.status == SessionStatus.SCHEDULED && now >= it.start && now < it.end) ||
                (it.status == SessionStatus.ACTIVE && now >= it.end) ||
                (it.status == SessionStatus.SNOOZED && (it.snoozedUntil ?: Long.MAX_VALUE) <= now)
        }
        if ((due && now - lastReconcile > 5_000L) || now - lastReconcile > 60_000L) {
            lastReconcile = now
            scope.launch {
                runCatching { container.coordinator.reconcile() }.onFailure { recordError("ticker-reconcile", it) }
                EnforcementDiagnostics.update { it.copy(lastReconcileAt = System.currentTimeMillis()) }
            }
        }
    }

    private fun recordError(where: String, error: Throwable) {
        android.util.Log.e("JedaService", where, error)
        EnforcementDiagnostics.update { it.copy(lastError = "$where: ${error.javaClass.simpleName}: ${error.message}") }
        EnforcementDiagnostics.note("error $where: ${error.message}")
    }

    private fun evaluate() {
        val now = System.currentTimeMillis()
        val locked = getSystemService(KeyguardManager::class.java).isKeyguardLocked
        val audio = getSystemService(AudioManager::class.java)
        val inCall = audio.mode == AudioManager.MODE_IN_CALL || audio.mode == AudioManager.MODE_IN_COMMUNICATION
        val active = SessionEngine.active(sessions, now)
        val decision = if (locked || inCall || !settings.accessibilityConsent) Decision.Allow else PolicyEngine.decide(
            foreground, packageName, safety, settings, sessions, now, dismissed)
        val decisionLabel = when (decision) {
            Decision.Allow -> "Allow"
            is Decision.Remind -> "Remind:${decision.session.id}"
            is Decision.Block -> "Block:${decision.session.id}"
        }
        EnforcementDiagnostics.update {
            it.copy(
                protectionEnabled = settings.protectionEnabled,
                accessibilityConsent = settings.accessibilityConsent,
                selectedCount = settings.selectedPackages.size,
                foreground = foreground,
                lastDecision = decisionLabel,
                activeSessionId = active.firstOrNull()?.id.orEmpty(),
                exactAlarms = android.os.Build.VERSION.SDK_INT < 31 || getSystemService(android.app.AlarmManager::class.java).canScheduleExactAlarms(),
            )
        }
        android.util.Log.d("JedaService", "evaluate foreground=$foreground decision=$decisionLabel active=${active.size} enabled=${settings.protectionEnabled} consent=${settings.accessibilityConsent}")
        when (decision) {
            Decision.Allow -> hide(allowReason(locked, inCall, active))
            is Decision.Remind -> show(decision.session, false)
            is Decision.Block -> show(decision.session, true)
        }
    }

    private fun allowReason(locked: Boolean, inCall: Boolean, active: List<Session>): String = when {
        locked -> "keyguard"
        inCall -> "in_call"
        !settings.accessibilityConsent -> "no_consent"
        !settings.protectionEnabled -> "protection_disabled"
        active.isEmpty() -> "no_active_session"
        foreground.isBlank() -> "no_foreground"
        foreground == packageName -> "own_app"
        foreground in safety -> "safety_app"
        foreground !in settings.selectedPackages -> "unselected_app"
        dismissed.contains(active.first().id) -> "reminder_dismissed"
        else -> "policy_allow"
    }

    private fun show(session: Session, strict: Boolean) {
        val key = "${session.id}:$strict"
        if (overlay != null && shownKey != key) hide("session_changed")
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
                    else { dismissed.add(session.id); hide("reminder_dismissed"); evaluate() }
                }
            }
            action("Kembali ke layar utama", true) { hide("user_home"); performGlobalAction(GLOBAL_ACTION_HOME) }
            action("Buka telepon / darurat", false) {
                hide("user_dialer"); runCatching { startActivity(Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
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
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.OPAQUE).apply { gravity = Gravity.CENTER; windowAnimations = 0 }
            runCatching {
                getSystemService(WindowManager::class.java).addView(root, params)
                android.util.Log.i("JedaService", "overlay added for $foreground session=${session.id}")
                EnforcementDiagnostics.note("overlay added session=${session.id} strict=$strict foreground=$foreground")
                overlay = root
                EnforcementDiagnostics.update { it.copy(overlayVisible = true, lastError = "") }
            }.onFailure {
                recordError("overlay-add", it)
                overlay = null
                EnforcementDiagnostics.update { it.copy(overlayVisible = false) }
            }
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

    private fun hide(reason: String) {
        val hadOverlay = overlay != null
        overlay?.let { runCatching { getSystemService(WindowManager::class.java).removeViewImmediate(it) } }
        overlay = null; timerText = null; titleText = null; progressBar = null; shownKey = ""; lastAnnouncedMinute = -1
        EnforcementDiagnostics.update { it.copy(overlayVisible = false, lastHideReason = reason) }
        if (hadOverlay) {
            android.util.Log.i("JedaService", "overlay hidden reason=$reason foreground=$foreground")
            EnforcementDiagnostics.note("overlay hidden reason=$reason")
        }
    }
}
