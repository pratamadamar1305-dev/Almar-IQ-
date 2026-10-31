package id.jedasholat.ui

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import id.jedasholat.app.R
import id.jedasholat.core.Theme

// Brand constants are intentionally independent of wallpaper colors: prayer status must stay recognizable.
val Green = Color(0xFF124D40)
val Gold = Color(0xFFC7A568)
val Cream = Color(0xFFF3F7F1)
val LocalJedaDark = staticCompositionLocalOf { false }

private val Jakarta = FontFamily(
    Font(R.font.plus_jakarta_sans_regular, FontWeight.Normal),
    Font(R.font.plus_jakarta_sans_medium, FontWeight.Medium),
    Font(R.font.plus_jakarta_sans_semibold, FontWeight.SemiBold),
    Font(R.font.plus_jakarta_sans_bold, FontWeight.Bold),
)

private fun style(size: Int, line: Int, weight: FontWeight = FontWeight.Normal, tracking: Double = 0.0) =
    TextStyle(fontFamily = Jakarta, fontSize = size.sp, lineHeight = line.sp, fontWeight = weight, letterSpacing = tracking.sp)

private val JedaTypography = Typography(
    displayLarge = style(56, 64, FontWeight.SemiBold, (-1.5)),
    displayMedium = style(46, 54, FontWeight.SemiBold, (-1.0)),
    displaySmall = style(36, 44, FontWeight.SemiBold, (-0.5)),
    headlineLarge = style(32, 40, FontWeight.Bold, (-0.8)),
    headlineMedium = style(28, 36, FontWeight.Bold, (-0.6)),
    headlineSmall = style(24, 32, FontWeight.SemiBold, (-0.3)),
    titleLarge = style(21, 28, FontWeight.SemiBold, (-0.3)),
    titleMedium = style(16, 24, FontWeight.SemiBold),
    titleSmall = style(14, 20, FontWeight.SemiBold),
    bodyLarge = style(16, 25),
    bodyMedium = style(14, 21),
    bodySmall = style(12, 18),
    labelLarge = style(14, 20, FontWeight.SemiBold),
    labelMedium = style(12, 17, FontWeight.Medium),
    labelSmall = style(11, 16, FontWeight.Medium),
)

private val JedaShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp), small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(20.dp), large = RoundedCornerShape(28.dp), extraLarge = RoundedCornerShape(32.dp),
)

@Composable
fun JedaTheme(theme: Theme, content: @Composable () -> Unit) {
    val dark = theme == Theme.DARK || (theme == Theme.SYSTEM && isSystemInDarkTheme())
    val view = LocalView.current
    SideEffect {
        (view.context as? Activity)?.window?.let { window ->
            val controller = WindowCompat.getInsetsController(window, view)
            controller.isAppearanceLightStatusBars = !dark
            controller.isAppearanceLightNavigationBars = !dark
        }
    }
    val colors = if (dark) darkColorScheme(
        primary = Color(0xFFA9D8BF), onPrimary = Color(0xFF0B382C),
        primaryContainer = Color(0xFF285443), onPrimaryContainer = Color(0xFFD9F2E3),
        secondary = Color(0xFFD9BE87), onSecondary = Color(0xFF3D2E0C),
        secondaryContainer = Color(0xFF4B4028), onSecondaryContainer = Color(0xFFF2DFB8),
        tertiary = Color(0xFFB6CCD8), background = Color(0xFF101C19), onBackground = Color(0xFFEAF1EB),
        surface = Color(0xFF192A24), onSurface = Color(0xFFEAF1EB),
        surfaceVariant = Color(0xFF263A31), onSurfaceVariant = Color(0xFFB8C9BE),
        surfaceContainerLowest = Color(0xFF0C1613), surfaceContainerLow = Color(0xFF15231E),
        surfaceContainer = Color(0xFF1D3028), surfaceContainerHigh = Color(0xFF263B31),
        surfaceContainerHighest = Color(0xFF30473B), outline = Color(0xFF8A9E91), outlineVariant = Color(0xFF354B40),
        error = Color(0xFFFFB4AB), onError = Color(0xFF601410), errorContainer = Color(0xFF7B2922), onErrorContainer = Color(0xFFFFDAD6),
        inverseSurface = Color(0xFFEAF1EB), inverseOnSurface = Color(0xFF172F29), inversePrimary = Green,
    ) else lightColorScheme(
        primary = Green, onPrimary = Color.White,
        primaryContainer = Color(0xFFDCEDE4), onPrimaryContainer = Color(0xFF123D30),
        secondary = Color(0xFF79602D), onSecondary = Color.White,
        secondaryContainer = Color(0xFFF3E8CE), onSecondaryContainer = Color(0xFF4D3B14),
        tertiary = Color(0xFF496575), background = Color(0xFFF5F7F4), onBackground = Color(0xFF172F29),
        surface = Color(0xFFFFFFFF), onSurface = Color(0xFF172F29),
        surfaceVariant = Color(0xFFE9EFE9), onSurfaceVariant = Color(0xFF52665B),
        surfaceContainerLowest = Color.White, surfaceContainerLow = Color(0xFFF0F4EF),
        surfaceContainer = Color(0xFFEAF0EA), surfaceContainerHigh = Color(0xFFE2EAE2),
        surfaceContainerHighest = Color(0xFFD9E4DA), outline = Color(0xFF718579), outlineVariant = Color(0xFFD5E0D6),
        error = Color(0xFFB3261E), onError = Color.White, errorContainer = Color(0xFFF9DEDC), onErrorContainer = Color(0xFF601410),
        inverseSurface = Color(0xFF172F29), inverseOnSurface = Color(0xFFF3F7F1), inversePrimary = Color(0xFFA9D8BF),
    )
    CompositionLocalProvider(LocalJedaDark provides dark) {
        MaterialTheme(colorScheme = colors, typography = JedaTypography, shapes = JedaShapes, content = content)
    }
}
