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
        val bound = JedaAccessibilityService.bound
        val ops = context.getSystemService(AppOpsManager::class.java)
        val usage = runCatching {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName) == AppOpsManager.MODE_ALLOWED
        }.getOrDefault(false)
        val exact = android.os.Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
        EnforcementDiagnostics.update {
            it.copy(serviceBound = bound, enabledInSettings = accessibility, usageAccess = usage, exactAlarms = exact)
        }
        return Capabilities(
            accessibility = accessibility,
            exactAlarms = exact,
            notifications = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED,
            usageAccess = usage,
            accessibilityBound = bound,
        )
    }
}
