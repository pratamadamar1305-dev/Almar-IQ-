package id.jedasholat.domain

import com.batoulapps.adhan.*
import id.jedasholat.core.Prayer
import id.jedasholat.core.PrayerCalculator
import id.jedasholat.core.Settings
import java.time.LocalDate
import java.time.ZoneId
import com.batoulapps.adhan.data.DateComponents

/** Offline astronomical estimate, NOT an official Kemenag timetable. */
class AdhanCalculator : PrayerCalculator {
    override fun calculate(date: String, settings: Settings): Map<Prayer, Long> {
        val params = CalculationParameters(20.0, 18.0).apply {
            madhab = if (settings.hanafiAsr) Madhab.HANAFI else Madhab.SHAFI
            highLatitudeRule = HighLatitudeRule.TWILIGHT_ANGLE
        }
        val localDate = LocalDate.parse(date)
        // Explicit calendar components avoid the host JVM's default timezone.
        val components = DateComponents(localDate.year, localDate.monthValue, localDate.dayOfMonth)
        val times = PrayerTimes(Coordinates(settings.latitude, settings.longitude), components, params)
        val raw = mapOf(Prayer.SUBUH to times.fajr, Prayer.DZUHUR to times.dhuhr,
            Prayer.ASHAR to times.asr, Prayer.MAGHRIB to times.maghrib, Prayer.ISYA to times.isha)
        // Adhan 1.2.1 rounds to the minute but can leak the host clock's milliseconds.
        // Normalize to whole minutes so results are deterministic across timezones/calls.
        val result = raw.mapNotNull { (prayer, value) -> value?.let { prayer to Math.floorDiv(it.time, 60_000L) * 60_000L } }.toMap()
        check(result.size == 5) { "Jadwal tidak lengkap di lokasi ini. Gunakan koreksi atau referensi setempat." }
        val zone = ZoneId.of(settings.zoneId)
        check(result.all { (_, instant) -> java.time.Instant.ofEpochMilli(instant).atZone(zone).toLocalDate() == localDate }) {
            "Tanggal hasil perhitungan tidak sesuai zona waktu."
        }
        return result
    }
}
