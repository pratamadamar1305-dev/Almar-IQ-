package id.jedasholat.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import id.jedasholat.core.*
import id.jedasholat.ui.*
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable fun HomeScreen(state: UiState, vm: JedaViewModel, navigate: (String) -> Unit) {
    val s = state.settings
    val active = state.active
    val next = state.next
    val focus = active.firstOrNull()
    val end = if (active.isNotEmpty()) active.maxOf { it.end } else next?.start ?: state.now
    val focusRule = focus?.let { s.rules.getValue(it.prayer) } ?: next?.let { s.rules.getValue(it.prayer) }
    LazyColumn(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(18.dp),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 28.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Surface(shape = MaterialTheme.shapes.small, color = Green, modifier = Modifier.size(42.dp)) {
                    Box(contentAlignment = Alignment.Center) { JedaMark(38.dp) }
                }
                Column(Modifier.weight(1f)) {
                    Text("JedaSholat", style = MaterialTheme.typography.titleMedium)
                    Text("Ruang untuk yang utama", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainer,
                    modifier = Modifier.clip(CircleShape)) {
                    Row(Modifier.padding(horizontal = 10.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        JedaIcon(JedaGlyph.PIN, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
                        Text(s.locationLabel, style = MaterialTheme.typography.labelMedium, maxLines = 1)
                    }
                }
            }
        }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Assalamu’alaikum", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Beri ruang untuk\nyang utama.", style = MaterialTheme.typography.headlineLarge)
                Text(state.today.format(DateTimeFormatter.ofPattern("EEEE, d MMMM yyyy", Locale("id", "ID"))),
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        item {
            Surface(shape = MaterialTheme.shapes.large, color = Green, contentColor = Cream, modifier = Modifier.fillMaxWidth()) {
                Box {
                    HeroArt(Modifier.align(Alignment.CenterEnd).width(180.dp).height(210.dp))
                    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(if (active.isNotEmpty()) "Jeda sedang berjalan" else "Jeda berikutnya",
                                Modifier.weight(1f), style = MaterialTheme.typography.labelLarge, color = Color(0xFFD4E7DA))
                            JedaIcon(if (focus != null) prayerGlyph(focus.prayer) else if (next != null) prayerGlyph(next.prayer) else JedaGlyph.MOON,
                                tint = Gold, modifier = Modifier.size(24.dp))
                        }
                        Text(focus?.prayer?.label ?: next?.prayer?.label ?: "Belum ada jadwal", style = MaterialTheme.typography.headlineMedium)
                        if (active.isNotEmpty() || next != null) {
                            Text(countdown(end, state.now), style = MaterialTheme.typography.displayMedium.copy(fontFeatureSettings = "tnum"), maxLines = 1)
                            Text(if (active.isNotEmpty()) "sampai jeda selesai · ${countdownCaption(end, state.now)}" else "menuju waktu jeda · ${countdownCaption(end, state.now)}",
                                style = MaterialTheme.typography.bodySmall, color = Color(0xFFD4E7DA))
                        } else Text("Periksa lokasi dan aturan jadwal.", style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.height(8.dp))
                        HorizontalDivider(color = Color.White.copy(alpha = 0.16f))
                        Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            JedaIcon(if (active.isNotEmpty()) JedaGlyph.PAUSE else JedaGlyph.SHIELD, modifier = Modifier.size(17.dp), tint = Gold)
                            Text(when {
                                active.size > 1 -> "${active.size} jendela jeda sedang berjalan"
                                active.isNotEmpty() -> "Hanya aplikasi pilihanmu yang dijeda"
                                next != null -> "${time(next.start, state.zone)} · jeda ${focusRule?.durationMinutes ?: 20} menit"
                                else -> "Jadwal dihitung di perangkat"
                            }, style = MaterialTheme.typography.bodySmall, color = Color(0xFFE1EEE5))
                        }
                    }
                }
            }
        }
        item {
            if (state.ready) {
                Surface(shape = MaterialTheme.shapes.medium, color = MaterialTheme.colorScheme.primaryContainer, contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    onClick = { navigate("apps") }, modifier = Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        JedaIcon(JedaGlyph.SHIELD, modifier = Modifier.size(24.dp))
                        Column(Modifier.weight(1f)) {
                            Text("Perlindungan siap", style = MaterialTheme.typography.titleSmall)
                            Text("${s.selectedPackages.size} aplikasi dipilih · di luar jeda tetap bebas", style = MaterialTheme.typography.bodySmall)
                        }
                        JedaIcon(JedaGlyph.CHEVRON, modifier = Modifier.size(18.dp))
                    }
                }
            } else {
                val needsApps = s.selectedPackages.isEmpty()
                JedaCard(outlined = true) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
                        JedaIcon(JedaGlyph.SHIELD, tint = MaterialTheme.colorScheme.primary)
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(if (!s.protectionEnabled) "Perlindungan sedang mati" else if (needsApps) "Pilih aplikasi yang ingin dijeda" else "Satu langkah lagi",
                                style = MaterialTheme.typography.titleMedium)
                            Text(when {
                                !s.protectionEnabled -> "Jadwal tetap bisa dilihat. Aktifkan perlindungan saat kamu siap."
                                needsApps -> "Tidak ada aplikasi yang dipilih otomatis. Telepon dan akses darurat tetap aman."
                                !state.capabilities.accessibility || !s.accessibilityConsent -> "Layar jeda membutuhkan izin Layanan Aksesibilitas. Isi layar dan pesan tidak dibaca."
                                else -> "Periksa izin perlindungan di pengaturan."
                            }, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Button(onClick = { navigate(if (needsApps && s.protectionEnabled) "apps" else "settings") }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                        Text(if (needsApps && s.protectionEnabled) "Pilih aplikasi" else "Siapkan perlindungan")
                        Spacer(Modifier.width(8.dp)); JedaIcon(JedaGlyph.ARROW, modifier = Modifier.size(18.dp))
                    }
                }
            }
        }
        if (!state.capabilities.exactAlarms) item {
            JedaCard(color = MaterialTheme.colorScheme.secondaryContainer, content = {
                InfoNote(JedaGlyph.BELL, "Ketepatan waktu terbatas", "Izin Alarms & reminders belum aktif. Android dapat menunda batas waktu.")
                TextButton(onClick = { navigate("settings") }) { Text("Periksa izin") }
            })
        }
        if (state.scheduleError != null) item {
            JedaCard(color = MaterialTheme.colorScheme.errorContainer) {
                Text("Jadwal belum bisa dihitung", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onErrorContainer)
                Text(state.scheduleError!!, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onErrorContainer)
            }
        }
        item { SectionTitle("Jadwal hari ini", "Jeda selesai otomatis setelah durasi habis.") { TextButton(onClick = { navigate("schedule") }) { Text("Atur") } } }
        item {
            JedaCard(Modifier.padding(0.dp)) {
                Column(Modifier.fillMaxWidth()) {
                    Prayer.entries.forEachIndexed { index, prayer ->
                        val rule = s.rules.getValue(prayer)
                        val window = state.windows.firstOrNull { it.prayer == prayer && it.date == state.today.toString() }
                        val isActive = active.any { it.prayer == prayer }
                        val isNext = !isActive && next?.prayer == prayer && next.date == state.today.toString()
                        val past = window != null && window.end <= state.now
                        Surface(onClick = { navigate("schedule") }, color = if (isNext) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
                            shape = MaterialTheme.shapes.small, modifier = Modifier.fillMaxWidth()) {
                            Row(Modifier.padding(horizontal = 10.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Surface(shape = CircleShape, color = if (isActive || isNext) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceContainer,
                                    contentColor = MaterialTheme.colorScheme.primary, modifier = Modifier.size(40.dp)) {
                                    Box(contentAlignment = Alignment.Center) { JedaIcon(prayerGlyph(prayer), modifier = Modifier.size(21.dp)) }
                                }
                                Column(Modifier.weight(1f)) {
                                    Text(prayer.label, style = MaterialTheme.typography.titleSmall)
                                    Text(if (!rule.enabled) "Tidak dijeda" else "${rule.durationMinutes} menit · ${if (rule.mode == Mode.TEGAS) "Tegas" else "Pengingat"}",
                                        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                    Text(window?.let { time(it.start, state.zone) } ?: if (!rule.enabled) "—" else "…",
                                        style = MaterialTheme.typography.titleMedium.copy(fontFeatureSettings = "tnum"))
                                    when {
                                        isActive -> Text("Berjalan", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                                        isNext -> Text("Berikutnya", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                                        past -> Text("Lewat", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                            }
                        }
                        if (index < Prayer.entries.lastIndex) HorizontalDivider(Modifier.padding(horizontal = 10.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
                    }
                }
            }
        }
        item { InfoNote(JedaGlyph.OFFLINE, "Lokal, privat, tanpa iklan.",
            "Jadwal dihitung offline. Profil kustom, bukan jadwal resmi Kemenag; cocokkan dengan masjid setempat.") }
    }
}
