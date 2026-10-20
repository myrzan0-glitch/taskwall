package app.taskwall.shared

import kotlin.math.pow

/** WCAG 2 relative luminance and contrast ratio. */
object Contrast {

    /** Relative luminance (0 = black, 1 = white) of an sRGB colour with 0-255 channels. */
    fun relativeLuminance(red: Int, green: Int, blue: Int): Double =
        0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)

    /** Contrast ratio between two luminances, from 1.0 to 21.0. */
    fun ratio(luminanceA: Double, luminanceB: Double): Double {
        val lighter = maxOf(luminanceA, luminanceB)
        val darker = minOf(luminanceA, luminanceB)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private fun linear(channel: Int): Double {
        val c = channel.coerceIn(0, 255) / 255.0
        return if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }
}
