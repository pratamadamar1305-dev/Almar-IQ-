package id.jedasholat.core

interface PrayerCalculator {
    /** Return the five prayer start instants, before user offsets. Sunrise is deliberately excluded. */
    fun calculate(date: String, settings: Settings): Map<Prayer, Long>
}

object WindowFactory {
    const val PROFILE = "Indonesia kustom · Subuh 20° / Isya 18° · Ashar standar"
    fun create(date: String, starts: Map<Prayer, Long>, settings: Settings): List<PrayerWindow> =
        Prayer.entries.mapNotNull { prayer ->
            val rule = settings.rules.getValue(prayer)
            val start = starts[prayer]?.plus(rule.offsetMinutes * 60_000L) ?: return@mapNotNull null
            if (!rule.enabled) return@mapNotNull null
            PrayerWindow(date, prayer, start, start + rule.durationMinutes * 60_000L, rule.mode, rule.reminderMinutes)
        }
}
