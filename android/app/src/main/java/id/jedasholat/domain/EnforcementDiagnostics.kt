package id.jedasholat.domain

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Local-only, in-memory enforcement diagnostics. No screen content, keystrokes, browsing
 * history, or network calls. The ring buffer keeps the last few package/decision events so
 * a user can copy a useful bug report when an OEM window manager behaves unexpectedly.
 */
data class EnforcementSnapshot(
    val serviceBound: Boolean = false,
    val enabledInSettings: Boolean = false,
    val protectionEnabled: Boolean = false,
    val accessibilityConsent: Boolean = false,
    val usageAccess: Boolean = false,
    val exactAlarms: Boolean = false,
    val selectedCount: Int = 0,
    val foreground: String = "",
    val lastEventPackage: String = "",
    val lastEventClass: String = "",
    val lastEventType: String = "",
    val lastDecision: String = "",
    val overlayVisible: Boolean = false,
    val activeSessionId: String = "",
    val lastHideReason: String = "",
    val lastError: String = "",
    val lastReconcileAt: Long = 0L,
    val lastUsagePollAt: Long = 0L,
    val updatedAt: Long = 0L,
    val events: List<String> = emptyList(),
)

object EnforcementDiagnostics {
    private val formatter = DateTimeFormatter.ofPattern("HH:mm:ss.SSS").withZone(ZoneId.systemDefault())
    private val _state = MutableStateFlow(EnforcementSnapshot())
    val state: StateFlow<EnforcementSnapshot> = _state.asStateFlow()

    fun update(transform: (EnforcementSnapshot) -> EnforcementSnapshot) {
        _state.update { current -> transform(current).copy(updatedAt = System.currentTimeMillis()) }
    }

    fun note(message: String) {
        val line = "${formatter.format(Instant.now())} $message"
        _state.update { current ->
            current.copy(updatedAt = System.currentTimeMillis(), events = (current.events + line).takeLast(40))
        }
    }

    fun dump(): String {
        val s = _state.value
        return buildString {
            appendLine("JedaSholat enforcement diagnostics (local only)")
            appendLine("serviceBound=${s.serviceBound} enabledInSettings=${s.enabledInSettings}")
            appendLine("protection=${s.protectionEnabled} consent=${s.accessibilityConsent} selected=${s.selectedCount}")
            appendLine("usageAccess=${s.usageAccess} exactAlarms=${s.exactAlarms}")
            appendLine("foreground=${s.foreground} overlay=${s.overlayVisible} activeSession=${s.activeSessionId}")
            appendLine("lastEvent=${s.lastEventType} ${s.lastEventPackage}/${s.lastEventClass}")
            appendLine("lastDecision=${s.lastDecision} lastHideReason=${s.lastHideReason}")
            appendLine("lastError=${s.lastError}")
            appendLine("lastReconcileAt=${s.lastReconcileAt} lastUsagePollAt=${s.lastUsagePollAt}")
            appendLine("events:")
            s.events.forEach { appendLine(it) }
        }
    }
}
