package id.jedasholat.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
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
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

fun time(millis: Long, zone: ZoneId): String = Instant.ofEpochMilli(millis).atZone(zone).format(DateTimeFormatter.ofPattern("HH:mm"))
fun countdown(end: Long, now: Long): String {
    val seconds = ((end - now).coerceAtLeast(0) + 999) / 1000
    return "%02d:%02d".format(seconds / 60, seconds % 60)
}
@Composable fun SectionTitle(title: String, subtitle: String? = null) {
    Column(Modifier.padding(vertical = 10.dp)) {
        Text(title, style = MaterialTheme.typography.titleLarge)
        if (subtitle != null) Text(subtitle, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 14.sp)
    }
}
@Composable fun JedaCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth()) { Column(Modifier.padding(20.dp), content = content) }
}
@Composable fun Pill(text: String, positive: Boolean = true) {
    Surface(shape = RoundedCornerShape(50), color = if (positive) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant) {
        Text(text, Modifier.padding(horizontal = 12.dp, vertical = 7.dp), fontSize = 12.sp, fontWeight = FontWeight.Medium)
    }
}
@Composable fun ModePicker(mode: Mode, onChange: (Mode) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf(Mode.PENGINGAT to "Pengingat", Mode.TEGAS to "Tegas").forEach { (value, label) ->
            if (mode == value) Button(onClick = { onChange(value) }, modifier = Modifier.weight(1f)) { Text(label) }
            else OutlinedButton(onClick = { onChange(value) }, modifier = Modifier.weight(1f)) { Text(label) }
        }
    }
}
@Composable fun RuleEditor(prayer: Prayer, rule: PrayerRule, onChange: (PrayerRule) -> Unit) {
    JedaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(prayer.label, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
            Switch(checked = rule.enabled, onCheckedChange = { onChange(rule.copy(enabled = it)) })
        }
        if (rule.enabled) {
            Text("Durasi jeda", fontSize = 14.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                listOf(10, 15, 20, 30, 45, 60).forEach { minutes ->
                    val selected = rule.durationMinutes == minutes
                    TextButton(onClick = { onChange(rule.copy(durationMinutes = minutes)) },
                        colors = ButtonDefaults.textButtonColors(containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent),
                        contentPadding = PaddingValues(horizontal = 6.dp), modifier = Modifier.weight(1f)) { Text("$minutes", fontSize = 12.sp) }
                }
            }
            ModePicker(rule.mode) { onChange(rule.copy(mode = it)) }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Koreksi: ${rule.offsetMinutes} menit", Modifier.weight(1f), fontSize = 13.sp)
                TextButton(onClick = { if (rule.offsetMinutes > -30) onChange(rule.copy(offsetMinutes = rule.offsetMinutes - 1)) }) { Text("−1") }
                TextButton(onClick = { if (rule.offsetMinutes < 30) onChange(rule.copy(offsetMinutes = rule.offsetMinutes + 1)) }) { Text("+1") }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Ingatkan sebelum: ${rule.reminderMinutes} m", Modifier.weight(1f), fontSize = 13.sp)
                TextButton(onClick = { onChange(rule.copy(reminderMinutes = (rule.reminderMinutes - 5).coerceAtLeast(0)) }) { Text("−") }
                TextButton(onClick = { onChange(rule.copy(reminderMinutes = (rule.reminderMinutes + 5).coerceAtMost(30)) }) { Text("+") }
            }
            Text("Perubahan durasi/mode berlaku pada sesi berikutnya.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
