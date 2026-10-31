package id.jedasholat.domain

import android.Manifest
import android.app.AlarmManager
import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.os.Process
import android.provider.Settings
import androidx.core.content.ContextCompat
import id.jedasholat.core.Capabilities
import id.jedasholat.service.JedaAccessibilityService

object PermissionReader {
    fun read(context: Context): Capabilities {
        val component = ComponentName(context, JedaAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        val accessibility = enabled.split(':').any { ComponentName.unflattenFromString(it) == component }
        val ops = context.getSystemService(AppOpsManager::class.java)
        val usage = runCatching {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName) == AppOpsManager.MODE_ALLOWED
        }.getOrDefault(false)
        return Capabilities(accessibility, (android.os.Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED, usage)
    }
}
