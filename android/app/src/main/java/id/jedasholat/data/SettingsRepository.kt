package id.jedasholat.data

import android.content.Context
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import id.jedasholat.core.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.ZoneId

private val Context.store by preferencesDataStore(name = "jeda_settings")

class SettingsRepository(private val context: Context) {
    val settings: Flow<Settings> = context.store.data.map(::decode)

    suspend fun update(transform: (Settings) -> Settings) {
        context.store.edit { p ->
            val s = transform(decode(p))
            p[Keys.onboarding] = s.onboardingCompleted
            p[Keys.enabled] = s.protectionEnabled
            p[Keys.consent] = s.accessibilityConsent
            p[Keys.usageConsent] = s.usageConsent
            p[Keys.lat] = s.latitude; p[Keys.lng] = s.longitude
            p[Keys.label] = s.locationLabel; p[Keys.source] = s.locationSource
            p[Keys.zone] = s.zoneId; p[Keys.hanafi] = s.hanafiAsr
            p[Keys.selected] = s.selectedPackages; p[Keys.whitelist] = s.whitelistPackages
            p[Keys.theme] = s.theme.name; p[Keys.notifications] = s.notifications
            s.rules.forEach { (prayer, r) ->
                p[booleanPreferencesKey("${prayer.name}_enabled")] = r.enabled
                p[intPreferencesKey("${prayer.name}_duration")] = r.durationMinutes
                p[stringPreferencesKey("${prayer.name}_mode")] = r.mode.name
                p[intPreferencesKey("${prayer.name}_offset")] = r.offsetMinutes
                p[intPreferencesKey("${prayer.name}_reminder")] = r.reminderMinutes
            }
        }
    }

    suspend fun clear() { context.store.edit { it.clear() } }

    private object Keys {
        val onboarding = booleanPreferencesKey("onboarding"); val enabled = booleanPreferencesKey("enabled")
        val consent = booleanPreferencesKey("accessibility_consent_v1"); val usageConsent = booleanPreferencesKey("usage_consent_v1")
        val lat = doublePreferencesKey("latitude"); val lng = doublePreferencesKey("longitude")
        val label = stringPreferencesKey("location_label"); val source = stringPreferencesKey("location_source")
        val zone = stringPreferencesKey("zone"); val hanafi = booleanPreferencesKey("hanafi")
        val selected = stringSetPreferencesKey("selected"); val whitelist = stringSetPreferencesKey("whitelist")
        val theme = stringPreferencesKey("theme"); val notifications = booleanPreferencesKey("notifications")
    }

    /**
     * Preferences are local and normally written by this app, but a corrupt/edited file must not
     * crash startup. Sanitize field-by-field and fall back to safe defaults instead of throwing.
     */
    private fun decode(p: Preferences): Settings {
        val d = Settings()
        val lat = p[Keys.lat]?.takeIf { it.isFinite() && it in -90.0..90.0 } ?: d.latitude
        val lng = p[Keys.lng]?.takeIf { it.isFinite() && it in -180.0..180.0 } ?: d.longitude
        val zone = p[Keys.zone]?.takeIf { runCatching { ZoneId.of(it) }.isSuccess } ?: d.zoneId
        val whitelist = cleanPackages(p[Keys.whitelist])
        val selected = cleanPackages(p[Keys.selected]) - whitelist
        val rules = Prayer.entries.associateWith { prayer -> decodeRule(p, prayer, d.rules.getValue(prayer)) }
        return Settings(
            onboardingCompleted = p[Keys.onboarding] ?: false,
            protectionEnabled = p[Keys.enabled] ?: false,
            accessibilityConsent = p[Keys.consent] ?: false,
            usageConsent = p[Keys.usageConsent] ?: false,
            latitude = lat, longitude = lng,
            locationLabel = p[Keys.label]?.takeIf { it.isNotBlank() } ?: d.locationLabel,
            locationSource = p[Keys.source]?.takeIf { it == "GPS" || it == "MANUAL" } ?: d.locationSource,
            zoneId = zone, hanafiAsr = p[Keys.hanafi] ?: false,
            selectedPackages = selected, whitelistPackages = whitelist,
            rules = rules,
            theme = runCatching { Theme.valueOf(p[Keys.theme] ?: "") }.getOrDefault(Theme.SYSTEM),
            notifications = p[Keys.notifications] ?: true,
        )
    }

    private fun decodeRule(p: Preferences, prayer: Prayer, fallback: PrayerRule): PrayerRule {
        val enabled = p[booleanPreferencesKey("${prayer.name}_enabled")] ?: fallback.enabled
        val duration = (p[intPreferencesKey("${prayer.name}_duration")] ?: fallback.durationMinutes).coerceIn(1, 120)
        val mode = runCatching { Mode.valueOf(p[stringPreferencesKey("${prayer.name}_mode")] ?: "") }.getOrDefault(fallback.mode)
        val offset = (p[intPreferencesKey("${prayer.name}_offset")] ?: fallback.offsetMinutes).coerceIn(-30, 30)
        val reminder = (p[intPreferencesKey("${prayer.name}_reminder")] ?: fallback.reminderMinutes).coerceIn(0, 30)
        return PrayerRule(enabled, duration, mode, offset, reminder)
    }

    private fun cleanPackages(raw: Set<String>?): Set<String> = raw.orEmpty()
        .map { it.trim() }
        .filter { it.isNotEmpty() && it.length <= 255 && it.none { c -> c.isWhitespace() || c.isISOControl() } }
        .toSet()
}
