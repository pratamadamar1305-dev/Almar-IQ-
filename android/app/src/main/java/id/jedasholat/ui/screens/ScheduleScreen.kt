package id.jedasholat.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import id.jedasholat.core.*
import id.jedasholat.ui.*

@Composable fun ScheduleScreen(state: UiState, vm: JedaViewModel) {
    var day by remember { mutableStateOf(0) }
    val date = state.today.plusDays(day.toLong()).toString()
    val windows = remember(date, state.settings) {
        runCatching { WindowFactory.create(date, (vm.getApplication() as id.jedasholat.app.JedaApplication).container.calculator.calculate(date, state.settings), state.settings) }.getOrDefault(emptyList())
    }
    LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            SectionTitle("Atur ritme jedamu", "Durasi bukan lamanya waktu sholat. Jeda selesai otomatis setelah durasi habis.")
            Row { listOf("Kemarin", "Hari ini", "Besok").forEachIndexed { i, label -> TextButton(onClick = { day = i - 1 }) { Text(label, color = if (day == i - 1) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant) } } }
            Text("$date · ${state.settings.zoneId}", fontSize = 13.sp)
            Text(WindowFactory.PROFILE, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        items(Prayer.entries.toList()) { prayer ->
            val rule = state.settings.rules.getValue(prayer)
            val window = windows.firstOrNull { it.prayer == prayer }
            Column {
                if (window != null) Text("${prayer.label} · ${time(window.start, state.zone)}–${time(window.end, state.zone)}", fontSize = 13.sp)
                RuleEditor(prayer, rule) { changed -> vm.update { it.copy(rules = it.rules + (prayer to changed)) } }
            }
        }
        item { JedaCard {
            Text("Perhitungan transparan", style = MaterialTheme.typography.titleLarge)
            Text("Subuh 20°, Isya 18°, Ashar ${if (state.settings.hanafiAsr) "Hanafi" else "standar/Syafi'i"}. Profil kustom, bukan salinan jadwal resmi. Hasil dapat berbeda dari jadwal lokal.", fontSize = 14.sp)
            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                Text("Gunakan Ashar Hanafi", Modifier.weight(1f)); Switch(state.settings.hanafiAsr, { value -> vm.update { it.copy(hanafiAsr = value) } })
            }
            Text("Koreksi per sholat tersedia di atas. Untuk lokasi ekstrem, gunakan referensi setempat dan koreksi manual.", fontSize = 12.sp)
        } }
    }
}
