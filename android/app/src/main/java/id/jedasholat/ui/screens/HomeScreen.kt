package id.jedasholat.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import id.jedasholat.core.*
import id.jedasholat.ui.*
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable fun HomeScreen(state: UiState, vm: JedaViewModel, navigate: (String) -> Unit) {
    val s = state.settings
    LazyColumn(verticalArrangement = Arrangement.spacedBy(16.dp), contentPadding = PaddingValues(20.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Assalamu’alaikum", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Beri waktu untuk yang utama.", style = MaterialTheme.typography.titleLarge)
                }
                Pill("☾")
            }
            Text("${state.today.format(DateTimeFormatter.ofPattern("EEEE, d MMMM", Locale("id", "ID")))} · ${s.locationLabel}",
                fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item {
            Surface(color = Green, contentColor = Cream, shape = RoundedCornerShape(28.dp), modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(26.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(if (state.active.isNotEmpty()) "JEDA AKTIF" else "JEDA BERIKUTNYA", fontSize = 11.sp, letterSpacing = 2.sp, modifier = Modifier.weight(1f))
                        Text("☾", fontSize = 30.sp, color = Gold)
                    }
                    val next = state.next
                    Text(if (state.active.isNotEmpty()) state.active.first().prayer.label else next?.prayer?.label ?: "Belum ada jadwal",
                        fontSize = 30.sp, fontWeight = FontWeight.SemiBold)
                    Text(if (state.active.isNotEmpty()) countdown(state.active.maxOf { it.end }, state.now)
                        else next?.let { countdown(it.start, state.now) } ?: "—",
                        fontSize = 58.sp, fontWeight = FontWeight.Light, letterSpacing = (-2).sp)
                    Text(if (state.active.isNotEmpty()) "sampai aplikasi bisa digunakan kembali" else if (next != null)
                        "${time(next.start, state.zone)} · jeda ${s.rules.getValue(next.prayer).durationMinutes} menit" else "Periksa lokasi dan metode perhitungan", fontSize = 14.sp)
                    Spacer(Modifier.height(18.dp))
                    Text(if (state.active.isNotEmpty()) "◷  Jendela sholat sedang berjalan" else if (state.ready)
                        "✓  ${s.selectedPackages.size} aplikasi siap dibatasi saat jeda" else "○  Perlindungan belum siap · periksa pengaturan", fontSize = 13.sp, color = Color(0xFFD6E4D9))
                }
            }
        }
        if (!state.ready) item {
            JedaCard {
                Text("Satu langkah lagi", fontWeight = FontWeight.SemiBold)
                Text(if (!s.protectionEnabled) "Perlindungan sedang dimatikan. Jadwal tetap bisa dilihat."
                    else if (!state.capabilities.accessibility || !s.accessibilityConsent) "Izinkan Layanan Aksesibilitas supaya jeda bisa tampil di aplikasi pilihanmu."
                    else if (s.selectedPackages.isEmpty()) "Pilih aplikasi yang ingin kamu batasi. Tidak ada aplikasi yang dipilih otomatis."
                    else "Periksa pengaturan perlindungan.", fontSize = 14.sp)
                Button(onClick = { navigate(if (s.selectedPackages.isEmpty()) "apps" else "settings") }) { Text("Siapkan perlindungan") }
            }
        }
        if (!state.capabilities.exactAlarms) item {
            JedaCard { Text("Ketepatan waktu terbatas", fontWeight = FontWeight.SemiBold)
                Text("Izin Alarms & reminders belum aktif. Android dapat menunda batas waktu. Jangan mengandalkan Mode Tegas untuk ketepatan detik.", fontSize = 13.sp)
                TextButton(onClick = { navigate("settings") }) { Text("Periksa izin") }
            }
        }
        if (state.scheduleError != null) item { Text(state.scheduleError!!, color = MaterialTheme.colorScheme.error) }
        item {
            Row(verticalAlignment = Alignment.CenterVertically) { SectionTitle("Jadwal hari ini", "Hanya aplikasi pilihanmu yang dibatasi."); Spacer(Modifier.weight(1f)); TextButton(onClick = { navigate("schedule") }) { Text("Atur") } }
        }
        items(Prayer.entries.toList()) { prayer ->
            val w = state.windows.firstOrNull { it.prayer == prayer }
            val rule = s.rules.getValue(prayer)
            Surface(color = MaterialTheme.colorScheme.surface, shape = RoundedCornerShape(16.dp)) {
                Row(Modifier.padding(horizontal = 18.dp, vertical = 15.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(prayer.label, Modifier.weight(1f), fontWeight = FontWeight.Medium)
                    Column(horizontalAlignment = Alignment.End) {
                        Text(w?.let { time(it.start, state.zone) } ?: if (!rule.enabled) "Nonaktif" else "—", fontWeight = FontWeight.SemiBold)
                        Text("${rule.durationMinutes} m · ${if (rule.mode == Mode.TEGAS) "Tegas" else "Pengingat"}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        item {
            JedaCard {
                SectionTitle("Jeda kecil, ruang yang lebih besar.", "Jadwal dihitung offline. Bukan jadwal resmi Kemenag; cocokkan dengan masjid setempat.")
                Text("Tidak ada iklan. Tidak ada pelacakan. Kamu tetap memegang kendali.", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
