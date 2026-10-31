package id.jedasholat.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.graphics.drawable.toBitmap
import id.jedasholat.ui.*

@Composable fun AppsScreen(state: UiState, vm: JedaViewModel) {
    var query by remember { mutableStateOf("") }
    var whitelist by remember { mutableStateOf(false) }
    val s = state.settings
    val filtered = remember(state.apps, query) {
        state.apps.filter { it.label.contains(query, true) || it.packageName.contains(query, true) }
    }
    fun toggle(packageName: String, value: Boolean) = vm.update { old ->
        if (whitelist) old.copy(
            whitelistPackages = if (value) old.whitelistPackages + packageName else old.whitelistPackages - packageName,
            selectedPackages = old.selectedPackages - packageName)
        else old.copy(
            selectedPackages = if (value) old.selectedPackages + packageName else old.selectedPackages - packageName,
            whitelistPackages = old.whitelistPackages - packageName)
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Aplikasi pilihan", style = MaterialTheme.typography.headlineMedium)
                Text("Tidak semua aplikasi perlu dibatasi. Pilih yang paling sering mengalihkan perhatianmu.",
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        item {
            OutlinedTextField(query, { query = it }, modifier = Modifier.fillMaxWidth(), singleLine = true,
                label = { Text("Cari aplikasi") }, leadingIcon = { JedaIcon(JedaGlyph.SEARCH, modifier = Modifier.size(20.dp)) },
                trailingIcon = { if (query.isNotEmpty()) IconButton(onClick = { query = "" }) { JedaIcon(JedaGlyph.CLOSE, "Hapus pencarian", Modifier.size(18.dp)) } },
                shape = MaterialTheme.shapes.small)
        }
        item {
            SegmentedTabs(listOf("restricted" to "Dibatasi · ${s.selectedPackages.size}", "allowed" to "Selalu izin · ${s.whitelistPackages.size}"),
                if (whitelist) "allowed" else "restricted") { whitelist = it == "allowed" }
        }
        item {
            InfoNote(if (whitelist) JedaGlyph.SHIELD else JedaGlyph.PAUSE,
                if (whitelist) "Ruang aman tambahan" else "Hanya saat jendela sholat",
                if (whitelist) "Aplikasi di daftar ini selalu diizinkan. Telepon, alarm, Settings, dan layar utama sudah dilindungi otomatis."
                else "Aplikasi terpilih diarahkan ke layar jeda saat waktunya. Di luar jeda, semuanya normal.")
        }
        item {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("${filtered.size} aplikasi", Modifier.weight(1f), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                IconButton(onClick = vm::refresh) { JedaIcon(JedaGlyph.REFRESH, "Segarkan daftar aplikasi", Modifier.size(19.dp)) }
            }
        }
        if (filtered.isEmpty()) item {
            EmptyState(JedaGlyph.SEARCH, if (query.isBlank()) "Belum ada aplikasi" else "Tidak ada yang cocok",
                if (query.isBlank()) "Segarkan daftar untuk membaca aplikasi yang terpasang." else "Coba nama lain atau hapus pencarian.",
                if (query.isBlank()) "Segarkan daftar" else "Hapus pencarian",
                if (query.isBlank()) vm::refresh else ({ query = "" }))
        }
        items(filtered, key = { it.packageName }) { app ->
            val checked = if (whitelist) app.packageName in s.whitelistPackages else app.packageName in s.selectedPackages
            val icon = remember(app.icon) { app.icon.toBitmap(96, 96).asImageBitmap() }
            Surface(shape = MaterialTheme.shapes.small,
                color = if (checked) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
                contentColor = if (checked) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface,
                border = if (checked) androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)) else null,
                modifier = Modifier.fillMaxWidth().toggleable(checked, role = Role.Checkbox) { toggle(app.packageName, it) }) {
                Row(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Surface(shape = MaterialTheme.shapes.extraSmall, color = MaterialTheme.colorScheme.surface, modifier = Modifier.size(44.dp)) {
                        Image(icon, contentDescription = null, modifier = Modifier.padding(5.dp).fillMaxSize())
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(app.label, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(app.packageName, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Checkbox(checked, onCheckedChange = null)
                }
            }
        }
        item { Text("JedaSholat tidak menampilkan dirinya sendiri atau aplikasi keselamatan dalam daftar pilihan.",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}
