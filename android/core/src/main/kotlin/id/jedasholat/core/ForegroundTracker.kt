package id.jedasholat.core

/**
 * Pure foreground-app reducer used by the accessibility service.
 *
 * Android sends window-state events for many things that are not a real app switch:
 * notification shade, recents, IME, system dialogs, and our own overlay. Treating those
 * as the new foreground app both hides the overlay and loses the app the user was in.
 * This reducer keeps the last real app for transient windows, while still letting real
 * safety surfaces (Settings, dialer, package installer, permission controller, home) win.
 *
 * No screen content, view ids, text, or gestures are accepted here — package/class names only.
 */
enum class ForegroundEvent { APP, TRANSIENT, IGNORE }

data class ForegroundClassifier(
    val ownPackage: String,
    val ownActivity: String,
    val imePackages: Set<String> = emptySet(),
    val safetyPackages: Set<String> = emptySet(),
    val launchablePackages: Set<String> = emptySet(),
) {
    fun classify(packageName: String?, className: String? = null): ForegroundEvent {
        val pkg = packageName?.trim().orEmpty()
        if (pkg.isEmpty()) return ForegroundEvent.IGNORE
        if (pkg == ownPackage) {
            // The overlay itself emits window events under our package. Only the real
            // JedaSholat activity should count as "user opened JedaSholat".
            return if (className != null && className.contains(ownActivity)) ForegroundEvent.APP else ForegroundEvent.IGNORE
        }
        if (isTransientSystemPackage(pkg)) return ForegroundEvent.TRANSIENT
        if (pkg in safetyPackages) return ForegroundEvent.APP
        // If we know the launchable universe, unknown packages are usually dialogs,
        // services, or OEM helper windows. Do not let them erase the current app.
        if (launchablePackages.isNotEmpty() && pkg !in launchablePackages) return ForegroundEvent.TRANSIENT
        return ForegroundEvent.APP
    }

    /** Usage-stats events have no class name; our own package there means the real app. */
    fun classifyUsage(packageName: String?): ForegroundEvent {
        val pkg = packageName?.trim().orEmpty()
        if (pkg == ownPackage) return ForegroundEvent.APP
        return classify(pkg, null)
    }

    fun reduce(current: String, packageName: String?, className: String? = null): String =
        when (classify(packageName, className)) {
            ForegroundEvent.APP -> packageName!!.trim()
            ForegroundEvent.TRANSIENT, ForegroundEvent.IGNORE -> current
        }

    fun reduceUsage(current: String, packageName: String?): String =
        when (classifyUsage(packageName)) {
            ForegroundEvent.APP -> packageName!!.trim()
            ForegroundEvent.TRANSIENT, ForegroundEvent.IGNORE -> current
        }

    private fun isTransientSystemPackage(pkg: String): Boolean =
        pkg == "android" || pkg == "com.android.systemui" || pkg.endsWith(".systemui") ||
            pkg in imePackages || pkg.contains("inputmethod") || pkg.contains("keyboard") ||
            pkg == "com.android.internal.app.ChooserActivity"
}
