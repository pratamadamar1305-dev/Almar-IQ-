package id.jedasholat.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import id.jedasholat.core.*
import id.jedasholat.data.toDomain
import id.jedasholat.data.toEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.ZoneId

/**
 * Real accessibility-overlay smoke tests on an emulator.
 * The separate testtarget APK is an ordinary launcher app, not part of JedaSholat.
 * These tests do not prove OEM/Doze reliability; see docs/DEVICE_TEST_CHECKLIST.md.
 */
@RunWith(AndroidJUnit4::class)
class EnforcementSmokeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private val container get() = (context.applicationContext as JedaApplication).container
    private val device get() = UiDevice.getInstance(instrumentation)
    private val targetPackage = "id.jedasholat.testtarget"
    private val service = "id.jedasholat.app/id.jedasholat.service.JedaAccessibilityService"

    @Before fun setUp() {
        val own = context.packageManager.getLaunchIntentForPackage("id.jedasholat.app")
        if (own != null) {
            own.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(own)
            device.wait(Until.hasObject(By.pkg("id.jedasholat.app")), 5000)
        }
        device.pressHome()
        runCatching { shell("appops set id.jedasholat.app ACCESS_RESTRICTED_SETTINGS allow") }
        shell("settings put secure enabled_accessibility_services $service")
        shell("settings put secure accessibility_enabled 1")
        val enabled = android.provider.Settings.Secure.getString(context.contentResolver, android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        assertTrue("Service not enabled: $enabled", enabled.contains(service))
        val dump = shell("dumpsys accessibility")
        assertTrue("Accessibility service not bound. dump=${dump.take(4000)}", dump.contains("JedaAccessibilityService"))
        runBlocking {
            container.database.sessions().clear()
            container.settings.update {
                it.copy(onboardingCompleted = true, protectionEnabled = true, accessibilityConsent = true,
                    selectedPackages = setOf(targetPackage), whitelistPackages = emptySet())
            }
        }
        Thread.sleep(1500)
    }

    @After fun tearDown() {
        runBlocking {
            container.database.sessions().clear()
            container.settings.update { it.copy(protectionEnabled = false, selectedPackages = emptySet()) }
        }
        shell("settings put secure enabled_accessibility_services \"\"")
        shell("settings put secure accessibility_enabled 0")
        device.pressHome()
    }

    @Test fun strictOverlayAppearsOnSelectedAppAndAutoUnlocksWithoutExtending() {
        val now = System.currentTimeMillis()
        val session = session(now, now + 8_000L, Mode.TEGAS)
        runBlocking { container.database.sessions().put(listOf(session.toEntity())) }
        launchTarget()
        assertTrue("Strict overlay did not appear", device.wait(Until.hasObject(By.text("Jeda Dzuhur")), 6000))
        assertFalse("Strict mode must not offer snooze", device.hasObject(By.text("Tunda 5 menit (1×)")))
        assertTrue("Overlay did not auto-unlock at the original end", device.wait(Until.gone(By.text("Jeda Dzuhur")), 12_000))
        assertTrue("Target app was not restored", device.wait(Until.hasObject(By.text("JEDA_TEST_TARGET_FOREGROUND")), 3000))
        runBlocking { container.coordinator.reconcile() }
        val stored = runBlocking { container.database.sessions().all().first().toDomain() }
        assertEquals(session.end, stored.end)
        assertEquals(SessionStatus.COMPLETED, stored.status)
    }

    @Test fun reminderSnoozeIsPersistedOnceAndHidesOverlay() {
        val now = System.currentTimeMillis()
        val session = session(now, now + 10 * 60_000L, Mode.PENGINGAT)
        runBlocking { container.database.sessions().put(listOf(session.toEntity())) }
        launchTarget()
        val snooze = device.wait(Until.findObject(By.text("Tunda 5 menit (1×)")), 6000)
        assertNotNull("Reminder snooze button missing", snooze)
        snooze.click()
        assertTrue("Overlay did not hide after snooze", device.wait(Until.gone(By.text("JEDA SHOLAT")), 5000))
        val stored = runBlocking { container.database.sessions().all().first().toDomain() }
        assertTrue(stored.snoozeUsed)
        assertEquals(SessionStatus.SNOOZED, stored.status)
        assertEquals(session.end, stored.end)
        assertNotNull(stored.snoozedUntil)
    }

    @Test fun unselectedAppIsNeverCovered() {
        runBlocking { container.settings.update { it.copy(selectedPackages = emptySet()) } }
        val now = System.currentTimeMillis()
        runBlocking { container.database.sessions().put(listOf(session(now, now + 60_000L, Mode.TEGAS).toEntity())) }
        launchTarget()
        assertTrue(device.wait(Until.hasObject(By.text("JEDA_TEST_TARGET_FOREGROUND")), 5000))
        Thread.sleep(1200)
        assertFalse("Unselected app was covered", device.hasObject(By.text("JEDA SHOLAT")))
    }

    private fun session(start: Long, end: Long, mode: Mode): Session {
        val date = Instant.ofEpochMilli(start).atZone(ZoneId.of("Asia/Jakarta")).toLocalDate().toString()
        return Session("TEST:$start", date, Prayer.DZUHUR, start, end, mode, SessionStatus.ACTIVE)
    }
    private fun launchTarget() {
        val intent = context.packageManager.getLaunchIntentForPackage(targetPackage)
        assertNotNull("Install testtarget-debug.apk before connected tests", intent)
        intent!!.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK)
        context.startActivity(intent)
    }
    private fun shell(command: String): String {
        instrumentation.uiAutomation.executeShellCommand(command).use { fd ->
            return android.os.ParcelFileDescriptor.AutoCloseInputStream(fd).use { it.readBytes().toString(Charsets.UTF_8) }
        }
    }
}
