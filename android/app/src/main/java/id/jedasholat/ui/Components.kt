package id.jedasholat.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import id.jedasholat.core.*
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

fun time(millis: Long, zone: ZoneId): String =
    Instant.ofEpochMilli(millis).atZone(zone).format(DateTimeFormatter.ofPattern("HH:mm", Locale("id", "ID")))

fun countdown(end: Long, now: Long): String {
    val seconds = ((end - now).coerceAtLeast(0) + 999) / 1000
    return if (seconds >= 3600) "%02d:%02d:%02d".format(Locale.ROOT, seconds / 3600, seconds / 60 % 60, seconds % 60)
    else "%02d:%02d".format(Locale.ROOT, seconds / 60, seconds % 60)
}
fun countdownCaption(end: Long, now: Long): String = if (end - now >= 3_600_000) "jam · menit · detik" else "menit · detik"

@Composable fun SectionTitle(title: String, subtitle: String? = null, trailing: @Composable (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (trailing != null) trailing()
    }
}

@Composable fun JedaCard(
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.surface,
    outlined: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(shape = MaterialTheme.shapes.medium, color = color,
        border = if (outlined) BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant) else null,
        modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
    }
}

@Composable fun Pill(text: String, positive: Boolean = true, icon: JedaGlyph? = null) {
    Surface(shape = CircleShape, color = if (positive) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceContainerHigh,
        contentColor = if (positive) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant) {
        Row(Modifier.padding(horizontal = 10.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            if (icon != null) JedaIcon(icon, modifier = Modifier.size(14.dp))
            Text(text, style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable fun ModePicker(mode: Mode, onChange: (Mode) -> Unit) {
    Row(Modifier.fillMaxWidth().selectableGroup(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        listOf(Mode.PENGINGAT to "Pengingat", Mode.TEGAS to "Tegas").forEach { (value, label) ->
            val selected = mode == value
            Surface(shape = MaterialTheme.shapes.small,
                color = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceContainerLow,
                contentColor = if (selected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant,
                border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant),
                modifier = Modifier.weight(1f).heightIn(min = 76.dp)
                    .selectable(selected, role = Role.RadioButton) { onChange(value) }) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    JedaIcon(if (value == Mode.PENGINGAT) JedaGlyph.BELL else JedaGlyph.LOCK, modifier = Modifier.size(20.dp))
                    Column { Text(label, style = MaterialTheme.typography.titleSmall)
                        Text(if (value == Mode.PENGINGAT) "Bisa ditunda sekali" else "Tanpa tombol lanjut", style = MaterialTheme.typography.bodySmall) }
                }
            }
        }
    }
}

@Composable private fun Stepper(label: String, value: String, onMinus: () -> Unit, onPlus: () -> Unit, minusEnabled: Boolean, plusEnabled: Boolean) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
        IconButton(onMinus, enabled = minusEnabled) { JedaIcon(JedaGlyph.MINUS, "Kurangi $label", Modifier.size(18.dp)) }
        Text(value, Modifier.widthIn(min = 54.dp), textAlign = TextAlign.Center, style = MaterialTheme.typography.titleSmall)
        IconButton(onPlus, enabled = plusEnabled) { JedaIcon(JedaGlyph.PLUS, "Tambah $label", Modifier.size(18.dp)) }
    }
}

@Composable fun RuleEditor(prayer: Prayer, rule: PrayerRule, onChange: (PrayerRule) -> Unit, window: PrayerWindow? = null, initiallyExpanded: Boolean = false, zone: ZoneId = ZoneId.systemDefault()) {
    var expanded by rememberSaveable(prayer.name) { mutableStateOf(initiallyExpanded) }
    var customDuration by remember { mutableStateOf(false) }
    var durationInput by remember { mutableStateOf(rule.durationMinutes.toString()) }
    var durationError by remember { mutableStateOf<String?>(null) }
    JedaCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Surface(shape = CircleShape, color = MaterialTheme.colorScheme.primaryContainer, contentColor = MaterialTheme.colorScheme.onPrimaryContainer, modifier = Modifier.size(42.dp)) {
                Box(contentAlignment = Alignment.Center) { JedaIcon(prayerGlyph(prayer), modifier = Modifier.size(22.dp)) }
            }
            Column(Modifier.weight(1f)) {
                Text(prayer.label, style = MaterialTheme.typography.titleMedium)
                Text(if (!rule.enabled) "Nonaktif" else window?.let { "${time(it.start, zone)} · ${rule.durationMinutes} menit" } ?: "${rule.durationMinutes} menit · ${if (rule.mode == Mode.TEGAS) "Tegas" else "Pengingat"}",
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = { expanded = !expanded }) {
                JedaIcon(JedaGlyph.CHEVRON, if (expanded) "Tutup aturan ${prayer.label}" else "Atur ${prayer.label}", Modifier.size(18.dp).graphicsLayer { rotationZ = if (expanded) 90f else 0f })
            }
            Switch(rule.enabled, onCheckedChange = { onChange(rule.copy(enabled = it)) },
                modifier = Modifier.semantics { contentDescription = "Aktifkan jeda ${prayer.label}" })
        }
        if (expanded && rule.enabled) {
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Durasi jeda", Modifier.weight(1f), style = MaterialTheme.typography.titleSmall)
                TextButton(onClick = { durationInput = rule.durationMinutes.toString(); durationError = null; customDuration = true }) { Text("Ubah") }
            }
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).selectableGroup(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(10, 15, 20, 30, 45, 60).forEach { minutes ->
                    val selected = rule.durationMinutes == minutes
                    Surface(shape = MaterialTheme.shapes.small, color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerLow,
                        contentColor = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.height(44.dp).widthIn(min = 52.dp).selectable(selected, role = Role.RadioButton) { onChange(rule.copy(durationMinutes = minutes)) }) {
                        Box(contentAlignment = Alignment.Center, modifier = Modifier.padding(horizontal = 12.dp)) { Text("$minutes m", style = MaterialTheme.typography.labelLarge) }
                    }
                }
            }
            ModePicker(rule.mode) { onChange(rule.copy(mode = it)) }
            Stepper("Koreksi waktu", "${if (rule.offsetMinutes > 0) "+" else ""}${rule.offsetMinutes} m",
                { onChange(rule.copy(offsetMinutes = rule.offsetMinutes - 1)) }, { onChange(rule.copy(offsetMinutes = rule.offsetMinutes + 1)) },
                rule.offsetMinutes > -30, rule.offsetMinutes < 30)
            Stepper("Ingatkan sebelum", if (rule.reminderMinutes == 0) "Mati" else "${rule.reminderMinutes} m",
                { onChange(rule.copy(reminderMinutes = (rule.reminderMinutes - 5).coerceAtLeast(0))) },
                { onChange(rule.copy(reminderMinutes = (rule.reminderMinutes + 5).coerceAtMost(30))) },
                rule.reminderMinutes > 0, rule.reminderMinutes < 30)
            Text("Durasi dan mode baru berlaku pada sesi berikutnya. Koreksi memengaruhi jadwal yang dihitung ulang.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
    if (customDuration) AlertDialog(onDismissRequest = { customDuration = false },
        title = { Text("Durasi jeda ${prayer.label}") },
        text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Berapa lama aplikasi pilihanmu dijeda? Ini bukan durasi ibadah.")
            OutlinedTextField(durationInput, { durationInput = it; durationError = null }, label = { Text("Menit") }, singleLine = true,
                isError = durationError != null, supportingText = { Text(durationError ?: "1–120 menit") }, modifier = Modifier.fillMaxWidth())
        } },
        confirmButton = { TextButton(onClick = {
            val value = durationInput.toIntOrNull()
            if (value == null || value !in 1..120) durationError = "Masukkan angka 1 sampai 120."
            else { onChange(rule.copy(durationMinutes = value)); customDuration = false }
        }) { Text("Simpan durasi") } },
        dismissButton = { TextButton(onClick = { customDuration = false }) { Text("Batal") } })
}

