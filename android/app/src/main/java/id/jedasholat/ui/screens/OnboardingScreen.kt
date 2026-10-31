package id.jedasholat.ui.screens

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import id.jedasholat.core.Mode
import id.jedasholat.core.Prayer
import id.jedasholat.ui.*

@Composable fun OnboardingScreen(state: UiState, vm: JedaViewModel) {
    var step by rememberSaveable { mutableStateOf(0) }
    var location by remember { mutableStateOf(false) }
    val s = state.settings
    val locationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) vm.locate() else vm.message("Izin lokasi ditolak. Kota manual tetap tersedia.")
    }
    Column(Modifier.fillMaxSize().safeDrawingPadding().padding(horizontal = 24.dp, vertical = 16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            JedaMark(36.dp, crescent = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(10.dp))
            Text("JedaSholat", Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = { vm.update { it.copy(onboardingCompleted = true) } }) { Text("Lewati") }
        }
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            repeat(4) { index ->
                Surface(shape = CircleShape, color = if (index <= step) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHigh,
                    modifier = Modifier.weight(1f).height(4.dp)) {}
            }
        }
        Spacer(Modifier.height(12.dp))
        Text("Langkah ${step + 1} dari 4", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            when (step) {
                0 -> {
                    Surface(shape = MaterialTheme.shapes.large, color = Green, modifier = Modifier.size(96.dp)) {
                        Box(contentAlignment = Alignment.Center) { JedaMark(82.dp) }
                    }
                    Text("Beri ruang\nuntuk yang utama.", style = MaterialTheme.typography.displaySmall)
                    Text("Jeda aplikasi pilihanmu saat waktu sholat. Di luar itu, HP tetap bebas digunakan.", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    JedaCard(outlined = true) {
                        InfoNote(JedaGlyph.PAUSE, "Bukan mengunci HP seharian", "Pilih aplikasi, atur lima jendela sholat, lalu jeda selesai otomatis.")
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        InfoNote(JedaGlyph.PHONE, "Akses darurat tetap tersedia", "Telepon, Settings, dan layar utama tidak pernah dibatasi.")
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        InfoNote(JedaGlyph.OFFLINE, "Lokal dan privat", "Tanpa akun, iklan, atau pelacakan. Pengaturan disimpan di perangkat.")
                    }
                }
                1 -> {
                    Text("Di mana kamu\nberada?", style = MaterialTheme.typography.displaySmall)
                    Text("Jadwal awal memakai Jakarta. Pilih lokasi supaya sesuai. Ini perhitungan offline, bukan jadwal resmi Kemenag.", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    JedaCard {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            JedaIcon(JedaGlyph.PIN, tint = MaterialTheme.colorScheme.primary)
                            Column(Modifier.weight(1f)) {
                                Text(s.locationLabel, style = MaterialTheme.typography.titleMedium)
                                Text("${"%.4f".format(s.latitude)}, ${"%.4f".format(s.longitude)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(s.zoneId, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        Button(onClick = { location = true }, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)) { Text("Pilih kota atau koordinat") }
                        OutlinedButton(onClick = { locationPermission.launch(Manifest.permission.ACCESS_COARSE_LOCATION) }, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)) { Text("Gunakan lokasi saya sekali") }
                    }
                    Text("Lokasi hanya dipakai untuk menghitung jadwal. Kamu bisa mengubahnya kapan saja di Pengaturan.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                2 -> {
                    Text("Seberapa tegas\njedamu?", style = MaterialTheme.typography.displaySmall)
                    Text("Mulai dengan pengingat. Pilihan ini diterapkan ke lima sholat dan bisa diubah per sholat nanti.", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    RuleEditor(Prayer.DZUHUR, s.rules.getValue(Prayer.DZUHUR), { rule ->
                        vm.update { it.copy(rules = it.rules.mapValues { (_, old) -> old.copy(durationMinutes = rule.durationMinutes, mode = rule.mode) }) }
                    }, initiallyExpanded = true, zone = state.zone)
                    InfoNote(JedaGlyph.INFO, "Tegas bukan anti-bypass", "Mode Tegas tidak punya tombol lanjut main, tetapi izin Android selalu bisa dicabut. Kami tidak menjanjikan blokir yang mustahil dilewati.")
                }
                else -> {
                    Text("Siapkan\ndengan sadar.", style = MaterialTheme.typography.displaySmall)
                    Text("Setelah masuk, pilih aplikasi dan baca penjelasan izin sebelum mengaktifkan perlindungan.", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    JedaCard(outlined = true) {
                        InfoNote(JedaGlyph.GRID, "1. Pilih aplikasi", "Tidak ada aplikasi yang dipilih otomatis.")
                        InfoNote(JedaGlyph.SHIELD, "2. Pahami izin aksesibilitas", "Hanya nama paket aplikasi yang dibaca, bukan isi layar.")
                        InfoNote(JedaGlyph.BELL, "3. Aktifkan izin seperlunya", "Notifikasi dan alarm membantu jeda berjalan tepat waktu.")
                        InfoNote(JedaGlyph.PLAY, "4. Coba simulasi 30 detik", "Pastikan layar jeda muncul sebelum memakai jadwal asli.")
                    }
                    Text("Menyelesaikan setup menjadwalkan perlindungan, tetapi jeda baru berjalan setelah aplikasi dipilih dan izin yang diperlukan aktif. Kamu bisa berhenti kapan saja.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        if (state.message != null) {
            Text(state.message!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(bottom = 10.dp))
        }
        Button(onClick = { if (step < 3) step++ else vm.update { it.copy(onboardingCompleted = true, protectionEnabled = true) } },
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
            Text(if (step < 3) "Lanjutkan" else "Selesai & lihat beranda")
            Spacer(Modifier.width(8.dp)); JedaIcon(JedaGlyph.ARROW, modifier = Modifier.size(18.dp))
        }
        if (step > 0) TextButton(onClick = { step-- }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text("Kembali") }
        else Text("Dengan melanjutkan, kamu tetap memegang kendali.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.align(Alignment.CenterHorizontally).padding(vertical = 12.dp))
    }
    if (location) LocationDialog(s, { location = false }) { choice ->
        vm.update { it.copy(locationLabel = choice.label, latitude = choice.lat, longitude = choice.lng, zoneId = choice.zone, locationSource = "MANUAL") }
        location = false
    }
}
