package id.jedasholat.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.graphics.drawable.toBitmap
import id.jedasholat.ui.*

@Composable fun AppsScreen(state: UiState, vm: JedaViewModel) {
    var query by remember { mutableStateOf("") }
    var whitelist by remember { mutableStateOf(false) }
    val s = state.settings
    val filtered = state.apps.filter { it.label.contains(query, true) || it.packageName.contains(query, true) }
    LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            SectionTitle("Pilih yang ingin dijeda", "Tidak semua aplikasi perlu dibatasi. Pilih sesuai kebutuhanmu.")
            OutlinedTextField(query, { query = it }, label = { Text("Cari aplikasi") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(!whitelist, { whitelist = false }, { Text("Dibatasi · ${s.selectedPackages.size}") })
                FilterChip(whitelist, { whitelist = true }, { Text("Whitelist · ${s.whitelistPackages.size}") })
            }
            Text(if (whitelist) "Aplikasi di sini selalu diizinkan. Telepon, alarm, dan Settings sudah dilindungi otomatis."
                else "Saat jeda aktif, aplikasi terpilih diarahkan ke layar jeda. Di luar jeda, semuanya normal.", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (filtered.isEmpty()) item { JedaCard { Text("Tidak ada aplikasi yang cocok. Coba kata lain atau tekan segarkan."); TextButton(onClick = vm::refresh) { Text("Segarkan daftar") } } }
        items(filtered, key = { it.packageName }) { app ->
            val checked = if (whitelist) app.packageName in s.whitelistPackages else app.packageName in s.selectedPackages
            Surface(color = MaterialTheme.colorScheme.surface) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Image(app.icon.toBitmap(64, 64).asImageBitmap(), contentDescription = null, modifier = Modifier.size(38.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) { Text(app.label, fontSize = 15.sp); Text(app.packageName, fontSize = 10.sp, maxLines = 1, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    Checkbox(checked, onCheckedChange = { value -> vm.update { old ->
                        if (whitelist) old.copy(whitelistPackages = if (value) old.whitelistPackages + app.packageName else old.whitelistPackages - app.packageName,
                            selectedPackages = old.selectedPackages - app.packageName)
                        else old.copy(selectedPackages = if (value) old.selectedPackages + app.packageName else old.selectedPackages - app.packageName,
                            whitelistPackages = old.whitelistPackages - app.packageName)
                    } })
                }
            }
        }
    }
}
