package app.taskwall.shared

import kotlinx.serialization.Serializable

/** What Auto decided for a photo, plus the measurements behind it. */
@Serializable
data class LegibilityResult(
    val tone: TextTone,
    val backdrop: Backdrop,
    /** Contrast of white text against the brighter spots behind the tasks. */
    val whiteContrast: Double,
    /** Contrast of black text against the darker spots behind the tasks. */
    val blackContrast: Double,
    val meanLuminance: Double,
)

/**
 * Decides how to keep tasks readable on a photo.
 *
 * It measures the part of the photo behind the task list, counting its
 * brightest and darkest spots rather than the average. It picks the text
 * colour with more contrast, then the lightest backdrop that keeps the text
 * readable: none at 4.5:1 or more, a soft shade from 3:1, frosted glass
 * below that. On glass the text colour follows the photo's average brightness.
 */
object LegibilityAnalyzer {
    const val CLEAR_MIN_CONTRAST = 4.5
    const val SHADE_MIN_CONTRAST = 3.0
    /** Share of pixels allowed to be worse than the measured contrast. */
    const val WORST_CASE_SHARE = 0.10
    /** On glass, photos darker than this get white text. */
    const val GLASS_LIGHT_TEXT_BELOW = 0.25

    private const val WHITE = 1.0
    private const val BLACK = 0.0

    fun analyzeLuminance(luminances: DoubleArray): LegibilityResult {
        require(luminances.isNotEmpty()) { "Need at least one sample" }
        val sorted = luminances.sortedArray()
        val last = sorted.size - 1
        val brightSpot = sorted[(sorted.size * (1 - WORST_CASE_SHARE)).toInt().coerceAtMost(last)]
        val darkSpot = sorted[(sorted.size * WORST_CASE_SHARE).toInt().coerceAtMost(last)]
        val mean = sorted.average()

        val whiteContrast = Contrast.ratio(WHITE, brightSpot)
        val blackContrast = Contrast.ratio(darkSpot, BLACK)
        val best = maxOf(whiteContrast, blackContrast)
        val bestTone = if (whiteContrast >= blackContrast) TextTone.LIGHT else TextTone.DARK

        val (tone, backdrop) = when {
            best >= CLEAR_MIN_CONTRAST -> bestTone to Backdrop.CLEAR
            best >= SHADE_MIN_CONTRAST -> bestTone to Backdrop.SHADE
            else -> (if (mean < GLASS_LIGHT_TEXT_BELOW) TextTone.LIGHT else TextTone.DARK) to Backdrop.GLASS
        }
        return LegibilityResult(tone, backdrop, whiteContrast, blackContrast, mean)
    }

    /**
     * Analyse raw RGBA pixels (4 bytes per pixel, any order of rows) taken from
     * [WallpaperGeometry.analysisRegion]. A small downscaled copy (e.g. 64x64) is plenty.
     */
    fun analyzeRgba(rgba: ByteArray): LegibilityResult {
        require(rgba.size >= 4 && rgba.size % 4 == 0) { "Expected RGBA bytes" }
        val pixels = rgba.size / 4
        val luminances = DoubleArray(pixels) { i ->
            val o = i * 4
            Contrast.relativeLuminance(
                rgba[o].toInt() and 0xFF,
                rgba[o + 1].toInt() and 0xFF,
                rgba[o + 2].toInt() and 0xFF,
            )
        }
        return analyzeLuminance(luminances)
    }
}
