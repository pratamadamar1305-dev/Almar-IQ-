package id.jedasholat.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import id.jedasholat.core.Settings
import id.jedasholat.ui.*
import java.time.ZoneId

internal data class CityPreset(val name: String, val lat: Double, val lng: Double, val zone: String)
internal val cityPresets = listOf(
    CityPreset("Jakarta", -6.2115, 106.8452, "Asia/Jakarta"),
    CityPreset("Bandung", -6.9175, 107.6191, "Asia/Jakarta"),
    CityPreset("Surabaya", -7.2575, 112.7521, "Asia/Jakarta"),
    CityPreset("Yogyakarta", -7.7956, 110.3695, "Asia/Jakarta"),
    CityPreset("Medan", 3.5952, 98.6722, "Asia/Jakarta"),
    CityPreset("Makassar", -5.1477, 119.4327, "Asia/Makassar"),
    CityPreset("Denpasar", -8.6705, 115.2126, "Asia/Makassar"),
    CityPreset("Jayapura", -2.5337, 140.7181, "Asia/Jayapura"),
)

internal data class LocationChoice(val label: String, val lat: Double, val lng: Double, val zone: String)

@Composable internal fun LocationDialog(settings: Settings, onDismiss: () -> Unit, onSave: (LocationChoice) -> Unit) {
    var tab by remember { mutableStateOf("city") }
    var label by remember { mutableStateOf(settings.locationLabel) }
    var lat by remember { mutableStateOf(settings.latitude.toString()) }
    var lng by remember { mutableStateOf(settings.longitude.toString()) }
    var zone by remember { mutableStateOf(settings.zoneId) }
    var error by remember { mutableStateOf<String?>(null) }
    AlertDialog(onDismissRequest = onDismiss, icon = { JedaIcon(JedaGlyph.PIN, tint = MaterialTheme.colorScheme.primary) },
        title = { Text("Lokasi jadwal") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Pilih kota terdekat atau masukkan koordinat. Cocokkan hasilnya dengan jadwal setempat.", style = MaterialTheme.typography.bodyMedium)
                SegmentedTabs(listOf("city" to "Kota", "manual" to "Koordinat"), tab) { tab = it; error = null }
                if (tab == "city") {
                    LazyColumn(Modifier.heightIn(max = 320.dp)) {
                        items(cityPresets, key = { it.name }) { city ->
                            Surface(onClick = { onSave(LocationChoice(city.name, city.lat, city.lng, city.zone)) }, color = androidx.compose.ui.graphics.Color.Transparent,
                                shape = MaterialTheme.shapes.small, modifier = Modifier.fillMaxWidth()) {
                                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Column(Modifier.weight(1f)) { Text(city.name, style = MaterialTheme.typography.titleSmall); Text(city.zone, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                                    if (settings.locationLabel == city.name) JedaIcon(JedaGlyph.CHECK, modifier = Modifier.size(19.dp), tint = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                } else {
                    OutlinedTextField(label, { label = it; error = null }, label = { Text("Nama lokasi") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedTextField(lat, { lat = it; error = null }, label = { Text("Lintang") }, singleLine = true, modifier = Modifier.weight(1f))
                        OutlinedTextField(lng, { lng = it; error = null }, label = { Text("Bujur") }, singleLine = true, modifier = Modifier.weight(1f))
                    }
                    OutlinedTextField(zone, { zone = it; error = null }, label = { Text("Zona waktu IANA") }, singleLine = true,
                        supportingText = { Text("Contoh: Asia/Jakarta") }, modifier = Modifier.fillMaxWidth())
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            if (tab == "manual") TextButton(onClick = {
                val la = lat.toDoubleOrNull(); val lo = lng.toDoubleOrNull()
                val validZone = runCatching { ZoneId.of(zone.trim()) }.isSuccess
                when {
                    la == null || la !in -90.0..90.0 -> error = "Lintang harus angka antara −90 dan 90."
                    lo == null || lo !in -180.0..180.0 -> error = "Bujur harus angka antara −180 dan 180."
                    !validZone -> error = "Zona waktu belum valid. Gunakan contoh Asia/Jakarta."
                    else -> onSave(LocationChoice(label.trim().ifBlank { "Lokasi manual" }, la, lo, zone.trim()))
                }
            }) { Text("Simpan lokasi") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Tutup") } })
}
