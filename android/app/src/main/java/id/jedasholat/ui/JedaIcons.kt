package id.jedasholat.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import id.jedasholat.core.Prayer

/** Small original 24dp stroke set. Vectors are cached; no icon font or network dependency. */
enum class JedaGlyph {
    HOME, CALENDAR, GRID, SETTINGS, MOON, SUNRISE, SUN, SUNSET, STARS,
    SHIELD, CHECK, BELL, PIN, SEARCH, CLOSE, REFRESH, CHEVRON, ARROW,
    PHONE, PLAY, PAUSE, LOCK, INFO, TRASH, PLUS, MINUS, PALETTE, OFFLINE
}

private val cache = mutableMapOf<JedaGlyph, ImageVector>()
private val paths = mapOf(
    JedaGlyph.HOME to "M3,10L12,3L21,10M5,9V20H9V14H15V20H19V9",
    JedaGlyph.CALENDAR to "M7,3V6M17,3V6M4,5H20V21H4ZM4,10H20M8,14H10M14,14H16M8,17H10",
    JedaGlyph.GRID to "M4,4H10V10H4ZM14,4H20V10H14ZM4,14H10V20H4ZM14,14H20V20H14Z",
    JedaGlyph.SETTINGS to "M9,3H15L16,6L19,7L21,10L19,12L21,15L19,18L16,18L15,21H9L8,18L5,17L3,14L5,12L3,9L5,6L8,6ZM15,12A3,3 0,1 0,9 12A3,3 0,1 0,15 12",
    JedaGlyph.MOON to "M19,15A8,8 0,1 1,9 4A7,7 0,0 0,19 15Z",
    JedaGlyph.SUNRISE to "M3,17H21M5,21H19M7,17A5,5 0,0 1,17 17M12,3V8M4,8L7,11M20,8L17,11M2,13H4M20,13H22",
    JedaGlyph.SUN to "M16,12A4,4 0,1 0,8 12A4,4 0,1 0,16 12M12,2V4M12,20V22M2,12H4M20,12H22M5,5L6.5,6.5M17.5,17.5L19,19M5,19L6.5,17.5M17.5,6.5L19,5",
    JedaGlyph.SUNSET to "M3,17H21M5,21H19M7,17A5,5 0,0 1,17 17M12,3V9M9,6L12,9L15,6M4,10L6,12M20,10L18,12",
    JedaGlyph.STARS to "M12,3L14.5,9.5L21,12L14.5,14.5L12,21L9.5,14.5L3,12L9.5,9.5ZM20,2V6M18,4H22",
    JedaGlyph.SHIELD to "M12,3L20,6V12C20,17 16,20 12,22C8,20 4,17 4,12V6ZM8,12L11,15L16,9",
    JedaGlyph.CHECK to "M5,12L10,17L20,6",
    JedaGlyph.BELL to "M6,9A6,6 0,0 1,18 9V15L20,18H4L6,15ZM10,21H14M12,2V3",
    JedaGlyph.PIN to "M19,10C19,15 12,22 12,22C12,22 5,15 5,10A7,7 0,0 1,19 10ZM14.5,10A2.5,2.5 0,1 0,9.5 10A2.5,2.5 0,1 0,14.5 10",
    JedaGlyph.SEARCH to "M17,10A7,7 0,1 0,3 10A7,7 0,1 0,17 10M15,15L21,21",
    JedaGlyph.CLOSE to "M6,6L18,18M18,6L6,18",
    JedaGlyph.REFRESH to "M20,8A8,8 0,1 0,20 16M20,3V8H15",
    JedaGlyph.CHEVRON to "M9,5L16,12L9,19",
    JedaGlyph.ARROW to "M4,12H20M14,6L20,12L14,18",
    JedaGlyph.PHONE to "M7,3H4C3,3 3,5 3,7C4,14 10,20 17,21C19,21 21,21 21,20V17L16,15L14,18C10,16 8,14 6,10L9,8Z",
    JedaGlyph.PLAY to "M8,4L20,12L8,20Z",
    JedaGlyph.PAUSE to "M7,4H9V20H7ZM15,4H17V20H15Z",
    JedaGlyph.LOCK to "M7,10V7A5,5 0,0 1,17 7V10M5,10H19V21H5ZM12,14V17",
    JedaGlyph.INFO to "M21,12A9,9 0,1 0,3 12A9,9 0,1 0,21 12M12,11V17M12,7V7.2",
    JedaGlyph.TRASH to "M4,6H20M9,6V3H15V6M6,6L7,21H17L18,6M10,10V17M14,10V17",
    JedaGlyph.PLUS to "M12,5V19M5,12H19",
    JedaGlyph.MINUS to "M5,12H19",
    JedaGlyph.PALETTE to "M12,3A9,9 0,0 0,12 21H14C16,21 16,18 14,17C13,15 14,14 16,14H18C21,14 22,11 20,8C18,5 15,3 12,3ZM7,10V10.2M10,7V7.2M15,7V7.2M18,10V10.2",
    JedaGlyph.OFFLINE to "M5,9A11,11 0,0 1,19 9M8,12A7,7 0,0 1,16 12M11,15A2,2 0,0 1,13 15M12,18V18.2M3,3L21,21",
)

fun jedaIcon(glyph: JedaGlyph): ImageVector = cache.getOrPut(glyph) {
    ImageVector.Builder(glyph.name, 24.dp, 24.dp, 24f, 24f).addPath(
        pathData = PathParser().parsePathString(paths.getValue(glyph)).toPath(), fill = null, stroke = SolidColor(Color.Black),
        strokeLineWidth = 1.8f, strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
    ).build()
}

@Composable fun JedaIcon(glyph: JedaGlyph, contentDescription: String? = null, modifier: Modifier = Modifier.size(24.dp), tint: Color = LocalContentColor.current) {
    Icon(jedaIcon(glyph), contentDescription, modifier, tint)
}

fun prayerGlyph(prayer: Prayer): JedaGlyph = when (prayer) {
    Prayer.SUBUH -> JedaGlyph.SUNRISE; Prayer.DZUHUR -> JedaGlyph.SUN; Prayer.ASHAR -> JedaGlyph.SUNSET
    Prayer.MAGHRIB -> JedaGlyph.MOON; Prayer.ISYA -> JedaGlyph.STARS
}

/** The same crescent-and-pause identity used by the adaptive launcher icon. */
@Composable fun JedaMark(size: Dp = 40.dp, crescent: Color = Color(0xFFF3F7F1), bars: Color = Gold, modifier: Modifier = Modifier) {
    Canvas(modifier.then(Modifier.size(size))) {
        val s = this.size.minDimension / 108f
        val moon = Path().apply {
            moveTo(59f * s, 27f * s)
            arcTo(Rect(Offset(25.999f * s, 26.723f * s), Size(58f * s, 58f * s)), -82.07f, -243.79f, false)
            arcTo(Rect(Offset(47.957f * s, 22.741f * s), Size(50f * s, 50f * s)), 76.01f, 160.05f, false)
            close()
        }
        drawPath(moon, crescent)
        drawRoundRect(bars, Offset(56f * s, 44f * s), Size(7f * s, 27f * s), CornerRadius(3f * s))
        drawRoundRect(bars, Offset(68f * s, 44f * s), Size(7f * s, 27f * s), CornerRadius(3f * s))
    }
}
