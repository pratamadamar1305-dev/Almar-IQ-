package id.jedasholat.core

sealed interface Decision {
    data object Allow : Decision
    data class Remind(val session: Session) : Decision
    data class Block(val session: Session) : Decision
}

object PolicyEngine {
    fun decide(
        packageName: String, ownPackage: String, safetyPackages: Set<String>, settings: Settings,
        sessions: List<Session>, now: Long, dismissedReminders: Set<String> = emptySet(),
    ): Decision {
        if (packageName.isBlank() || packageName == ownPackage || packageName in safetyPackages ||
            packageName in settings.whitelistPackages || packageName !in settings.selectedPackages ||
            !settings.protectionEnabled || !settings.accessibilityConsent
        ) return Decision.Allow
        val active = SessionEngine.active(sessions, now).filter { session ->
            when (session.status) {
                SessionStatus.ACTIVE -> true
                SessionStatus.SNOOZED -> now >= (session.snoozedUntil ?: Long.MAX_VALUE)
                else -> false
            }
        }
        // Safety > whitelist > unselected > strict > reminder. Strict wins overlapping reminders.
        val strict = active.filter { it.mode == Mode.TEGAS }.maxByOrNull { it.end }
        if (strict != null) return Decision.Block(strict)
        val reminder = active.filter { it.mode == Mode.PENGINGAT && it.id !in dismissedReminders }.maxByOrNull { it.end }
        return reminder?.let { Decision.Remind(it) } ?: Decision.Allow
    }
}
