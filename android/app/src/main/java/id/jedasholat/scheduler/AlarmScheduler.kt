package id.jedasholat.scheduler

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.work.*
import id.jedasholat.core.*
import id.jedasholat.domain.PermissionReader
import java.util.concurrent.TimeUnit

class AlarmScheduler(private val context: Context) {
    private val manager = context.getSystemService(AlarmManager::class.java)
    private val registry = context.getSharedPreferences("jeda_alarm_registry", Context.MODE_PRIVATE)

    fun schedule(sessions: List<Session>, windows: List<PrayerWindow>, now: Long) {
        val exact = PermissionReader.read(context).exactAlarms
        val desired = AlarmPlanner.plan(sessions, windows, now).associateBy { it.key }
        val previous = registry.getStringSet("pending", emptySet()) ?: emptySet()

        (previous - desired.keys).forEach { key ->
            val pending = pending(key, create = false)
            if (pending != null) { manager.cancel(pending); pending.cancel() }
        }
        desired.forEach { (key, event) ->
            val pending = pending(key, create = true) ?: return@forEach
            runCatching {
                if (exact) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, event.time, pending)
                else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, event.time, pending)
            }.onFailure { pending.cancel() }
        }

        val editor = registry.edit().putStringSet("pending", desired.keys)
        // Reconciliation can run every minute. Do not replace the one-shot maintenance worker
        // on every tick; the periodic worker and alarm boundaries already provide recovery.
        val lastMaintenance = registry.getLong("last_maintenance", 0L)
        if (now - lastMaintenance > 10 * 60_000L) {
            WorkManager.getInstance(context).enqueueUniqueWork(
                "jeda-maintenance", ExistingWorkPolicy.KEEP,
                OneTimeWorkRequestBuilder<MaintenanceWorker>().build(),
            )
            editor.putLong("last_maintenance", now)
        }
        editor.apply()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "jeda-periodic", ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<MaintenanceWorker>(6, TimeUnit.HOURS).build(),
        )
    }

    fun cancelAll() {
        registry.getStringSet("pending", emptySet())?.toList()?.forEach { key ->
            val pending = pending(key, create = false)
            if (pending != null) { manager.cancel(pending); pending.cancel() }
        }
        registry.edit().clear().apply()
        WorkManager.getInstance(context).cancelUniqueWork("jeda-maintenance")
        WorkManager.getInstance(context).cancelUniqueWork("jeda-periodic")
    }

    private fun pending(key: String, create: Boolean): PendingIntent? {
        val kind = key.substringAfter('|')
        val intent = Intent(context, ScheduleReceiver::class.java)
            .setAction("id.jedasholat.BOUNDARY")
            .putExtra("kind", kind)
        val flags = PendingIntent.FLAG_IMMUTABLE or
            (if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE)
        return PendingIntent.getBroadcast(context, key.hashCode() and 0x7fffffff, intent, flags)
    }
}

class MaintenanceWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = runCatching {
        (applicationContext as id.jedasholat.app.JedaApplication).container.coordinator.reconcile()
        Result.success()
    }.getOrElse { Result.retry() }
}
