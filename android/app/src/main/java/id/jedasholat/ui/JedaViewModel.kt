package id.jedasholat.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import id.jedasholat.app.JedaApplication
import id.jedasholat.core.*
import id.jedasholat.data.toDomain
import id.jedasholat.domain.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class UiState(
    val settings: Settings = Settings(), val sessions: List<Session> = emptyList(),
    val capabilities: Capabilities = Capabilities(), val apps: List<InstalledApp> = emptyList(),
    val now: Long = System.currentTimeMillis(), val loading: Boolean = true,
    val appsLoading: Boolean = true,
    val message: String? = null, val scheduleError: String? = null, val windows: List<PrayerWindow> = emptyList(),
) {
    val zone: ZoneId get() = runCatching { ZoneId.of(settings.zoneId) }.getOrDefault(ZoneId.systemDefault())
    val today: LocalDate get() = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()

    val next: PrayerWindow? get() = windows.firstOrNull { it.start > now }
    /** Only sessions that should actually enforce right now; a snoozed reminder is not "Berjalan". */
    val active: List<Session> get() = SessionEngine.enforcing(sessions, now)
    val snoozed: List<Session> get() = sessions.filter {
        it.status == SessionStatus.SNOOZED && now < (it.snoozedUntil ?: Long.MAX_VALUE) && now < it.end
    }
    val readiness: Readiness get() = ReadinessGuide.assess(settings, capabilities)
    val ready: Boolean get() = readiness.ready
}

private data class ScheduleSnapshot(val windows: List<PrayerWindow> = emptyList(), val error: String? = null)

class JedaViewModel(app: Application) : AndroidViewModel(app) {
    private val container = (app as JedaApplication).container
    private val extra = MutableStateFlow(UiState())

    /**
     * Prayer calculation is deterministic for a given settings + local date. Cache it so the
     * 1-second UI tick does not recalculate Adhan twice per second.
     */
    private val schedule: Flow<ScheduleSnapshot> = combine(container.settings.settings, extra.map { it.now }.distinctUntilChanged()) { settings, now ->
        val zone = runCatching { ZoneId.of(settings.zoneId) }.getOrDefault(ZoneId.systemDefault())
        settings to Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
    }.distinctUntilChanged().map { (settings, today) ->
        runCatching {
            listOf(today, today.plusDays(1)).flatMap { date ->
                WindowFactory.create(date.toString(), container.calculator.calculate(date.toString(), settings), settings)
            }.sortedBy { it.start }
        }.fold(
            onSuccess = { ScheduleSnapshot(it, null) },
            onFailure = { ScheduleSnapshot(emptyList(), it.message ?: "Jadwal belum bisa dihitung.") },
        )
    }

    private val serviceBound: Flow<Boolean> = EnforcementDiagnostics.state
        .map { it.serviceBound }.distinctUntilChanged()

    val state: StateFlow<UiState> = combine(
        container.settings.settings, container.database.sessions().observe(), extra, schedule, serviceBound,
    ) { settings, rows, e, snap, bound ->
        e.copy(
            settings = settings,
            sessions = rows.map { it.toDomain() },
            loading = false,
            capabilities = e.capabilities.copy(accessibilityBound = bound),
            windows = snap.windows,
            scheduleError = snap.error,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), UiState())

    init {
        refresh()
        viewModelScope.launch {
            container.settings.settings.collect { settings ->
                EnforcementDiagnostics.update {
                    it.copy(
                        protectionEnabled = settings.protectionEnabled,
                        accessibilityConsent = settings.accessibilityConsent,
                        selectedCount = settings.selectedPackages.size,
                    )
                }
            }
        }
        viewModelScope.launch {
            while (true) {
                extra.update { it.copy(now = System.currentTimeMillis()) }
                kotlinx.coroutines.delay(1000)
            }
        }
    }

    fun refresh() {
        viewModelScope.launch {
            val application = getApplication<Application>()
            val caps = withContext(Dispatchers.IO) { PermissionReader.read(application) }
            extra.update { it.copy(now = System.currentTimeMillis(), capabilities = caps, appsLoading = true) }
            val apps = withContext(Dispatchers.IO) {
                runCatching { AppCatalog.launchable(application) }.getOrDefault(emptyList())
            }
            if (apps.isNotEmpty()) {
                val installed = apps.map { it.packageName }.toSet()
                runCatching {
                    container.settings.update { old ->
                        val selected = old.selectedPackages intersect installed
                        val whitelist = old.whitelistPackages intersect installed
                        if (selected == old.selectedPackages && whitelist == old.whitelistPackages) old
                        else old.copy(selectedPackages = selected, whitelistPackages = whitelist)
                    }
                }
            }
            extra.update { it.copy(apps = apps, appsLoading = false) }
        }
    }

    fun update(transform: (Settings) -> Settings) = viewModelScope.launch {
        runCatching { container.settings.update(transform) }.onFailure { message(it.message) }
    }

    fun message(text: String?) = extra.update { it.copy(message = text) }

    fun reconcile() = viewModelScope.launch {
        runCatching { container.coordinator.reconcile() }.onFailure { message(it.message) }
        refresh()
    }

    fun stop() = viewModelScope.launch {
        runCatching { container.coordinator.stop() }.onFailure { message(it.message) }
    }

    fun simulate(mode: Mode) = viewModelScope.launch {
        runCatching { container.coordinator.simulate(mode) }
            .onSuccess { message("Simulasi 30 detik dimulai. Buka aplikasi pilihanmu; akses darurat tetap tersedia.") }
            .onFailure { message(it.message) }
    }

    fun deleteHistory() = viewModelScope.launch {
        runCatching {
            container.database.sessions().clearHistory()
            container.coordinator.reconcile()
        }.onSuccess { message("Riwayat sesi dihapus. Sesi aktif/terjadwal tidak dihapus.") }
            .onFailure { message(it.message) }
    }

    fun deleteAll() = viewModelScope.launch {
        runCatching {
            container.settings.clear()
            container.database.sessions().clear()
            getApplication<Application>().getSharedPreferences("jeda_dismissed_reminders", 0).edit().clear().apply()
            id.jedasholat.scheduler.AlarmScheduler(getApplication()).cancelAll()
            container.coordinator.reconcile()
        }.onSuccess { message("Data lokal direset. Layanan Aksesibilitas tetap dikelola melalui Pengaturan Android.") }
            .onFailure { message(it.message) }
    }

    fun locate() = viewModelScope.launch {
        val location = withContext(Dispatchers.IO) { LocationReader.current(getApplication()) }
        if (location == null) {
            message("Lokasi belum tersedia. Izinkan lokasi, aktifkan GPS, atau gunakan kota manual.")
        } else {
            // GPS gives coordinates, not an IANA zone. Keep the user's explicit zone and ask them to verify it.
            update { it.copy(latitude = location.first, longitude = location.second, locationLabel = "Lokasi saya", locationSource = "GPS") }
            message("Lokasi disimpan. Zona waktu tetap ${state.value.settings.zoneId}; periksa bila kamu pindah wilayah.")
        }
    }
}
