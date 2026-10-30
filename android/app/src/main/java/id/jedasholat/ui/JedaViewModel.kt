package id.jedasholat.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import id.jedasholat.app.JedaApplication
import id.jedasholat.core.*
import id.jedasholat.data.toDomain
import id.jedasholat.domain.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class UiState(
    val settings: Settings = Settings(), val sessions: List<Session> = emptyList(),
    val capabilities: Capabilities = Capabilities(), val apps: List<InstalledApp> = emptyList(),
    val now: Long = System.currentTimeMillis(), val loading: Boolean = true,
    val message: String? = null, val scheduleError: String? = null, val windows: List<PrayerWindow> = emptyList(),
) {
    val zone: ZoneId get() = runCatching { ZoneId.of(settings.zoneId) }.getOrDefault(ZoneId.systemDefault())
    val today: LocalDate get() = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()

    val next: PrayerWindow? get() = windows.firstOrNull { it.start > now }
    val active: List<Session> get() = SessionEngine.active(sessions, now)
    val ready: Boolean get() = settings.protectionEnabled && settings.accessibilityConsent && capabilities.accessibility && settings.selectedPackages.isNotEmpty()
}

class JedaViewModel(app: Application) : AndroidViewModel(app) {
    private val container = (app as JedaApplication).container
    private val extra = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = combine(container.settings.settings, container.database.sessions().observe(), extra) { settings, rows, e ->
        e.copy(settings = settings, sessions = rows.map { it.toDomain() }, loading = false,
            windows = runCatching {
                val today = Instant.ofEpochMilli(e.now).atZone(ZoneId.of(settings.zoneId)).toLocalDate()
                listOf(today, today.plusDays(1)).flatMap { date ->
                    WindowFactory.create(date.toString(), container.calculator.calculate(date.toString(), settings), settings)
                }.sortedBy { it.start }
            }.getOrDefault(emptyList()),
            scheduleError = runCatching {
                val date = Instant.ofEpochMilli(e.now).atZone(ZoneId.of(settings.zoneId)).toLocalDate().toString()
                container.calculator.calculate(date, settings); null
            }.exceptionOrNull()?.message)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), UiState())
    init {
        refresh()
        viewModelScope.launch {
            while (true) {
                extra.update { it.copy(now = System.currentTimeMillis()) }
                kotlinx.coroutines.delay(1000)
            }
        }
    }
    fun refresh() {
        val caps = PermissionReader.read(getApplication())
        extra.update { it.copy(now = System.currentTimeMillis(), capabilities = caps, apps = AppCatalog.launchable(getApplication())) }

    }
    fun update(transform: (Settings) -> Settings) = viewModelScope.launch {
        runCatching { container.settings.update(transform) }.onFailure { message(it.message) }
    }
    fun message(text: String?) = extra.update { it.copy(message = text) }
    fun reconcile() = viewModelScope.launch { runCatching { container.coordinator.reconcile() }.onFailure { message(it.message) }; refresh() }
    fun stop() = viewModelScope.launch { runCatching { container.coordinator.stop() }.onFailure { message(it.message) } }
    fun simulate(mode: Mode) = viewModelScope.launch {
        runCatching { container.coordinator.simulate(mode) }.onSuccess { message("Simulasi 30 detik dimulai. Buka aplikasi pilihanmu; akses darurat tetap tersedia.") }
            .onFailure { message(it.message) }
    }
    fun deleteHistory() = viewModelScope.launch {
        container.database.sessions().clear(); container.coordinator.reconcile(); message("Riwayat sesi dihapus.")
    }
    fun deleteAll() = viewModelScope.launch {
        container.settings.clear(); container.database.sessions().clear()
        id.jedasholat.scheduler.AlarmScheduler(getApplication()).cancelAll()
        container.coordinator.reconcile()
        message("Data lokal direset. Layanan Aksesibilitas tetap dikelola melalui Pengaturan Android.")
    }
    fun locate() = viewModelScope.launch {
        val location = LocationReader.current(getApplication())
        if (location == null) message("Lokasi belum tersedia. Izinkan lokasi, aktifkan GPS, atau gunakan kota manual.")
        else update { it.copy(latitude = location.first, longitude = location.second, locationLabel = "Lokasi saya", locationSource = "GPS", zoneId = ZoneId.systemDefault().id) }
    }
}
