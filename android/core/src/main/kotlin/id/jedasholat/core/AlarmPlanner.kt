package id.jedasholat.core

/** One alarm boundary. [kind] is stable and per-session so equal timestamps cannot collide. */
data class AlarmEvent(val time: Long, val kind: String) {
    val key: String get() = "$time|$kind"
}

/**
 * Pure alarm planning used by the Android scheduler and unit tests.
 * WorkManager/AlarmManager may still delay delivery; this only guarantees a complete,
 * deterministic registry of the next boundaries we intend to request.
 */
object AlarmPlanner {
    /** Four days of five prayers, start/end/snooze, plus pre-reminders and headroom. */
    const val MAX_EVENTS = 96

    fun plan(
        sessions: List<Session>,
        windows: List<PrayerWindow>,
        now: Long,
        maxEvents: Int = MAX_EVENTS,
    ): List<AlarmEvent> {
        val terminal = setOf(SessionStatus.COMPLETED, SessionStatus.CANCELLED, SessionStatus.MISSED)
        val boundaries = sessions.filter { it.status !in terminal }.flatMap { session ->
            listOfNotNull(
                AlarmEvent(session.start, "START:${session.id}"),
                AlarmEvent(session.end, "END:${session.id}"),
                session.snoozedUntil?.let { AlarmEvent(it, "SNOOZE_END:${session.id}") },
            )
        }
        val byId = sessions.associateBy { it.id }
        val reminders = windows.mapNotNull { window ->
            val session = byId[window.id]
            if (session?.status == SessionStatus.SCHEDULED && window.reminderMinutes > 0) {
                AlarmEvent(window.start - window.reminderMinutes * 60_000L, "REMIND:${window.id}:${window.start}")
            } else null
        }
        return (boundaries + reminders)
            .filter { it.time > now }
            .sortedWith(compareBy({ it.time }, { it.kind }))
            .distinctBy { it.key }
            .take(maxEvents.coerceAtLeast(0))
    }
}
