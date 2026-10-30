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
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import id.jedasholat.core.*
import id.jedasholat.ui.*

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
    fun open(action: String) { runCatching { context.startActivity(Intent(action).setData(Uri.parse("package:${context.packageName}"))) }
        .onFailure { vm.message("Buka Pengaturan Android → Aplikasi → JedaSholat secara manual.") } }
    LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { SectionTitle("Kamu tetap memegang kendali", "Pengaturan, izin, dan data tersimpan di perangkat ini.") }
        item { JedaCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { Text("Perlindungan aplikasi", style = MaterialTheme.typography.titleLarge)
                    Text(if (s.protectionEnabled) "Aktif sesuai jadwal" else "Sedang dimatikan", fontSize = 13.sp) }
                Switch(s.protectionEnabled, { enabled -> if (enabled) vm.update { it.copy(protectionEnabled = true, onboardingCompleted = true) } else { confirm = "stop" } })
            }
            Text("Layanan Aksesibilitas: ${if (state.capabilities.accessibility) "aktif" else "belum aktif"}\nAlarm tepat waktu: ${if (state.capabilities.exactAlarms) "tersedia" else "terbatas"}\nNotifikasi: ${if (state.capabilities.notifications) "diizinkan" else "tidak diizinkan"}", fontSize = 13.sp)
            Button(onClick = { if (s.accessibilityConsent) open(Settings.ACTION_ACCESSIBILITY_SETTINGS) else disclosure = true }) { Text("Atur Layanan Aksesibilitas") }
            Text("Mode Tegas bukan anti-bypass. Force stop, pencabutan izin, dan pembatasan OEM dapat memengaruhi fungsi.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } }
        item { JedaCard {
            SectionTitle("Izin seperlunya", "Tidak ada akses isi layar, chat, kamera, atau mikrofon.")
            OutlinedButton(onClick = { open(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM) }) { Text("Alarms & reminders") }
            OutlinedButton(onClick = { if (android.os.Build.VERSION.SDK_INT >= 33) notifications.launch(Manifest.permission.POST_NOTIFICATIONS) else vm.message("Atur notifikasi melalui Pengaturan Android.") }) { Text("Izinkan notifikasi") }
            OutlinedButton(onClick = { open(Settings.ACTION_APPLICATION_DETAILS_SETTINGS) }) { Text("Pengaturan aplikasi Android") }
            Text("Usage Access opsional: hanya untuk mengenali aplikasi yang sudah terbuka ketika layanan tersambung. Tanpa izin ini, aplikasi menunggu event perpindahan berikutnya.", fontSize = 12.sp)
            OutlinedButton(onClick = { if (s.usageConsent) open(Settings.ACTION_USAGE_ACCESS_SETTINGS) else usageDisclosure = true }) { Text("Atur akses penggunaan opsional") }
        } }
        item { JedaCard {
            SectionTitle("Lokasi & jadwal", "${s.locationLabel} · ${s.zoneId}")
            Text("${"%.4f".format(s.latitude)}, ${"%.4f".format(s.longitude)} · ${if (s.locationSource == "GPS") "GPS sekali ambil" else "manual"}", fontSize = 13.sp)
            Row { TextButton(onClick = { locationPermission.launch(Manifest.permission.ACCESS_COARSE_LOCATION) }) { Text("Gunakan lokasi saya") }
                TextButton(onClick = { location = true }) { Text("Pilih kota") } }
            Text("Zona waktu mengikuti perangkat. Jika pindah wilayah, periksa kota dan zona waktu sebelum mengandalkan jadwal.", fontSize = 12.sp)
        } }
        item { JedaCard {
            SectionTitle("Coba tanpa menunggu sholat", "Simulasi 30 detik menjalankan layar jeda asli pada aplikasi pilihanmu. Tidak mengubah jadwal sholat.")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { vm.simulate(Mode.PENGINGAT) }) { Text("Coba Pengingat") }
                OutlinedButton(onClick = { vm.simulate(Mode.TEGAS) }) { Text("Coba Tegas") }
            }
            Text("Setelah menekan coba, buka aplikasi yang dipilih. Telepon dan layar utama tetap tersedia.", fontSize = 12.sp)
        } }
        item { JedaCard {
            SectionTitle("Tampilan & notifikasi")
            Row { Theme.entries.forEach { theme -> TextButton(onClick = { vm.update { it.copy(theme = theme) } }) {
                Text(when(theme) { Theme.SYSTEM -> "Sistem" Theme.LIGHT -> "Terang" Theme.DARK -> "Gelap" },
                    color = if (s.theme == theme) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
            } }
            Row(verticalAlignment = Alignment.CenterVertically) { Text("Notifikasi jeda", Modifier.weight(1f)); Switch(s.notifications, { value -> vm.update { it.copy(notifications = value) } }) }
        } }
        item { SectionTitle("Riwayat jeda", "Bukan catatan ibadah. Hanya status sesi aplikasi.") }
        val history = state.sessions.filter { it.status in setOf(SessionStatus.COMPLETED, SessionStatus.CANCELLED, SessionStatus.INTERRUPTED, SessionStatus.MISSED) }.take(10)
        if (history.isEmpty()) item { Text("Belum ada riwayat. Riwayat akan muncul setelah sesi berakhir.", fontSize = 14.sp) }
        items(history, key = { it.id }) { session -> JedaCard {
            Row { Text("${session.prayer.label} · ${session.date}", Modifier.weight(1f)); Text(when(session.status) {
                SessionStatus.COMPLETED -> "Selesai" SessionStatus.CANCELLED -> "Dihentikan" SessionStatus.INTERRUPTED -> "Terputus" else -> "Terlewat"
            }, fontSize = 13.sp) }
            Text("${time(session.start, state.zone)}–${time(session.end, state.zone)}", fontSize = 12.sp)
        } }
        item { JedaCard {
            SectionTitle("Data & privasi", "Tanpa akun, iklan, analytics, atau izin internet.")
            TextButton(onClick = { confirm = "history" }) { Text("Hapus riwayat") }
            TextButton(onClick = { confirm = "all" }) { Text("Hapus seluruh data lokal", color = MaterialTheme.colorScheme.error) }
            Text("JedaSholat 0.1.0 · MVP Android\nAdhan oleh Batoul Apps, lisensi MIT.\nLayanan aksesibilitas dapat dicabut kapan saja di Pengaturan Android.", fontSize = 12.sp)
        } }
    }
    if (disclosure) AlertDialog(onDismissRequest = { disclosure = false }, title = { Text("Izin Layanan Aksesibilitas") },
        text = { Text("JedaSholat menggunakan Layanan Aksesibilitas untuk mengenali nama paket aplikasi yang sedang dibuka, supaya layar jeda dapat ditampilkan pada aplikasi pilihanmu saat waktu sholat. Nama paket diproses di perangkat, tidak disimpan sebagai riwayat penjelajahan dan tidak dikirim ke server. Kami tidak membaca isi layar, pesan, atau ketikan. Kamu boleh menolak dan tetap memakai jadwal. Izin dapat dicabut kapan saja di Pengaturan Android.") },
        confirmButton = { TextButton(onClick = { disclosure = false; vm.update { it.copy(accessibilityConsent = true) }; open(Settings.ACTION_ACCESSIBILITY_SETTINGS) }) { Text("Saya setuju & buka pengaturan") } },
        dismissButton = { TextButton(onClick = { disclosure = false }) { Text("Tidak sekarang") } })
    if (usageDisclosure) AlertDialog(onDismissRequest = { usageDisclosure = false }, title = { Text("Akses penggunaan opsional") },
        text = { Text("Jika diizinkan, JedaSholat membaca event aplikasi foreground terbaru untuk mengetahui aplikasi yang sudah terbuka saat layanan tersambung. Informasi ini dipakai di memori perangkat untuk fungsi jeda, tidak dikirim atau dijadikan riwayat aktivitas. Izin ini opsional dan dapat dicabut.") },
        confirmButton = { TextButton(onClick = { usageDisclosure = false; vm.update { it.copy(usageConsent = true) }; open(Settings.ACTION_USAGE_ACCESS_SETTINGS) }) { Text("Setuju & buka pengaturan") } },
        dismissButton = { TextButton(onClick = { usageDisclosure = false }) { Text("Tidak sekarang") } })
    if (confirm.isNotEmpty()) AlertDialog(onDismissRequest = { confirm = "" }, title = { Text(if (confirm == "stop") "Matikan perlindungan?" else "Hapus data?") },
        text = { Text(if (confirm == "stop") "Jeda yang sedang berjalan akan dihentikan. Jadwal tetap tersimpan dan bisa diaktifkan lagi." else "Tindakan ini tidak bisa dibatalkan. Pengaturan Android seperti izin aksesibilitas tetap harus dicabut secara manual.") },
        confirmButton = { TextButton(onClick = { when(confirm) { "stop" -> vm.stop() "history" -> vm.deleteHistory() else -> vm.deleteAll() }; confirm = "" }) { Text("Ya, lanjutkan") } },
        dismissButton = { TextButton(onClick = { confirm = "" }) { Text("Batal") } })
    if (location) AlertDialog(onDismissRequest = { location = false }, title = { Text("Pilih kota") },
        text = { Column {
            Text("Pilih kota terdekat, lalu cocokkan dengan jadwal setempat.", fontSize = 13.sp)
            listOf(Triple("Jakarta", -6.2115, 106.8452), Triple("Bandung", -6.9175, 107.6191), Triple("Surabaya", -7.2575, 112.7521),
                Triple("Yogyakarta", -7.7956, 110.3695), Triple("Medan", 3.5952, 98.6722), Triple("Makassar", -5.1477, 119.4327),
                Triple("Denpasar", -8.6705, 115.2126), Triple("Jayapura", -2.5337, 140.7181)).forEach { (name, lat, lng) ->
                TextButton(onClick = { vm.update { it.copy(locationLabel = name, latitude = lat, longitude = lng, locationSource = "MANUAL",
                    zoneId = if (name == "Jayapura") "Asia/Jayapura" else if (name == "Makassar" || name == "Denpasar") "Asia/Makassar" else "Asia/Jakarta") }; location = false }) { Text(name) }
            }
        } }, confirmButton = { TextButton(onClick = { location = false }) { Text("Tutup") } })
}
