package id.jedasholat.scheduler

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import id.jedasholat.app.MainActivity
import id.jedasholat.app.R
import id.jedasholat.domain.PermissionReader
import id.jedasholat.app.JedaApplication
import kotlinx.coroutines.flow.first

object Notifications {
    const val CHANNEL = "jeda_events"
    fun init(context: Context) {
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Jeda dan pengingat sholat", NotificationManager.IMPORTANCE_DEFAULT))
    }
    fun send(context: Context, id: Int, title: String, text: String) {
        val settings = kotlinx.coroutines.runBlocking { (context.applicationContext as JedaApplication).container.settings.settings.first() }
        if (!settings.notifications || !PermissionReader.read(context).notifications) return
        val intent = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(context, CHANNEL).setSmallIcon(R.drawable.ic_jeda)
            .setContentTitle(title).setContentText(text).setContentIntent(intent).setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER).setOnlyAlertOnce(true).build()
        runCatching { NotificationManagerCompat.from(context).notify(id, n) }
    }
}
