package id.jedasholat.app

import id.jedasholat.core.*
import id.jedasholat.domain.AdhanCalculator
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class AdhanCalculatorTest {
    private val calculator = AdhanCalculator()
    @Test fun fivePrayersInRequestedZone() {
        listOf("Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura").forEach { zone ->
            val s = Settings(zoneId = zone)
            val times = calculator.calculate("2026-10-30", s)
            assertEquals(5, times.size)
            times.values.forEach { assertEquals("2026-10-30", Instant.ofEpochMilli(it).atZone(ZoneId.of(zone)).toLocalDate().toString()) }
            assertEquals(times.values.toList().sorted(), times.values.toList())
        }
    }
    @Test fun independentOfHostTimezone() {
        val original = java.util.TimeZone.getDefault()
        try {
            val s = Settings()
            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("America/New_York"))
            val a = calculator.calculate("2026-10-30", s)
            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Asia/Tokyo"))
            val b = calculator.calculate("2026-10-30", s)
            assertEquals("New York=$a Tokyo=$b", a, b)
        } finally { java.util.TimeZone.setDefault(original) }
    }
    @Test fun hanafiAsrIsLater() {
        val s = Settings()
        assertTrue(calculator.calculate("2026-10-30", s.copy(hanafiAsr = true)).getValue(Prayer.ASHAR) > calculator.calculate("2026-10-30", s).getValue(Prayer.ASHAR))
    }
    @Test fun leapDaySupported() { assertEquals(5, calculator.calculate("2028-02-29", Settings()).size) }
}
