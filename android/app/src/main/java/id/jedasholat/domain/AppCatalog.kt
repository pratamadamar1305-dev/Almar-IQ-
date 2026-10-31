package id.jedasholat.domain

import android.content.Context
import android.content.Intent
import android.graphics.drawable.Drawable
import android.os.Build
import id.jedasholat.core.Settings

data class InstalledApp(val packageName: String, val label: String, val icon: Drawable)
object AppCatalog {
    fun launchable(context: Context): List<InstalledApp> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val safety = safetyPackages(context)
        return pm.queryIntentActivities(intent, 0).mapNotNull {
            val pkg = it.activityInfo.packageName
            if (pkg == context.packageName || pkg in safety) null else
                runCatching { InstalledApp(pkg, it.loadLabel(pm).toString(), it.loadIcon(pm)) }.getOrNull()
        }.distinctBy { it.packageName }.sortedBy { it.label.lowercase() }
    }
    /** Package names only; used by the foreground classifier without loading icons/labels. */
    fun launchablePackages(context: Context): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return context.packageManager.queryIntentActivities(intent, 0)
            .map { it.activityInfo.packageName }.toSet()
    }
    fun imePackages(context: Context): Set<String> = runCatching {
        context.getSystemService(android.view.inputmethod.InputMethodManager::class.java)
            .enabledInputMethodList.map { it.packageName }.toSet()
    }.getOrDefault(emptySet())
    fun safetyPackages(context: Context): Set<String> {
        val pm = context.packageManager
        val result = mutableSetOf("android", "com.android.systemui", "com.android.settings",
            "com.android.permissioncontroller", "com.google.android.permissioncontroller",
            "com.android.packageinstaller", "com.google.android.packageinstaller", "com.android.emergency",
            "com.android.phone", "com.android.server.telecom", "com.android.incallui", "com.google.android.dialer")
        listOf(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), Intent(Intent.ACTION_DIAL),
            Intent("android.intent.action.SHOW_ALARMS")).forEach { intent ->
            pm.queryIntentActivities(intent, 0).forEach { result.add(it.activityInfo.packageName) }
            runCatching { pm.resolveActivity(intent, 0)?.activityInfo?.packageName?.let(result::add) }
        }
        // Default dialer and alarm apps vary by OEM. Never rely only on a fixed vendor list.
        runCatching {
            context.getSystemService(android.telecom.TelecomManager::class.java).defaultDialerPackage?.let(result::add)
        }
        return result
    }
    fun cleanSelection(context: Context, settings: Settings): Settings {
        val installed = launchable(context).map { it.packageName }.toSet()
        return settings.copy(selectedPackages = settings.selectedPackages intersect installed,
            whitelistPackages = settings.whitelistPackages intersect installed)
    }
}
