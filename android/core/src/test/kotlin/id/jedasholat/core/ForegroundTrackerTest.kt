package id.jedasholat.core

import org.junit.Assert.assertEquals
import org.junit.Test

class ForegroundTrackerTest {
    private val classifier = ForegroundClassifier(
        ownPackage = "id.jedasholat.app",
        ownActivity = "id.jedasholat.app.MainActivity",
        imePackages = setOf("com.google.android.inputmethod.latin", "com.nubia.ime"),
        safetyPackages = setOf("com.android.settings", "com.android.packageinstaller", "com.google.android.dialer", "com.android.launcher"),
        launchablePackages = setOf("com.game", "com.social", "com.browser", "com.android.settings", "com.google.android.dialer", "com.android.launcher"),
    )

    @Test fun systemUiAndImeDoNotEraseSelectedApp() {
        var fg = classifier.reduce("", "com.game", "com.game.Main")
        fg = classifier.reduce(fg, "com.android.systemui", "android.widget.FrameLayout")
        fg = classifier.reduce(fg, "com.google.android.inputmethod.latin", "android.inputmethodservice.SoftInputWindow")
        fg = classifier.reduce(fg, "com.nubia.systemui", null)
        assertEquals("com.game", fg)
    }

    @Test fun ownOverlayDoesNotEraseSelectedAppButRealJedaActivityDoes() {
        var fg = classifier.reduce("", "com.game", null)
        fg = classifier.reduce(fg, "id.jedasholat.app", "android.widget.ScrollView")
        assertEquals("com.game", fg)
        fg = classifier.reduce(fg, "id.jedasholat.app", "id.jedasholat.app.MainActivity")
        assertEquals("id.jedasholat.app", fg)
    }

    @Test fun safetyAndUnselectedAppsReplaceForeground() {
        var fg = classifier.reduce("", "com.game", null)
        fg = classifier.reduce(fg, "com.android.settings", "com.android.settings.Settings")
        assertEquals("com.android.settings", fg)
        fg = classifier.reduce(fg, "com.browser", null)
        assertEquals("com.browser", fg)
        fg = classifier.reduce(fg, "com.google.android.dialer", null)
        assertEquals("com.google.android.dialer", fg)
    }

    @Test fun unknownHelperWindowIsTransientWhenLaunchableUniverseIsKnown() {
        val fg = classifier.reduce("com.game", "com.oem.helper", null)
        assertEquals("com.game", fg)
    }

    @Test fun usageFallbackTreatsOwnPackageAsRealAppAndStillIgnoresSystemUi() {
        var fg = classifier.reduceUsage("", "com.game")
        fg = classifier.reduceUsage(fg, "com.android.systemui")
        assertEquals("com.game", fg)
        fg = classifier.reduceUsage(fg, "id.jedasholat.app")
        assertEquals("id.jedasholat.app", fg)
    }

    @Test fun transientWindowDoesNotChangePolicyDecision() {
        val start = 1_700_000_000_000L
        val session = Session("d:DZUHUR", "d", Prayer.DZUHUR, start, start + 60_000, Mode.TEGAS, SessionStatus.ACTIVE)
        val settings = Settings(protectionEnabled = true, accessibilityConsent = true, selectedPackages = setOf("com.game"))
        var fg = classifier.reduce("", "com.game", null)
        fg = classifier.reduce(fg, "com.android.systemui", null)
        val decision = PolicyEngine.decide(fg, "id.jedasholat.app", classifier.safetyPackages, settings, listOf(session), start)
        assertEquals(true, decision is Decision.Block)
    }
}
