package id.jedasholat.domain

import android.content.Context
import id.jedasholat.core.*
import id.jedasholat.data.*
import id.jedasholat.scheduler.AlarmScheduler
import id.jedasholat.scheduler.Notifications
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class SessionCoordinator(
    private val context: Context, private val settingsRepository: SettingsRepository,
    private val dao: SessionDao, private val calculator: PrayerCalculator,
) {
    private val mutex = Mutex()
    private val scheduler = AlarmScheduler(context)
    suspend fun reconcile(): List<Session> = mutex.withLock {
        val settings = settingsRepository.settings.first()
        val now = System.currentTimeMillis()
        val capabilities = PermissionReader.read(context)
        val windows = windows(settings, now)
        val old = dao.all().map { it.toDomain() }
        val today = Instant.ofEpochMilli(now).atZone(ZoneId.of(settings.zoneId)).toLocalDate()
        val coveredDates = (-1L..2L).map { today.plusDays(it).toString() }.toSet()
        val ids = windows.map { it.id }.toSet()
        // A disabled future prayer is cancelled, not left as a stale alarm/session.
        val normalized = old.map { if (it.status == SessionStatus.SCHEDULED && it.date in coveredDates && it.id !in ids)
            SessionEngine.cancel(it, "SCHEDULE_CHANGED") else it }
        val result = SessionEngine.reconcile(normalized, windows, now, settings.protectionEnabled,
            settings.accessibilityConsent && capabilities.accessibility)
        dao.put(result.map { it.toEntity() })
        dao.prune(now - 90L * 86_400_000L)
        scheduler.schedule(result, windows, now)
        val previous = old.associateBy { it.id }
        result.filter { it.status == SessionStatus.ACTIVE || it.status == SessionStatus.COMPLETED }
            .filter { previous[it.id]?.status != it.status }.forEach {
                if (it.status == SessionStatus.ACTIVE) Notifications.send(context, it.id.hashCode(),
                    "Jeda ${it.prayer.label} aktif", "Aplikasi pilihanmu beristirahat sebentar. Akses darurat tetap tersedia.")
                else Notifications.send(context, it.id.hashCode(), "Jeda ${it.prayer.label} selesai",
                    "Aplikasi sudah bisa digunakan kembali.")
            }
        result
    }
    suspend fun snooze(id: String) = mutex.withLock {
        val s = dao.all().firstOrNull { it.id == id }?.toDomain() ?: return@withLock
        dao.put(listOf(SessionEngine.snooze(s, System.currentTimeMillis()).toEntity()))
        reconcileUnlocked()
    }
    suspend fun stop() {
        settingsRepository.update { it.copy(protectionEnabled = false) }
        reconcile()
    }
    suspend fun simulate(mode: Mode) = mutex.withLock {
        val settings = settingsRepository.settings.first()
        require(settings.selectedPackages.isNotEmpty()) { "Pilih minimal satu aplikasi dahulu." }
        require(settings.protectionEnabled && settings.accessibilityConsent && PermissionReader.read(context).accessibility) {
            "Aktifkan perlindungan dan izin aksesibilitas dahulu."
        }
        val now = System.currentTimeMillis()
        val date = Instant.ofEpochMilli(now).atZone(ZoneId.of(settings.zoneId)).toLocalDate().toString()
        val s = Session("SIM:$now", date, Prayer.DZUHUR, now, now + 30_000L, mode, SessionStatus.ACTIVE)
        dao.put(listOf(s.toEntity()))
        reconcileUnlocked()
    }
    private fun windows(settings: Settings, now: Long): List<PrayerWindow> {
        val zone = ZoneId.of(settings.zoneId)
        val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        return (-1..2L).flatMap { offset ->
            val date = today.plusDays(offset).toString()
            runCatching { calculator.calculate(date, settings) }
                .map { WindowFactory.create(date, it, settings) }.getOrDefault(emptyList())
        }
    }
    private suspend fun reconcileUnlocked() {
        val settings = settingsRepository.settings.first()
        val now = System.currentTimeMillis()
        val caps = PermissionReader.read(context)
        val result = SessionEngine.reconcile(dao.all().map { it.toDomain() }, emptyList(), now,
            settings.protectionEnabled, settings.accessibilityConsent && caps.accessibility)
        dao.put(result.map { it.toEntity() })
        scheduler.schedule(result, windows(settings, now), now)
    }
}
