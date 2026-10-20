package app.taskwall.shared

/**
 * Colours for drawing the wallpaper, as 0xAARRGGBB.
 * [panelTint] and [shade] only matter on photos.
 */
data class WallpaperPalette(
    val background: Long,
    val foreground: Long,
    val muted: Long,
    val line: Long,
    /** Colour drawn on top of [foreground] (e.g. text inside the "High" badge). */
    val onForeground: Long,
    val panelTint: Long,
    val shade: Long,
)

enum class WallpaperTheme(val displayName: String, val palette: WallpaperPalette) {
    PAPER("Paper", WallpaperPalette(0xFFF5F5F7L, 0xFF000000L, 0xFF48484AL, 0x1F000000L, 0xFFFFFFFFL, 0L, 0L)),
    INK("Ink", WallpaperPalette(0xFF000000L, 0xFFFFFFFFL, 0xFFAEAEB2L, 0x2EFFFFFFL, 0xFF000000L, 0L, 0L)),
    SAGE("Sage", WallpaperPalette(0xFFDDE3D8L, 0xFF1D2A20L, 0xFF46564AL, 0x291D2A20L, 0xFFDDE3D8L, 0L, 0L)),
    CLAY("Clay", WallpaperPalette(0xFFECDFD3L, 0xFF3A2618L, 0xFF6B5242L, 0x293A2618L, 0xFFECDFD3L, 0L, 0L)),
    NAVY("Navy", WallpaperPalette(0xFF0F1C2EL, 0xFFE8EEF6L, 0xFF9FB0C6L, 0x29E8EEF6L, 0xFF0F1C2EL, 0L, 0L)),
}

/** How the wallpaper will actually be drawn once Auto has been resolved. */
data class ResolvedAppearance(
    val isPhoto: Boolean,
    val tone: TextTone,
    val backdrop: Backdrop,
    val palette: WallpaperPalette,
)

object WallpaperAppearance {

    val lightTextOnPhoto = WallpaperPalette(
        background = 0xFF3A3A3CL, foreground = 0xFFFFFFFFL, muted = 0xD6FFFFFFL, line = 0x4DFFFFFFL,
        onForeground = 0xFF000000L, panelTint = 0x6B121214L, shade = 0x80000000L,
    )

    val darkTextOnPhoto = WallpaperPalette(
        background = 0xFFD1D1D6L, foreground = 0xFF000000L, muted = 0xB3000000L, line = 0x29000000L,
        onForeground = 0xFFFFFFFFL, panelTint = 0x94FFFFFFL, shade = 0x99FFFFFFL,
    )

    fun resolve(style: WallpaperStyle): ResolvedAppearance {
        if (style.source == BackgroundSource.COLOR || style.photoFileName == null) {
            val palette = style.theme.palette
            val tone = if (isDark(palette.background)) TextTone.LIGHT else TextTone.DARK
            return ResolvedAppearance(isPhoto = false, tone = tone, backdrop = Backdrop.CLEAR, palette = palette)
        }
        val auto = style.photoAnalysis
        val tone = when (style.textTone) {
            ToneSetting.LIGHT -> TextTone.LIGHT
            ToneSetting.DARK -> TextTone.DARK
            ToneSetting.AUTOMATIC -> auto?.tone ?: TextTone.LIGHT
        }
        val backdrop = when (style.backdrop) {
            BackdropSetting.CLEAR -> Backdrop.CLEAR
            BackdropSetting.SHADE -> Backdrop.SHADE
            BackdropSetting.GLASS -> Backdrop.GLASS
            // Until the photo is measured, glass is the safe choice.
            BackdropSetting.AUTOMATIC -> auto?.backdrop ?: Backdrop.GLASS
        }
        val palette = if (tone == TextTone.LIGHT) lightTextOnPhoto else darkTextOnPhoto
        return ResolvedAppearance(isPhoto = true, tone = tone, backdrop = backdrop, palette = palette)
    }

    private fun isDark(argb: Long): Boolean {
        val r = ((argb shr 16) and 0xFF).toInt()
        val g = ((argb shr 8) and 0xFF).toInt()
        val b = (argb and 0xFF).toInt()
        return Contrast.relativeLuminance(r, g, b) < 0.18
    }
}
