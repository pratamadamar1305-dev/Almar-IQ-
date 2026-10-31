package id.jedasholat.core

object SessionEngine {
    /** Reconcile persisted state against reality. Never restart a full timer after a reboot. */
    fun reconcile(
        persisted: List<Session>, windows: List<PrayerWindow>, now: Long,
        protectionEnabled: Boolean, enforcementReady: Boolean,
    ): List<Session> {
        val byId = persisted.associateBy { it.id }.toMutableMap()
        for (window in windows) {
            val old = byId[window.id]
            if (old == null) {
                if (window.end > now) byId[window.id] = Session(
                    window.id, window.date, window.prayer, window.start, window.end, window.mode,
                    SessionStatus.SCHEDULED,
                )
            } else if (old.status == SessionStatus.SCHEDULED) {
                // Future session settings may change; a running session keeps its original end/mode.
                byId[window.id] = old.copy(start = window.start, end = window.end, mode = window.mode)
            }
        }
        return byId.values.map { s ->
            if (s.status in setOf(SessionStatus.COMPLETED, SessionStatus.CANCELLED, SessionStatus.MISSED)) return@map s
            when {
                now >= s.end -> s.copy(
                    status = if (s.status == SessionStatus.SCHEDULED) SessionStatus.MISSED
                    else if (s.status == SessionStatus.INTERRUPTED) SessionStatus.INTERRUPTED
                    else SessionStatus.COMPLETED,
                    snoozedUntil = null,
                )
                !protectionEnabled -> if (s.status == SessionStatus.SCHEDULED && now < s.start) s
                    else s.copy(status = SessionStatus.INTERRUPTED, reason = "PROTECTION_DISABLED")
                !enforcementReady -> if (s.status == SessionStatus.SCHEDULED && now < s.start) s
                    else s.copy(status = SessionStatus.INTERRUPTED, reason = "PERMISSION_MISSING")
                now < s.start -> if (s.status == SessionStatus.INTERRUPTED) s.copy(status = SessionStatus.SCHEDULED, reason = null) else s
                s.status == SessionStatus.SNOOZED && now < (s.snoozedUntil ?: s.start) -> s
                else -> s.copy(status = SessionStatus.ACTIVE, snoozedUntil = null, reason = null)
            }
        }.sortedBy { it.start }
    }

    fun snooze(session: Session, now: Long): Session {
        require(session.mode == Mode.PENGINGAT) { "Mode Tegas tidak mendukung tunda" }
        require(session.status == SessionStatus.ACTIVE && session.isActiveAt(now)) { "Sesi tidak aktif" }
        require(!session.snoozeUsed) { "Tunda hanya satu kali per sesi" }
        val until = minOf(session.end, now + 5 * 60_000L)
        return if (until >= session.end) session.copy(status = SessionStatus.COMPLETED)
        else session.copy(status = SessionStatus.SNOOZED, snoozedUntil = until, snoozeUsed = true)
    }

    fun cancel(session: Session, reason: String = "USER_STOPPED"): Session =
        if (session.status in setOf(SessionStatus.COMPLETED, SessionStatus.MISSED)) session
        else session.copy(status = SessionStatus.CANCELLED, reason = reason, snoozedUntil = null)

    fun active(sessions: List<Session>, now: Long): List<Session> = sessions.filter { it.isActiveAt(now) }
}
