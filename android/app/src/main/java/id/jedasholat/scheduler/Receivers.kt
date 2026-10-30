package id.jedasholat.scheduler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import id.jedasholat.app.JedaApplication
import kotlinx.coroutines.*

class ScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val app = context.applicationContext as JedaApplication
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                app.container.coordinator.reconcile()
                val kind = intent.getStringExtra("kind") ?: ""
                if (kind.startsWith("REMIND:")) {
                    val id = kind.removePrefix("REMIND:").substringBeforeLast(':')
                    val session = app.container.database.sessions().all().firstOrNull { it.id == id }
                    val settings = app.container.settings.settings.let { kotlinx.coroutines.flow.first(it) }
                    val delta = (session?.start ?: 0L) - System.currentTimeMillis()
                    if (session?.status == "SCHEDULED" && settings.protectionEnabled && settings.notifications && delta in -120_000L..31 * 60_000L) {
                        Notifications.send(context, kind.hashCode(), "${session.prayer.label} segera tiba",
                            "Siapkan waktu untuk jeda. Aplikasi pilihanmu akan dibatasi sesuai jadwal.")
                    }
                }
            } finally { pending.finish() }
        }
    }
}
class SystemReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED)) return
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try { (context.applicationContext as JedaApplication).container.coordinator.reconcile() }
            finally { pending.finish() }
        }
    }
}
