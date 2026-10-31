package id.jedasholat.core

/** Pure domain: no Android calls, wall-clock reads, or hidden global state. All times are epoch milliseconds. */
enum class Prayer(val label: String) { SUBUH("Subuh"), DZUHUR("Dzuhur"), ASHAR("Ashar"), MAGHRIB("Maghrib"), ISYA("Isya") }
enum class Mode { PENGINGAT, TEGAS }
enum class SessionStatus { SCHEDULED, ACTIVE, SNOOZED, COMPLETED, CANCELLED, INTERRUPTED, MISSED }
enum class Theme { SYSTEM, LIGHT, DARK }

data class PrayerRule(
    val enabled: Boolean = true,
    val durationMinutes: Int = 20,
    val mode: Mode = Mode.PENGINGAT,
    val offsetMinutes: Int = 0,
    val reminderMinutes: Int = 5,
) {
    init {
        require(durationMinutes in 1..120) { "Durasi harus 1–120 menit" }
        require(offsetMinutes in -30..30) { "Koreksi harus -30 sampai +30 menit" }
        require(reminderMinutes in 0..30) { "Pengingat harus 0–30 menit" }
    }
}

data class Settings(
    val onboardingCompleted: Boolean = false,
    val protectionEnabled: Boolean = false,
    val accessibilityConsent: Boolean = false,
    val usageConsent: Boolean = false,
    val latitude: Double = -6.2115,
    val longitude: Double = 106.8452,
    val locationLabel: String = "Jakarta",
    val locationSource: String = "MANUAL",
    val zoneId: String = "Asia/Jakarta",
    val hanafiAsr: Boolean = false,
    val selectedPackages: Set<String> = emptySet(),
    val whitelistPackages: Set<String> = emptySet(),
    val rules: Map<Prayer, PrayerRule> = Prayer.entries.associateWith { PrayerRule() },
    val theme: Theme = Theme.SYSTEM,
    val notifications: Boolean = true,
) {
    init {
        require(latitude.isFinite() && latitude in -90.0..90.0)
        require(longitude.isFinite() && longitude in -180.0..180.0)
        require(Prayer.entries.all { rules.containsKey(it) })
    }
}

data class PrayerWindow(
    val date: String,
    val prayer: Prayer,
    val start: Long,
    val end: Long,
    val mode: Mode,
    val reminderMinutes: Int,
) {
    val id: String get() = "$date:${prayer.name}"
    init { require(start < end) { "Jendela waktu tidak valid" } }
}

data class Session(
    val id: String,
    val date: String,
    val prayer: Prayer,
    val start: Long,
    val end: Long,
    val mode: Mode,
    val status: SessionStatus,
    val snoozedUntil: Long? = null,
    val snoozeUsed: Boolean = false,
    val reason: String? = null,
) {
    fun isActiveAt(now: Long): Boolean =
        (status == SessionStatus.ACTIVE || status == SessionStatus.SNOOZED) && now >= start && now < end
}

data class Capabilities(
    val accessibility: Boolean = false,
    val exactAlarms: Boolean = false,
    val notifications: Boolean = false,
    val usageAccess: Boolean = false,
    /** True only while the accessibility service is actually bound, not just listed in Secure settings. */
    val accessibilityBound: Boolean = false,
)
