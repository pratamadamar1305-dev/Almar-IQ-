package id.jedasholat.app

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import id.jedasholat.core.Settings
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Native UI regression + screenshot capture. This does not enable AccessibilityService
 * and does not claim enforcement verification; see EnforcementSmokeTest and the device checklist.
 */
@RunWith(AndroidJUnit4::class)
class UiSmokeTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private val container get() = (context.applicationContext as JedaApplication).container
    private val device get() = UiDevice.getInstance(instrumentation)

    @Before fun seed() {
        runBlocking {
            container.database.sessions().clear()
            container.settings.update { Settings().copy(onboardingCompleted = true) }
        }
        compose.waitUntil(8_000) { compose.onAllNodesWithText("Jadwal").fetchSemanticsNodes().isNotEmpty() }
    }

    @After fun reset() {
        runCatching { device.executeShellCommand("settings put system font_scale 1.0") }
        runBlocking { runCatching { container.settings.update { Settings() } } }
    }

    @Test fun mainTabsRenderAndThemeSwitches() {
        compose.onNodeWithText("Beri ruang untuk\nyang utama.").assertExists()
        capture("home-light")
        compose.onNodeWithText("Jadwal").performClick()
        compose.onNodeWithText("Jadwal & aturan").assertExists()
        compose.onNodeWithContentDescription("Atur Dzuhur").performClick()
        compose.onNodeWithText("Durasi jeda").assertExists()
        capture("schedule-expanded")
        compose.onNodeWithText("Aplikasi").performClick()
        compose.onNodeWithText("Aplikasi pilihan").assertExists()
        capture("apps")
        compose.onNodeWithText("Pengaturan").performClick()
        compose.onNodeWithText("Perlindungan aplikasi").assertExists()
        capture("settings")
        compose.onNode(hasScrollAction()).performScrollToNode(hasText("Gelap"))
        compose.onNodeWithText("Gelap").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Beranda").performClick()
        compose.onNodeWithText("Beri ruang untuk\nyang utama.").assertExists()
        capture("home-dark")
    }

    @Test fun onboardingIsScrollableAndSkippable() {
        runBlocking { container.settings.update { it.copy(onboardingCompleted = false) } }
        compose.activityRule.scenario.recreate()
        compose.onNodeWithText("Lewati").assertExists()
        capture("onboarding")
        compose.onNodeWithText("Lanjutkan").performClick()
        compose.onNodeWithText("Pilih kota atau koordinat").assertExists()
        compose.onNodeWithText("Lanjutkan").performClick()
        compose.onNodeWithText("Durasi jeda").assertExists()
        compose.onNodeWithText("Lanjutkan").performClick()
        compose.onNodeWithText("Selesai & lihat beranda").performClick()
        compose.onNodeWithText("Jadwal").assertExists()
    }

    @Test fun largeFontKeepsNavigationReachable() {
        device.executeShellCommand("settings put system font_scale 1.3")
        compose.activityRule.scenario.recreate()
        compose.waitUntil(8_000) { compose.onAllNodesWithText("Jadwal").fetchSemanticsNodes().isNotEmpty() }
        capture("home-large-font")
        compose.onNodeWithText("Aplikasi").performClick()
        compose.onNodeWithText("Aplikasi pilihan").assertExists()
        compose.onNodeWithText("Pengaturan").performClick()
        compose.onNodeWithText("Perlindungan aplikasi").assertExists()
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        val dir = File(context.getExternalFilesDir(null), "ui-screenshots").apply { mkdirs() }
        assertTrue("Screenshot failed: $name", device.takeScreenshot(File(dir, "$name.png")))
    }
}
