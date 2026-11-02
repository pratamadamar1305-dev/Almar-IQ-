package id.jedasholat.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import id.jedasholat.core.*
import id.jedasholat.ui.*
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable fun HomeScreen(state: UiState, vm: JedaViewModel, navigate: (String) -> Unit) {
    val s = state.settings
    val hero = LocalJedaHero.current
    val active = state.active
    val snoozed = state.snoozed
    val next = state.next
    val focus = active.firstOrNull() ?: snoozed.firstOrNull()
    val isSnoozed = active.isEmpty() && focus != null
    val end = when {
        active.isNotEmpty() -> active.maxOf { it.end }
        isSnoozed -> focus!!.snoozedUntil ?: focus.end
        else -> next?.start ?: state.now
    }
    val total = when {
        active.isNotEmpty() -> (end - (active.minOf { it.start })).coerceAtLeast(1L)
        isSnoozed -> 5 * 60_000L
        else -> 1L
    }
    val progress = if (active.isNotEmpty() || isSnoozed) ((end - state.now).coerceAtLeast(0L).toFloat() / total).coerceIn(0f, 1f) else 1f
    val focusRule = focus?.let { s.rules.getValue(it.prayer) } ?: next?.let { s.rules.getValue(it.prayer) }
    val enabledRules = s.rules.values.filter { it.enabled }
    val todayMinutes = enabledRules.sumOf { it.durationMinutes }
    val tnum = "tnum"

    LazyColumn(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(18.dp),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 28.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Surface(shape = MaterialTheme.shapes.small, color = hero.background, modifier = Modifier.size(42.dp)) {
                    Box(contentAlignment = Alignment.Center) { JedaMark(38.dp, crescent = hero.onBackground, bars = hero.accent) }
                }
                Column(Modifier.weight(1f)) {
                    Text("JedaSholat", style = MaterialTheme.typography.titleMedium)
                    Text("Ruang untuk yang utama", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainer, modifier = Modifier.clip(CircleShape)) {
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
            Surface(shape = MaterialTheme.shapes.large, color = hero.background, contentColor = hero.onBackground, modifier = Modifier.fillMaxWidth()) {
                Box {
                    HeroArt(Modifier.align(Alignment.CenterEnd).width(180.dp).height(230.dp))
                    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Surface(shape = CircleShape, color = hero.onBackground.copy(alpha = 0.12f)) {
                                Row(Modifier.padding(horizontal = 10.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    JedaIcon(if (active.isNotEmpty()) JedaGlyph.PAUSE else if (isSnoozed) JedaGlyph.BELL else JedaGlyph.SHIELD,
                                        modifier = Modifier.size(14.dp), tint = hero.accent)
                                    Text(when {
                                        active.isNotEmpty() -> "Jeda sedang berjalan"
                                        isSnoozed -> "Jeda ditunda"
                                        next != null -> "Jeda berikutnya"
                                        else -> "Jadwal hari ini"
                                    }, style = MaterialTheme.typography.labelMedium, color = hero.onBackground)
                                }
                            }
                            Spacer(Modifier.weight(1f))
                            JedaIcon(if (focus != null) prayerGlyph(focus.prayer) else if (next != null) prayerGlyph(next.prayer) else JedaGlyph.MOON,
                                tint = hero.accent, modifier = Modifier.size(24.dp))
                        }
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                            CountdownRing(
                                progress = progress,
                                modifier = Modifier.size(116.dp),
                                strokeWidth = 7.dp,
                                trackColor = hero.onBackground.copy(alpha = 0.16f),
                                progressColor = hero.accent,
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(focus?.prayer?.label ?: next?.prayer?.label ?: "—", style = MaterialTheme.typography.titleSmall, color = hero.onBackground)
                                    if (focus != null || next != null) Text(countdown(end, state.now),
                                        style = MaterialTheme.typography.titleLarge.copy(fontFeatureSettings = tnum), color = hero.onBackground, maxLines = 1)
                                }
                            }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(focus?.prayer?.label ?: next?.prayer?.label ?: "Belum ada jadwal", style = MaterialTheme.typography.headlineMedium)
                                if (active.isNotEmpty() || isSnoozed || next != null) {
                                    Text(countdown(end, state.now), style = MaterialTheme.typography.displaySmall.copy(fontFeatureSettings = tnum), maxLines = 1)
                                    Text(when {
                                        active.isNotEmpty() -> "sampai jeda selesai · ${countdownCaption(end, state.now)}"
                                        isSnoozed -> "sampai pengingat kembali · ${countdownCaption(end, state.now)}"
                                        else -> "menuju waktu jeda · ${countdownCaption(end, state.now)}"
                                    }, style = MaterialTheme.typography.bodySmall, color = hero.muted)
                                } else Text("Periksa lokasi dan aturan jadwal.", style = MaterialTheme.typography.bodyMedium, color = hero.muted)
                            }
                        }
                        HorizontalDivider(color = hero.onBackground.copy(alpha = 0.16f))
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            JedaIcon(if (active.isNotEmpty()) JedaGlyph.PAUSE else JedaGlyph.SHIELD, modifier = Modifier.size(17.dp), tint = hero.accent)
                            Text(when {
                                active.size > 1 -> "${active.size} jendela jeda sedang berjalan"
                                active.isNotEmpty() -> "Hanya aplikasi pilihanmu yang dijeda"
                                isSnoozed -> "Pengingat muncul lagi setelah tunda selesai"
                                next != null -> "${time(next.start, state.zone)} · jeda ${focusRule?.durationMinutes ?: 20} menit"
                                else -> "Jadwal dihitung di perangkat"
                            }, style = MaterialTheme.typography.bodySmall, color = hero.muted)
                        }
                    }
                }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                FilledTonalButton(onClick = { navigate("schedule") }, modifier = Modifier.weight(1f).heightIn(min = 52.dp)) {
                    JedaIcon(JedaGlyph.CALENDAR, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("Atur jadwal")
                }
                OutlinedButton(onClick = { navigate("apps") }, modifier = Modifier.weight(1f).heightIn(min = 52.dp)) {
                    JedaIcon(JedaGlyph.GRID, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("Pilih aplikasi")
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
                val readiness = state.readiness
                JedaCard(outlined = true) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
                        JedaIcon(JedaGlyph.SHIELD, tint = MaterialTheme.colorScheme.primary)
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(readiness.nextInfo.title, style = MaterialTheme.typography.titleMedium)
                            Text(readiness.nextInfo.detail, style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        readiness.steps.filter { it.step != ReadinessStep.READY }.forEach { step ->
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                                JedaIcon(if (step.done) JedaGlyph.CHECK else JedaGlyph.CLOSE,
                                    tint = if (step.done) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                    contentDescription = if (step.done) "${step.title}: selesai" else "${step.title}: belum",
                                    modifier = Modifier.size(15.dp))
                                Text(step.title, style = MaterialTheme.typography.bodySmall,
                                    color = if (step.done) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                                    fontWeight = if (step.step == readiness.next) androidx.compose.ui.text.font.FontWeight.SemiBold else null)
                            }
                        }
                    }
                    Button(onClick = {
                        when (readiness.next) {
                            ReadinessStep.PROTECTION -> vm.update { it.copy(protectionEnabled = true) }
                            ReadinessStep.APPS -> navigate("apps")
                            else -> navigate("settings")
                        }
                    }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                        Text(readiness.nextInfo.action)
                        Spacer(Modifier.width(8.dp)); JedaIcon(JedaGlyph.ARROW, modifier = Modifier.size(18.dp))
                    }
                    Text("${readiness.remaining} langkah tersisa sebelum jeda bisa tampil.",
                        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        if (!state.capabilities.exactAlarms) item {
            JedaCard(color = MaterialTheme.colorScheme.secondaryContainer) {
                InfoNote(JedaGlyph.BELL, "Ketepatan waktu terbatas", "Izin Alarms & reminders belum aktif. Android dapat menunda batas waktu.")
                TextButton(onClick = { navigate("settings") }) { Text("Periksa izin") }
            }
        }
        if (state.scheduleError != null) item {
            JedaCard(color = MaterialTheme.colorScheme.errorContainer) {
                Text("Jadwal belum bisa dihitung", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onErrorContainer)
                Text(state.scheduleError.orEmpty(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onErrorContainer)
                TextButton(onClick = { navigate("settings") }) { Text("Periksa lokasi", color = MaterialTheme.colorScheme.onErrorContainer) }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile("Total jeda hari ini", "$todayMinutes m", JedaGlyph.PAUSE, Modifier.weight(1f))
                StatTile("Aplikasi dipilih", "${s.selectedPackages.size}", JedaGlyph.GRID, Modifier.weight(1f))
                StatTile("Jendela aktif", "${enabledRules.size}/5", JedaGlyph.CALENDAR, Modifier.weight(1f))
            }
        }
        item { SectionTitle("Jadwal hari ini", "Jeda selesai otomatis setelah durasi habis.") { TextButton(onClick = { navigate("schedule") }) { Text("Atur") } } }
        item {
            JedaCard {
                Column(Modifier.fillMaxWidth()) {
                    Prayer.entries.forEachIndexed { index, prayer ->
                        val rule = s.rules.getValue(prayer)
                        val window = state.windows.firstOrNull { it.prayer == prayer && it.date == state.today.toString() }
                        val session = state.sessions.firstOrNull { it.prayer == prayer && it.date == state.today.toString() }
                        val isActive = active.any { it.prayer == prayer }
                        val isSnoozed = snoozed.any { it.prayer == prayer }
                        val isNext = !isActive && !isSnoozed && next?.prayer == prayer && next.date == state.today.toString()
                        val past = window != null && window.end <= state.now
                        val status = when {
                            !rule.enabled -> "Nonaktif"
                            isActive -> "Berjalan"
                            isSnoozed -> "Ditunda"
                            session?.status == SessionStatus.COMPLETED -> "Selesai"
                            isNext -> "Berikutnya"
                            past -> "Lewat"
                            else -> "Terjadwal"
                        }
                        Surface(onClick = { navigate("schedule") }, color = if (isNext || isActive) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
                            shape = MaterialTheme.shapes.small, modifier = Modifier.fillMaxWidth()) {
                            Row(Modifier.padding(horizontal = 10.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Text(window?.let { time(it.start, state.zone) } ?: if (!rule.enabled) "—" else "…",
                                    modifier = Modifier.widthIn(min = 48.dp), style = MaterialTheme.typography.titleMedium.copy(fontFeatureSettings = tnum),
                                    color = if (past && !isActive) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                                Surface(shape = CircleShape, color = if (isActive || isNext) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceContainer,
                                    contentColor = MaterialTheme.colorScheme.primary, modifier = Modifier.size(40.dp)) {
                                    Box(contentAlignment = Alignment.Center) { JedaIcon(prayerGlyph(prayer), modifier = Modifier.size(21.dp)) }
                                }
                                Column(Modifier.weight(1f)) {
                                    Text(prayer.label, style = MaterialTheme.typography.titleSmall)
                                    Text(if (!rule.enabled) "Tidak dijeda" else "${rule.durationMinutes} menit · ${if (rule.mode == Mode.TEGAS) "Tegas" else "Pengingat"}",
                                        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Pill(status, positive = isActive || isNext || status == "Selesai")
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
