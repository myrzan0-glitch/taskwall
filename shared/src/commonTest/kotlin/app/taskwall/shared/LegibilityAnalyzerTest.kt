package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class LegibilityAnalyzerTest {

    private fun mix(vararg parts: Pair<Int, Double>): DoubleArray =
        parts.flatMap { (count, luminance) -> List(count) { luminance } }.toDoubleArray()

    @Test
    fun brightPhotoGetsBlackTextAndNoBackdrop() {
        val result = LegibilityAnalyzer.analyzeLuminance(mix(10 to 0.9))
        assertEquals(TextTone.DARK, result.tone)
        assertEquals(Backdrop.CLEAR, result.backdrop)
    }

    @Test
    fun darkPhotoGetsWhiteTextAndNoBackdrop() {
        val result = LegibilityAnalyzer.analyzeLuminance(mix(10 to 0.01))
        assertEquals(TextTone.LIGHT, result.tone)
        assertEquals(Backdrop.CLEAR, result.backdrop)
    }

    @Test
    fun middlingContrastGetsAShade() {
        val dark = LegibilityAnalyzer.analyzeLuminance(mix(5 to 0.12, 5 to 0.5))
        assertEquals(TextTone.DARK, dark.tone)
        assertEquals(Backdrop.SHADE, dark.backdrop)

        val light = LegibilityAnalyzer.analyzeLuminance(mix(5 to 0.02, 5 to 0.25))
        assertEquals(TextTone.LIGHT, light.tone)
        assertEquals(Backdrop.SHADE, light.backdrop)
    }

    @Test
    fun busyPhotoGetsGlassAndTextFollowsAverageBrightness() {
        val mostlyBright = LegibilityAnalyzer.analyzeLuminance(mix(5 to 0.02, 5 to 0.9))
        assertEquals(Backdrop.GLASS, mostlyBright.backdrop)
        assertEquals(TextTone.DARK, mostlyBright.tone)

        val mostlyDark = LegibilityAnalyzer.analyzeLuminance(mix(8 to 0.02, 2 to 0.9))
        assertEquals(Backdrop.GLASS, mostlyDark.backdrop)
        assertEquals(TextTone.LIGHT, mostlyDark.tone)
    }

    @Test
    fun readsRgbaPixels() {
        val white = byteArrayOf(-1, -1, -1, -1)
        val result = LegibilityAnalyzer.analyzeRgba(white + white + white + white)
        assertEquals(TextTone.DARK, result.tone)
        assertTrue(result.blackContrast > 20.9)
    }

    @Test
    fun contrastMatchesWcagReferenceValues() {
        assertEquals(21.0, Contrast.ratio(1.0, 0.0), 1e-9)
        val grey = Contrast.relativeLuminance(0x6E, 0x6E, 0x73)
        assertTrue(Contrast.ratio(1.0, grey) > 4.5, "secondary label grey must pass on white")
    }
}
