package id.jedasholat.core

/** Shared executable checks; also called by JUnit in Gradle/CI. */
object DomainChecks {
    fun run(): Int {
        var count = 0
        fun check(name: String, block: () -> Unit) { block(); count++; println("PASS $name") }
        val start = 1_700_000_000_000L
        val end = start + 20 * 60_000L
        val strict = Session("2026-10-30:DZUHUR", "2026-10-30", Prayer.DZUHUR, start, end, Mode.TEGAS, SessionStatus.ACTIVE)
        val reminder = strict.copy(mode = Mode.PENGINGAT)
        val settings = Settings(protectionEnabled = true, accessibilityConsent = true, selectedPackages = setOf("game", "social"))
        fun decide(pkg: String, s: Settings = settings, sessions: List<Session> = listOf(strict), now: Long = start, dismissed: Set<String> = emptySet()) =
            PolicyEngine.decide(pkg, "self", setOf("dialer", "settings"), s, sessions, now, dismissed)
        check("selected app blocked") { require(decide("game") is Decision.Block) }
        check("unselected app allowed") { require(decide("browser") == Decision.Allow) }
        check("own package allowed") { require(decide("self") == Decision.Allow) }
        check("blank package allowed") { require(decide("") == Decision.Allow) }
        check("system safety wins") { require(decide("dialer") == Decision.Allow) }
        check("settings always allowed") { require(decide("settings") == Decision.Allow) }
        check("user whitelist wins") { require(decide("game", settings.copy(whitelistPackages = setOf("game"))) == Decision.Allow) }
        check("disabled protection allows") { require(decide("game", settings.copy(protectionEnabled = false)) == Decision.Allow) }
        check("no consent allows") { require(decide("game", settings.copy(accessibilityConsent = false)) == Decision.Allow) }
        check("before start allows") { require(decide("game", now = start - 1) == Decision.Allow) }
        check("at start blocks") { require(decide("game", now = start) is Decision.Block) }
        check("at end allows") { require(decide("game", now = end) == Decision.Allow) }
        check("after end allows") { require(decide("game", now = end + 1) == Decision.Allow) }
        check("reminder mode reminds") { require(decide("game", sessions = listOf(reminder)) is Decision.Remind) }
        check("dismissed reminder allows") { require(decide("game", sessions = listOf(reminder), dismissed = setOf(reminder.id)) == Decision.Allow) }
        check("strict wins overlapping reminder") { require(decide("game", sessions = listOf(reminder, strict)) is Decision.Block) }
        check("overlap retains longest end") { val later = strict.copy(id = "later", end = end + 1000); require((decide("game", sessions = listOf(strict, later)) as Decision.Block).session.id == "later") }
        check("future session scheduled") {
            val w = PrayerWindow("2026-10-30", Prayer.DZUHUR, start, end, Mode.TEGAS, 5)
            val result = SessionEngine.reconcile(emptyList(), listOf(w), start - 1000, true, true)
            require(result.single().status == SessionStatus.SCHEDULED)
        }
        val window = PrayerWindow("2026-10-30", Prayer.DZUHUR, start, end, Mode.TEGAS, 5)
        check("start reconciles active") { require(SessionEngine.reconcile(emptyList(), listOf(window), start, true, true).single().status == SessionStatus.ACTIVE) }
        check("boot mid-session keeps original end") { val s = SessionEngine.reconcile(listOf(strict), listOf(window), end - 1000, true, true).single(); require(s.end == end && s.status == SessionStatus.ACTIVE) }
        check("boot after session never relocks") { require(SessionEngine.reconcile(emptyList(), listOf(window), end + 1, true, true).isEmpty()) }
        check("scheduled missed marked missed") { require(SessionEngine.reconcile(listOf(strict.copy(status = SessionStatus.SCHEDULED)), listOf(window), end, true, true).single().status == SessionStatus.MISSED) }
        check("permission loss interrupts") { require(SessionEngine.reconcile(listOf(strict), listOf(window), start, true, false).single().status == SessionStatus.INTERRUPTED) }
        check("disable interrupts") { require(SessionEngine.reconcile(listOf(strict), listOf(window), start, false, true).single().reason == "PROTECTION_DISABLED") }
        check("future remains scheduled when disabled") { require(SessionEngine.reconcile(listOf(strict.copy(status = SessionStatus.SCHEDULED)), listOf(window), start - 1, false, false).single().status == SessionStatus.SCHEDULED) }
        check("permission recovery resumes only remaining time") { val s = SessionEngine.reconcile(listOf(strict.copy(status = SessionStatus.INTERRUPTED)), listOf(window), end - 1000, true, true).single(); require(s.status == SessionStatus.ACTIVE && s.end == end) }
        check("active mode immutable") { val changed = window.copy(mode = Mode.PENGINGAT, end = end + 10000); val s = SessionEngine.reconcile(listOf(strict), listOf(changed), start, true, true).single(); require(s.mode == Mode.TEGAS && s.end == end) }
        check("future settings update") { val changed = window.copy(mode = Mode.PENGINGAT, end = end + 10000); val s = SessionEngine.reconcile(listOf(strict.copy(status = SessionStatus.SCHEDULED)), listOf(changed), start - 1, true, true).single(); require(s.mode == Mode.PENGINGAT && s.end == end + 10000) }
        check("cancel cleans snooze") { require(SessionEngine.cancel(reminder.copy(status = SessionStatus.SNOOZED, snoozedUntil = start + 1)).snoozedUntil == null) }
        check("completed stays completed") { val s = strict.copy(status = SessionStatus.COMPLETED); require(SessionEngine.reconcile(listOf(s), listOf(window), end, true, true).single().status == SessionStatus.COMPLETED) }
        check("snooze lasts five minutes") { val s = SessionEngine.snooze(reminder, start); require(s.snoozedUntil == start + 300_000 && s.snoozeUsed) }
        check("snooze never extends end") { val s = SessionEngine.snooze(reminder, end - 60_000); require(s.end == end && s.status == SessionStatus.COMPLETED) }
        check("snooze suppresses reminder") { val s = SessionEngine.snooze(reminder, start); require(decide("game", sessions = listOf(s)) == Decision.Allow) }
        check("snooze resumes at boundary") { val s = SessionEngine.snooze(reminder, start); val resumed = SessionEngine.reconcile(listOf(s), listOf(window), start + 300_000, true, true).single(); require(resumed.status == SessionStatus.ACTIVE) }
        check("snooze only once even after resume") { val s = SessionEngine.snooze(reminder, start); val resumed = SessionEngine.reconcile(listOf(s), listOf(window), start + 300_000, true, true).single(); require(runCatching { SessionEngine.snooze(resumed, start + 300_000) }.isFailure) }
        check("strict cannot snooze") { require(runCatching { SessionEngine.snooze(strict, start) }.isFailure) }
        check("snoozed session not active before start") { require(!reminder.copy(status = SessionStatus.SNOOZED).isActiveAt(start - 1)) }
        check("sunrise is not a prayer") { require(Prayer.entries.size == 5) }
        check("window applies duration and offset") { val s = settings.copy(rules = settings.rules + (Prayer.DZUHUR to PrayerRule(offsetMinutes = 2, durationMinutes = 15))); val w = WindowFactory.create("2026-10-30", mapOf(Prayer.DZUHUR to start), s).single(); require(w.start == start + 120_000 && w.end == start + 17 * 60_000) }
        check("disabled prayer has no window") { val s = settings.copy(rules = settings.rules + (Prayer.DZUHUR to PrayerRule(enabled = false))); require(WindowFactory.create("x", mapOf(Prayer.DZUHUR to start), s).isEmpty()) }
        check("invalid duration rejected") { require(runCatching { PrayerRule(durationMinutes = 0) }.isFailure) }
        check("invalid offset rejected") { require(runCatching { PrayerRule(offsetMinutes = 31) }.isFailure) }
        check("invalid latitude rejected") { require(runCatching { settings.copy(latitude = 91.0) }.isFailure) }
        check("invalid longitude rejected") { require(runCatching { settings.copy(longitude = Double.NaN) }.isFailure) }
        check("session id stable") { require(window.id == strict.id) }
        check("two sessions do not duplicate") { val result = SessionEngine.reconcile(listOf(strict, strict), listOf(window, window), start, true, true); require(result.size == 1) }

        // 0.3.0 regressions: schedule re-enable, enforcing vs snoozed, and alarm registry planning.
        check("schedule-changed cancellation can be re-enabled before end") {
            val cancelled = strict.copy(status = SessionStatus.CANCELLED, reason = "SCHEDULE_CHANGED")
            val result = SessionEngine.reconcile(listOf(cancelled), listOf(window), start - 1000, true, true).single()
            require(result.status == SessionStatus.SCHEDULED)
        }
        check("schedule-changed cancellation re-enabled mid-window becomes active") {
            val cancelled = strict.copy(status = SessionStatus.CANCELLED, reason = "SCHEDULE_CHANGED")
            val result = SessionEngine.reconcile(listOf(cancelled), listOf(window), start + 1000, true, true).single()
            require(result.status == SessionStatus.ACTIVE && result.end == end)
        }
        check("user-stopped cancellation is not resurrected") {
            val cancelled = strict.copy(status = SessionStatus.CANCELLED, reason = "USER_STOPPED")
            val result = SessionEngine.reconcile(listOf(cancelled), listOf(window), start - 1000, true, true).single()
            require(result.status == SessionStatus.CANCELLED)
        }
        check("re-enable after end does not relock") {
            val cancelled = strict.copy(status = SessionStatus.CANCELLED, reason = "SCHEDULE_CHANGED")
            require(SessionEngine.reconcile(listOf(cancelled), listOf(window), end + 1, true, true).single().status == SessionStatus.CANCELLED)
        }
        check("snoozed session is not enforcing before boundary") {
            val s = SessionEngine.snooze(reminder, start)
            require(SessionEngine.enforcing(listOf(s), start + 1000).isEmpty())
        }
        check("snoozed session enforces at boundary") {
            val s = SessionEngine.snooze(reminder, start)
            require(SessionEngine.enforcing(listOf(s), start + 300_000).single().id == s.id)
        }
        check("active session is enforcing") { require(SessionEngine.enforcing(listOf(strict), start).single().id == strict.id) }
        check("scheduled session is not enforcing") { require(SessionEngine.enforcing(listOf(strict.copy(status = SessionStatus.SCHEDULED)), start).isEmpty()) }

        val other = strict.copy(id = "2026-10-30:ASHAR", prayer = Prayer.ASHAR)
        check("alarm kinds are per-session at equal timestamps") {
            val events = AlarmPlanner.plan(listOf(strict, other), emptyList(), start - 1000)
            val keys = events.map { it.key }
            require(keys.size == keys.toSet().size)
            require(keys.any { it.endsWith("|START:${strict.id}") } && keys.any { it.endsWith("|START:${other.id}") })
            require(keys.any { it.endsWith("|END:${strict.id}") } && keys.any { it.endsWith("|END:${other.id}") })
        }
        check("alarm planner includes snooze boundary") {
            val s = SessionEngine.snooze(reminder, start)
            val events = AlarmPlanner.plan(listOf(s), emptyList(), start)
            require(events.any { it.kind == "SNOOZE_END:${s.id}" && it.time == start + 300_000 })
        }
        check("alarm planner includes scheduled pre-reminder") {
            val scheduled = strict.copy(status = SessionStatus.SCHEDULED)
            val events = AlarmPlanner.plan(listOf(scheduled), listOf(window), start - 10 * 60_000L)
            require(events.any { it.kind == "REMIND:${window.id}:${window.start}" && it.time == start - 5 * 60_000L })
        }
        check("alarm planner skips terminal sessions and past events") {
            val events = AlarmPlanner.plan(listOf(strict.copy(status = SessionStatus.COMPLETED), strict), emptyList(), end)
            require(events.isEmpty())
        }
        check("alarm planner caps registry deterministically") {
            val many = (0 until 80).map { i -> strict.copy(id = "s$i", start = start + i * 1000L, end = end + i * 1000L, status = SessionStatus.SCHEDULED) }
            val events = AlarmPlanner.plan(many, emptyList(), start - 1, maxEvents = 96)
            require(events.size == 96)
            require(events == events.sortedWith(compareBy({ it.time }, { it.kind })))
        }
        // 0.3.1 readiness: "everything on" must still not look ready when nothing is selected.
        val allGranted = Capabilities(accessibility = true, exactAlarms = true, notifications = true, usageAccess = true, accessibilityBound = true)
        check("readiness asks for apps when nothing selected") {
            val r = ReadinessGuide.assess(settings.copy(selectedPackages = emptySet()), allGranted)
            require(r.next == ReadinessStep.APPS); require(!r.ready); require(r.remaining == 1)
            require(!r.steps.first { it.step == ReadinessStep.APPS }.done)
        }
        check("readiness ready only when every step done") {
            require(ReadinessGuide.assess(settings, allGranted).ready)
        }
        check("readiness protection comes first") {
            val r = ReadinessGuide.assess(Settings(), Capabilities())
            require(r.next == ReadinessStep.PROTECTION)
            require(r.nextInfo.action.isNotBlank())
            require(r.remaining == 5)
        }
        check("readiness separates consent from bound service") {
            val r = ReadinessGuide.assess(settings.copy(accessibilityConsent = false), allGranted)
            require(r.next == ReadinessStep.CONSENT)
        }
        check("readiness detects enabled but unbound service") {
            val r = ReadinessGuide.assess(settings, allGranted.copy(accessibility = true, accessibilityBound = false))
            require(r.next == ReadinessStep.SERVICE); require(r.nextInfo.detail.contains("belum tersambung"))
        }
        check("readiness never marks service done without permission") {
            val r = ReadinessGuide.assess(settings, allGranted.copy(accessibility = false, accessibilityBound = false))
            require(r.next == ReadinessStep.ACCESSIBILITY)
        }
        check("readiness steps stay in fixed order") {
            val order = ReadinessGuide.assess(Settings(), Capabilities()).steps.map { it.step }
            require(order == listOf(ReadinessStep.PROTECTION, ReadinessStep.APPS, ReadinessStep.CONSENT,
                ReadinessStep.ACCESSIBILITY, ReadinessStep.SERVICE, ReadinessStep.READY))
        }
        return count
    }
}
fun main() { val count = DomainChecks.run(); println("$count domain checks passed") }
