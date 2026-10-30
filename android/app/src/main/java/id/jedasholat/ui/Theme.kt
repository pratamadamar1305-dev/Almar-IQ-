package id.jedasholat.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import id.jedasholat.core.Theme

val Green = Color(0xFF123F35)
val Gold = Color(0xFFC9A96A)
val Cream = Color(0xFFF5F1E8)
@Composable
fun JedaTheme(theme: Theme, content: @Composable () -> Unit) {
    val dark = theme == Theme.DARK || (theme == Theme.SYSTEM && isSystemInDarkTheme())
    val colors = if (dark) darkColorScheme(primary = Color(0xFFB5D5C5), onPrimary = Green,
        primaryContainer = Color(0xFF244D42), onPrimaryContainer = Cream, secondary = Gold,
        background = Color(0xFF111C18), onBackground = Cream, surface = Color(0xFF1B2923), onSurface = Cream,
        surfaceVariant = Color(0xFF293B32), onSurfaceVariant = Color(0xFFC3CEC6))
    else lightColorScheme(primary = Green, onPrimary = Color.White, primaryContainer = Color(0xFFDDE9DF),
        onPrimaryContainer = Green, secondary = Color(0xFF80632D), background = Cream, onBackground = Color(0xFF1D3028),
        surface = Color(0xFFFFFDF8), onSurface = Color(0xFF1D3028), surfaceVariant = Color(0xFFEAE7DC), onSurfaceVariant = Color(0xFF5C685F))
    MaterialTheme(colorScheme = colors, typography = Typography(
        headlineLarge = TextStyle(fontSize = 32.sp, fontWeight = FontWeight.SemiBold),
        headlineMedium = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.SemiBold),
        titleLarge = TextStyle(fontSize = 21.sp, fontWeight = FontWeight.SemiBold),
        bodyLarge = TextStyle(fontSize = 16.sp, lineHeight = 24.sp),
        labelLarge = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium))) { content() }
}
