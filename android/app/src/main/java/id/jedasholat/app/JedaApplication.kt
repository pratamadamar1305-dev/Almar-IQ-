package id.jedasholat.app

import android.app.Application
import androidx.room.Room
import id.jedasholat.data.JedaDatabase
import id.jedasholat.data.SettingsRepository
import id.jedasholat.domain.AdhanCalculator
import id.jedasholat.domain.SessionCoordinator
import id.jedasholat.scheduler.Notifications
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.distinctUntilChanged

class JedaApplication : Application() {
    lateinit var container: AppContainer private set
    override fun onCreate() {
        super.onCreate()
        Notifications.init(this)
        container = AppContainer(this)
        container.scope.launch {
            container.settings.settings.distinctUntilChanged().collect {
                runCatching { container.coordinator.reconcile() }
            }
        }
    }
}
class AppContainer(val application: Application) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    val settings = SettingsRepository(application)
    val database = Room.databaseBuilder(application, JedaDatabase::class.java, "jeda.db").build()
    val calculator = AdhanCalculator()
    val coordinator = SessionCoordinator(application, settings, database.sessions(), calculator)
}
