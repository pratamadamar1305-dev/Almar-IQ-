package id.jedasholat.data

import android.content.Context
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import id.jedasholat.core.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

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
    private fun decode(p: Preferences): Settings {
        val d = Settings()
        return Settings(p[Keys.onboarding] ?: false, p[Keys.enabled] ?: false, p[Keys.consent] ?: false,
            p[Keys.usageConsent] ?: false, p[Keys.lat] ?: d.latitude, p[Keys.lng] ?: d.longitude,
            p[Keys.label] ?: d.locationLabel, p[Keys.source] ?: d.locationSource, p[Keys.zone] ?: d.zoneId,
            p[Keys.hanafi] ?: false, p[Keys.selected] ?: emptySet(), p[Keys.whitelist] ?: emptySet(),
            Prayer.entries.associateWith { prayer ->
                val r = d.rules.getValue(prayer)
                PrayerRule(p[booleanPreferencesKey("${prayer.name}_enabled")] ?: r.enabled,
                    p[intPreferencesKey("${prayer.name}_duration")] ?: r.durationMinutes,
                    runCatching { Mode.valueOf(p[stringPreferencesKey("${prayer.name}_mode")] ?: "") }.getOrDefault(r.mode),
                    p[intPreferencesKey("${prayer.name}_offset")] ?: r.offsetMinutes,
                    p[intPreferencesKey("${prayer.name}_reminder")] ?: r.reminderMinutes)
            }, runCatching { Theme.valueOf(p[Keys.theme] ?: "") }.getOrDefault(Theme.SYSTEM), p[Keys.notifications] ?: true)
    }
}
