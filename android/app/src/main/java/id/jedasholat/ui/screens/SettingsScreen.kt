package id.jedasholat.ui.screens

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import id.jedasholat.core.*
import id.jedasholat.ui.*

@Composable private fun ActionRow(icon: JedaGlyph, title: String, subtitle: String, onClick: () -> Unit, ok: Boolean? = null) {
    Surface(onClick = onClick, color = androidx.compose.ui.graphics.Color.Transparent, shape = MaterialTheme.shapes.small, modifier = Modifier.fillMaxWidth().heightIn(min = 60.dp)) {
        Row(Modifier.padding(vertical = 10.dp, horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            JedaIcon(icon, modifier = Modifier.size(21.dp), tint = MaterialTheme.colorScheme.primary)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = MaterialTheme.typography.titleSmall)
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = if (ok == false) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (ok == true) JedaIcon(JedaGlyph.CHECK, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
            else JedaIcon(JedaGlyph.CHEVRON, modifier = Modifier.size(17.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable fun SettingsScreen(state: UiState, vm: JedaViewModel) {
    val context = LocalContext.current
    val s = state.settings
    var disclosure by remember { mutableStateOf(false) }
    var usageDisclosure by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf("") }
    var location by remember { mutableStateOf(false) }
    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { vm.refresh() }
    val locationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) vm.locate() else vm.message("Izin lokasi ditolak. Kota manual tetap tersedia.")
    }
    fun open(action: String) {
        runCatching {
            val intent = Intent(action)
            if (action != Settings.ACTION_ACCESSIBILITY_SETTINGS && action != Settings.ACTION_USAGE_ACCESS_SETTINGS) intent.data = Uri.parse("package:${context.packageName}")
            if (action == Settings.ACTION_APP_NOTIFICATION_SETTINGS) intent.putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            context.startActivity(intent)
        }.onFailure { vm.message("Buka Pengaturan Android → Aplikasi → JedaSholat secara manual.") }
    }
    fun saveLocation(choice: LocationChoice) {
        vm.update { it.copy(locationLabel = choice.label, latitude = choice.lat, longitude = choice.lng, zoneId = choice.zone, locationSource = "MANUAL") }
        location = false
        vm.message("Lokasi disimpan. Jadwal dihitung ulang.")
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Pengaturan", style = MaterialTheme.typography.headlineMedium)
            Text("Kamu tetap memegang kendali. Semua data tersimpan di perangkat ini.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } }
        item { JedaCard(color = if (s.protectionEnabled) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface, outlined = !s.protectionEnabled) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                JedaIcon(JedaGlyph.SHIELD, modifier = Modifier.size(28.dp), tint = MaterialTheme.colorScheme.primary)
                Column(Modifier.weight(1f)) {
                    Text("Perlindungan aplikasi", style = MaterialTheme.typography.titleMedium)
                    Text(if (s.protectionEnabled) "Aktif sesuai jadwal" else "Sedang dimatikan", style = MaterialTheme.typography.bodySmall)
                }
                Switch(s.protectionEnabled, { enabled -> if (enabled) vm.update { it.copy(protectionEnabled = true, onboardingCompleted = true) } else confirm = "stop" },
                    modifier = Modifier.semantics { contentDescription = "Perlindungan aplikasi" })
            }
            Text("Mode Tegas bukan anti-bypass. Force stop, pencabutan izin, dan pembatasan OEM dapat memengaruhi fungsi.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } }
        item { JedaCard {
            SectionTitle("Izin seperlunya", "Tidak ada akses isi layar, chat, kamera, atau mikrofon.")
            ActionRow(JedaGlyph.SHIELD, "Layanan Aksesibilitas", if (state.capabilities.accessibility) "Aktif" else "Belum aktif · diperlukan untuk layar jeda",
                { if (s.accessibilityConsent) open(Settings.ACTION_ACCESSIBILITY_SETTINGS) else disclosure = true }, state.capabilities.accessibility)
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            ActionRow(JedaGlyph.BELL, "Alarms & reminders", if (state.capabilities.exactAlarms) "Tersedia" else "Terbatas · Android dapat menunda jeda",
                { open(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM) }, state.capabilities.exactAlarms)
            ActionRow(JedaGlyph.BELL, "Notifikasi", if (state.capabilities.notifications) "Diizinkan" else "Belum diizinkan",
                { if (android.os.Build.VERSION.SDK_INT >= 33) notifications.launch(Manifest.permission.POST_NOTIFICATIONS) else open(Settings.ACTION_APP_NOTIFICATION_SETTINGS) }, state.capabilities.notifications)
            ActionRow(JedaGlyph.PAUSE, "Akses penggunaan opsional", if (state.capabilities.usageAccess) "Aktif" else "Opsional · mengenali aplikasi yang sudah terbuka",
                { if (s.usageConsent) open(Settings.ACTION_USAGE_ACCESS_SETTINGS) else usageDisclosure = true }, state.capabilities.usageAccess)
            ActionRow(JedaGlyph.SETTINGS, "Pengaturan aplikasi Android", "Kelola izin, baterai, atau hapus aplikasi", { open(Settings.ACTION_APPLICATION_DETAILS_SETTINGS) })
        } }
        item { JedaCard {
            SectionTitle("Lokasi & jadwal", "${s.locationLabel} · ${s.zoneId}") {
                IconButton(onClick = { location = true }) { JedaIcon(JedaGlyph.PIN, "Ubah lokasi", Modifier.size(20.dp)) }
            }
            Text("${"%.4f".format(s.latitude)}, ${"%.4f".format(s.longitude)} · ${if (s.locationSource == "GPS") "GPS sekali ambil" else "manual"}",
                style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { locationPermission.launch(Manifest.permission.ACCESS_COARSE_LOCATION) }, modifier = Modifier.weight(1f).heightIn(min = 48.dp)) { Text("Lokasi saya") }
                OutlinedButton(onClick = { location = true }, modifier = Modifier.weight(1f).heightIn(min = 48.dp)) { Text("Pilih kota") }
            }
            Text("Jika pindah wilayah, periksa kota dan zona waktu sebelum mengandalkan jadwal.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } }
        item { JedaCard(outlined = true) {
            SectionTitle("Coba tanpa menunggu sholat", "Simulasi 30 detik memakai layar jeda asli pada aplikasi pilihanmu. Jadwal sholat tidak berubah.")
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(onClick = { vm.simulate(Mode.PENGINGAT) }, modifier = Modifier.weight(1f).heightIn(min = 52.dp)) {
                    JedaIcon(JedaGlyph.PLAY, modifier = Modifier.size(17.dp)); Spacer(Modifier.width(6.dp)); Text("Pengingat")
                }
                OutlinedButton(onClick = { vm.simulate(Mode.TEGAS) }, modifier = Modifier.weight(1f).heightIn(min = 52.dp)) {
                    JedaIcon(JedaGlyph.LOCK, modifier = Modifier.size(17.dp)); Spacer(Modifier.width(6.dp)); Text("Tegas")
                }
            }
            Text(if (state.ready) "Setelah menekan coba, buka aplikasi yang dipilih. Telepon dan layar utama tetap tersedia." else "Butuh aplikasi terpilih, perlindungan aktif, dan izin Layanan Aksesibilitas.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } }
        item { JedaCard {
            SectionTitle("Tampilan & notifikasi")
            SegmentedTabs(listOf("SYSTEM" to "Sistem", "LIGHT" to "Terang", "DARK" to "Gelap"), s.theme.name) { value -> vm.update { it.copy(theme = Theme.valueOf(value)) } }
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { Text("Notifikasi jeda", style = MaterialTheme.typography.titleSmall); Text("Pengingat sebelum dan saat jeda", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                Switch(s.notifications, { value -> vm.update { it.copy(notifications = value) } }, modifier = Modifier.semantics { contentDescription = "Notifikasi jeda" })
            }
        } }
        item { SectionTitle("Riwayat jeda", "Bukan catatan ibadah. Hanya status sesi aplikasi.") }
        val history = state.sessions.filter { it.status in setOf(SessionStatus.COMPLETED, SessionStatus.CANCELLED, SessionStatus.INTERRUPTED, SessionStatus.MISSED) }.take(10)
        if (history.isEmpty()) item { JedaCard(outlined = true) { EmptyState(JedaGlyph.CALENDAR, "Belum ada riwayat", "Riwayat muncul setelah sesi jeda berakhir.") } }
        items(history, key = { it.id }) { session ->
            JedaCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) { Text("${session.prayer.label} · ${session.date}", style = MaterialTheme.typography.titleSmall)
                        Text("${time(session.start, state.zone)}–${time(session.end, state.zone)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    Pill(when (session.status) { SessionStatus.COMPLETED -> "Selesai"; SessionStatus.CANCELLED -> "Dihentikan"; SessionStatus.INTERRUPTED -> "Terputus"; else -> "Terlewat" }, session.status == SessionStatus.COMPLETED)
                }
            }
        }
        item { JedaCard {
            SectionTitle("Data & privasi", "Tanpa akun, iklan, analytics, atau izin internet.")
            OutlinedButton(onClick = { confirm = "history" }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { JedaIcon(JedaGlyph.TRASH, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("Hapus riwayat") }
            TextButton(onClick = { confirm = "all" }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp), colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)) { Text("Hapus seluruh data lokal") }
            Text("JedaSholat 0.2.0 · Android\nAdhan oleh Batoul Apps, lisensi MIT.\nPlus Jakarta Sans, lisensi SIL OFL.\nIzin aksesibilitas dapat dicabut kapan saja di Pengaturan Android.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } }
    }
    if (disclosure) AlertDialog(onDismissRequest = { disclosure = false },
        icon = { JedaIcon(JedaGlyph.SHIELD, tint = MaterialTheme.colorScheme.primary) },
        title = { Text("Izin Layanan Aksesibilitas") },
        text = { Column(Modifier.verticalScroll(rememberScrollState())) { Text("JedaSholat menggunakan Layanan Aksesibilitas untuk mengenali nama paket aplikasi yang sedang dibuka, supaya layar jeda dapat ditampilkan pada aplikasi pilihanmu saat waktu sholat. Nama paket diproses di perangkat, tidak disimpan sebagai riwayat penjelajahan dan tidak dikirim ke server. Kami tidak membaca isi layar, pesan, atau ketikan. Kamu boleh menolak dan tetap memakai jadwal. Izin dapat dicabut kapan saja di Pengaturan Android.") } },
        confirmButton = { TextButton(onClick = { disclosure = false; vm.update { it.copy(accessibilityConsent = true) }; open(Settings.ACTION_ACCESSIBILITY_SETTINGS) }) { Text("Saya setuju & buka pengaturan") } },
        dismissButton = { TextButton(onClick = { disclosure = false }) { Text("Tidak sekarang") } })
    if (usageDisclosure) AlertDialog(onDismissRequest = { usageDisclosure = false },
        title = { Text("Akses penggunaan opsional") },
        text = { Column(Modifier.verticalScroll(rememberScrollState())) { Text("Jika diizinkan, JedaSholat membaca event aplikasi foreground terbaru untuk mengetahui aplikasi yang sudah terbuka saat layanan tersambung. Informasi ini dipakai di memori perangkat untuk fungsi jeda, tidak dikirim atau dijadikan riwayat aktivitas. Izin ini opsional dan dapat dicabut.") } },
        confirmButton = { TextButton(onClick = { usageDisclosure = false; vm.update { it.copy(usageConsent = true) }; open(Settings.ACTION_USAGE_ACCESS_SETTINGS) }) { Text("Setuju & buka pengaturan") } },
        dismissButton = { TextButton(onClick = { usageDisclosure = false }) { Text("Tidak sekarang") } })
    if (confirm.isNotEmpty()) AlertDialog(onDismissRequest = { confirm = "" },
        title = { Text(if (confirm == "stop") "Matikan perlindungan?" else if (confirm == "history") "Hapus riwayat?" else "Hapus seluruh data?") },
        text = { Text(if (confirm == "stop") "Jeda yang sedang berjalan akan dihentikan. Jadwal tetap tersimpan dan bisa diaktifkan lagi." else "Tindakan ini tidak bisa dibatalkan. Pengaturan Android seperti izin aksesibilitas tetap harus dicabut secara manual.") },
        confirmButton = { TextButton(onClick = { when (confirm) { "stop" -> vm.stop(); "history" -> vm.deleteHistory(); else -> vm.deleteAll() }; confirm = "" },
            colors = if (confirm == "stop") ButtonDefaults.textButtonColors() else ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)) { Text(if (confirm == "stop") "Matikan" else "Ya, hapus") } },
        dismissButton = { TextButton(onClick = { confirm = "" }) { Text("Batal") } })
    if (location) LocationDialog(s, { location = false }, ::saveLocation)
}