@Composable fun SegmentedTabs(options: List<Pair<String, String>>, selected: String, modifier: Modifier = Modifier, onSelect: (String) -> Unit) {
    Surface(modifier.fillMaxWidth(), shape = MaterialTheme.shapes.small, color = MaterialTheme.colorScheme.surfaceContainer,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)) {
        Row(Modifier.padding(4.dp).selectableGroup(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            options.forEach { (id, label) ->
                val active = id == selected
                Surface(shape = MaterialTheme.shapes.extraSmall, color = if (active) MaterialTheme.colorScheme.surface else Color.Transparent,
                    contentColor = if (active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    shadowElevation = if (active) 1.dp else 0.dp,
                    modifier = Modifier.weight(1f).heightIn(min = 48.dp).selectable(active, role = Role.Tab) { onSelect(id) }) {
                    Box(contentAlignment = Alignment.Center, modifier = Modifier.padding(horizontal = 6.dp, vertical = 10.dp)) {
                        Text(label, style = MaterialTheme.typography.labelLarge, textAlign = TextAlign.Center)
                    }
                }
            }
        }
    }
}

@Composable fun EmptyState(icon: JedaGlyph, title: String, text: String, action: String? = null, onAction: (() -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().padding(vertical = 28.dp, horizontal = 12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Surface(shape = CircleShape, color = MaterialTheme.colorScheme.primaryContainer, modifier = Modifier.size(64.dp)) {
            Box(contentAlignment = Alignment.Center) { JedaIcon(icon, modifier = Modifier.size(28.dp), tint = MaterialTheme.colorScheme.onPrimaryContainer) }
        }
        Text(title, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
        if (action != null && onAction != null) OutlinedButton(onClick = onAction) { Text(action) }
    }
}

@Composable fun InfoNote(icon: JedaGlyph, title: String, text: String, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        JedaIcon(icon, modifier = Modifier.size(20.dp), tint = MaterialTheme.colorScheme.primary)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** Quiet architectural line art: a dome, a doorway and a crescent. Decorative only. */
@Composable fun HeroArt(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val sx = size.width / 180f; val sy = size.height / 210f
        val line = Color.White.copy(alpha = 0.13f)
        val dome = Path().apply {
            moveTo(20f * sx, 205f * sy); lineTo(20f * sx, 120f * sy)
            cubicTo(20f * sx, 78f * sy, 90f * sx, 68f * sy, 90f * sx, 28f * sy)
            cubicTo(90f * sx, 68f * sy, 160f * sx, 78f * sy, 160f * sx, 120f * sy)
            lineTo(160f * sx, 205f * sy)
        }
        drawPath(dome, line, style = Stroke(1.4f * sx, cap = StrokeCap.Round))
        val door = Path().apply {
            moveTo(65f * sx, 205f * sy); lineTo(65f * sx, 155f * sy)
            cubicTo(65f * sx, 132f * sy, 90f * sx, 122f * sy, 90f * sx, 122f * sy)
            cubicTo(90f * sx, 122f * sy, 115f * sx, 132f * sy, 115f * sx, 155f * sy)
            lineTo(115f * sx, 205f * sy)
        }
        drawPath(door, line, style = Stroke(1.2f * sx))
        drawLine(line, Offset(8f * sx, 205f * sy), Offset(172f * sx, 205f * sy), 1.2f * sx)
        drawCircle(Gold.copy(alpha = 0.75f), 13f * sx, Offset(140f * sx, 35f * sy))
        drawCircle(Color(0xFF164F41), 12f * sx, Offset(146f * sx, 30f * sy))
        drawCircle(Gold.copy(alpha = 0.7f), 1.8f * sx, Offset(45f * sx, 52f * sy))
    }
}
