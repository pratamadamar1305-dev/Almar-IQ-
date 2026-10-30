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
        val events = sessions.filter { it.status !in setOf(SessionStatus.COMPLETED, SessionStatus.CANCELLED, SessionStatus.MISSED) }
            .flatMap { s -> listOf(s.start to "START", s.end to "END") + listOfNotNull(s.snoozedUntil?.let { it to "SNOOZE_END" }) }
        val reminders = windows.filter { w -> sessions.any { it.id == w.id && it.status == SessionStatus.SCHEDULED } }
            .mapNotNull { w -> if (w.reminderMinutes > 0) (w.start - w.reminderMinutes * 60_000L) to "REMIND:${w.id}:${w.start}" else null }
        val desired = (events + reminders).filter { it.first > now }.distinctBy { it.first }.sortedBy { it.first }.take(40)
            .associate { (time, kind) -> "$time|$kind" to (time to kind) }
        val previous = registry.getStringSet("pending", emptySet()) ?: emptySet()
        (previous - desired.keys).forEach { key ->
            val time = key.substringBefore('|').toLongOrNull() ?: return@forEach
            val kind = key.substringAfter('|')
            val intent = Intent(context, ScheduleReceiver::class.java).setAction("id.jedasholat.BOUNDARY").putExtra("kind", kind)
            val code = key.hashCode() and 0x7fffffff
            val pending = PendingIntent.getBroadcast(context, code, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE)
            if (pending != null) { manager.cancel(pending); pending.cancel() }
        }
        desired.forEach { (key, value) ->
            val (time, kind) = value
            val intent = Intent(context, ScheduleReceiver::class.java).setAction("id.jedasholat.BOUNDARY").putExtra("kind", kind)
            val code = key.hashCode() and 0x7fffffff
            val pending = PendingIntent.getBroadcast(context, code, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            runCatching {
                if (exact) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
                else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
            }.onFailure { pending.cancel() }
        }
        registry.edit().putStringSet("pending", desired.keys).apply()
        WorkManager.getInstance(context).enqueueUniqueWork("jeda-maintenance", ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<MaintenanceWorker>().build())
        WorkManager.getInstance(context).enqueueUniquePeriodicWork("jeda-periodic", ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<MaintenanceWorker>(6, TimeUnit.HOURS).build())
    }
    fun cancelAll() {
        registry.getStringSet("pending", emptySet())?.toList()?.forEach { key ->
            val intent = Intent(context, ScheduleReceiver::class.java).setAction("id.jedasholat.BOUNDARY").putExtra("kind", key.substringAfter('|'))
            val pending = PendingIntent.getBroadcast(context, key.hashCode() and 0x7fffffff, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE)
            if (pending != null) { manager.cancel(pending); pending.cancel() }
        }
        registry.edit().clear().apply()
        WorkManager.getInstance(context).cancelUniqueWork("jeda-maintenance")
        WorkManager.getInstance(context).cancelUniqueWork("jeda-periodic")
    }
}
class MaintenanceWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = runCatching {
        (applicationContext as id.jedasholat.app.JedaApplication).container.coordinator.reconcile()
        Result.success()
    }.getOrElse { Result.retry() }
}
