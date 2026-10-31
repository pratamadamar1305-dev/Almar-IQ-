package id.jedasholat.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import id.jedasholat.core.*
import id.jedasholat.ui.*
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable fun ScheduleScreen(state: UiState, vm: JedaViewModel) {
    var day by rememberSaveable { mutableStateOf(0) }
    val date = state.today.plusDays(day.toLong())
    val calculation = remember(date.toString(), state.settings) {
        runCatching {
            val calculator = (vm.getApplication() as id.jedasholat.app.JedaApplication).container.calculator
            WindowFactory.create(date.toString(), calculator.calculate(date.toString(), state.settings), state.settings)
        }
    }
    val windows = calculation.getOrDefault(emptyList())
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Jadwal & aturan", style = MaterialTheme.typography.headlineMedium)
                Text("Atur ritme jedamu. Durasi jeda bukan lamanya waktu sholat.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        item {
            SegmentedTabs(listOf("-1" to "Kemarin", "0" to "Hari ini", "1" to "Besok"), day.toString()) { day = it.toInt() }
        }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(date.format(DateTimeFormatter.ofPattern("EEEE, d MMMM", Locale("id", "ID"))), style = MaterialTheme.typography.titleSmall)
                Text(state.settings.zoneId, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (calculation.isFailure) item {
            JedaCard(color = MaterialTheme.colorScheme.errorContainer) {
                Text("Jadwal belum bisa dihitung", style = MaterialTheme.typography.titleMedium)
                Text(calculation.exceptionOrNull()?.message ?: "Periksa lokasi dan zona waktu.", style = MaterialTheme.typography.bodySmall)
            }
        }
        items(Prayer.entries.toList(), key = { it.name }) { prayer ->
            val rule = state.settings.rules.getValue(prayer)
            val window = windows.firstOrNull { it.prayer == prayer }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                RuleEditor(prayer, rule, { changed -> vm.update { it.copy(rules = it.rules + (prayer to changed)) } }, window, zone = state.zone)
                if (window != null && rule.enabled) Text("Jendela ${time(window.start, state.zone)}–${time(window.end, state.zone)}",
                    Modifier.padding(start = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        item {
            JedaCard(outlined = true) {
                SectionTitle("Perhitungan transparan")
                Text("Subuh 20°, Isya 18°. Profil Indonesia kustom, bukan salinan jadwal resmi. Hasil dapat berbeda dari jadwal lokal.",
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Ashar Hanafi", style = MaterialTheme.typography.titleSmall)
                        Text(if (state.settings.hanafiAsr) "Bayangan lebih panjang" else "Standar / Syafi'i", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Switch(state.settings.hanafiAsr, { value -> vm.update { it.copy(hanafiAsr = value) } },
                        modifier = Modifier.semantics { contentDescription = "Gunakan Ashar Hanafi" })
                }
                Text("Untuk lokasi ekstrem, gunakan referensi setempat dan koreksi manual per sholat.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
