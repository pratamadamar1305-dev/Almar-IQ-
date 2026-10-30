package id.jedasholat.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import id.jedasholat.core.Mode
import id.jedasholat.ui.*

@Composable fun OnboardingScreen(state: UiState, vm: JedaViewModel) {
    var step by remember { mutableStateOf(0) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(28.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Text("☾  JedaSholat", style = MaterialTheme.typography.titleLarge)
        LinearProgressIndicator(progress = { (step + 1) / 4f }, modifier = Modifier.fillMaxWidth())
        when (step) {
            0 -> {
                Text("Beri ruang\nuntuk yang utama.", style = MaterialTheme.typography.headlineLarge)
                Text("Jeda aplikasi pilihanmu saat waktu sholat. Di luar itu, HP tetap bebas digunakan.", style = MaterialTheme.typography.bodyLarge)
                JedaCard { Text("Bukan mengunci HP seharian.", style = MaterialTheme.typography.titleLarge)
                    Text("Pilih aplikasi → atur lima jendela sholat → jeda selesai otomatis. Telepon dan akses darurat tetap tersedia.") }
                Text("Tanpa akun, iklan, atau pelacakan. Semua pengaturan disimpan di perangkat.", fontSize = 14.sp)
            }
            1 -> {
                Text("Di mana kamu berada?", style = MaterialTheme.typography.headlineLarge)
                Text("Jadwal awal memakai Jakarta. Pilih lokasi supaya sesuai. Ini perhitungan offline, bukan jadwal resmi Kemenag.", fontSize = 15.sp)
                var lat by remember { mutableStateOf(state.settings.latitude.toString()) }
                var lng by remember { mutableStateOf(state.settings.longitude.toString()) }
                var label by remember { mutableStateOf(state.settings.locationLabel) }
                OutlinedTextField(label, { label = it }, label = { Text("Nama kota") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(lat, { lat = it }, label = { Text("Lintang") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(lng, { lng = it }, label = { Text("Bujur") }, modifier = Modifier.fillMaxWidth())
                Button(onClick = {
                    val la = lat.toDoubleOrNull(); val lo = lng.toDoubleOrNull()
                    if (la == null || lo == null || la !in -90.0..90.0 || lo !in -180.0..180.0) vm.message("Koordinat belum valid.")
                    else vm.update { it.copy(latitude = la, longitude = lo, locationLabel = label.ifBlank { "Lokasi manual" }, locationSource = "MANUAL") }
                }) { Text("Simpan koordinat") }
                Text("Lokasi GPS dan pilihan kota lengkap tersedia setelah setup. Zona waktu: ${state.settings.zoneId}", fontSize = 13.sp)
            }
            2 -> {
                Text("Seberapa tegas jedamu?", style = MaterialTheme.typography.headlineLarge)
                Text("Default 20 menit per sholat. Mulai dengan pengingat; kamu bisa mengubahnya kapan saja.", fontSize = 15.sp)
                RuleEditor(id.jedasholat.core.Prayer.DZUHUR, state.settings.rules.getValue(id.jedasholat.core.Prayer.DZUHUR)) { rule ->
                    vm.update { it.copy(rules = it.rules.mapValues { (_, old) -> old.copy(durationMinutes = rule.durationMinutes, mode = rule.mode) }) }
                }
                Text("Mode Tegas tidak punya tombol lanjut main, tetapi izin Android selalu bisa dicabut. Kami tidak menjanjikan blokir yang mustahil dilewati.", fontSize = 13.sp)
            }
            else -> {
                Text("Siapkan dengan sadar.", style = MaterialTheme.typography.headlineLarge)
                Text("1. Pilih aplikasi yang ingin dibatasi.\n2. Baca penjelasan Layanan Aksesibilitas.\n3. Aktifkan izin hanya jika kamu setuju.\n4. Coba simulasi 30 detik.", fontSize = 16.sp)
                JedaCard { Text("Kamu tetap memegang kendali.", style = MaterialTheme.typography.titleLarge)
                    Text("Jadwal bisa dipakai tanpa izin pembatasan. Tidak ada aplikasi yang dipilih otomatis. Kamu bisa berhenti kapan saja.") }
                Text("Dengan melanjutkan, perlindungan dijadwalkan tetapi baru berjalan setelah aplikasi dipilih dan izin yang diperlukan aktif.", fontSize = 13.sp)
            }
        }
        Button(onClick = { if (step < 3) step++ else vm.update { it.copy(onboardingCompleted = true, protectionEnabled = true) } }, modifier = Modifier.fillMaxWidth()) {
            Text(if (step < 3) "Lanjutkan" else "Masuk ke JedaSholat")
        }
        TextButton(onClick = { if (step > 0) step-- else vm.update { it.copy(onboardingCompleted = true) } }) { Text(if (step > 0) "Kembali" else "Lewati, lihat jadwal saja") }
        if (state.message != null) Text(state.message!!, color = MaterialTheme.colorScheme.error)
    }
}
