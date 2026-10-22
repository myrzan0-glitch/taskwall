package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class WallpaperFontTest {

    @Test
    fun savedStylesFromBeforeFontsUseClassic() {
        // A wallpaper saved by a version without fonts has no "font" key.
        val old = """{"version":1,"settings":{"onboardingComplete":true,"wallpaper":{"theme":"NAVY","layout":"TABLE"}}}"""
        val store = TaskWallStore(InMemoryTextFileStore(old))
        val style = store.settings.wallpaper
        assertEquals(WallpaperFont.CLASSIC, style.font)
        assertEquals(WallpaperTheme.NAVY, style.theme)
        assertEquals(WallpaperLayout.TABLE, style.layout)
    }

    @Test
    fun fontIsSavedAndReopened() {
        val file = InMemoryTextFileStore()
        TaskWallStore(file).setWallpaperStyle(WallpaperStyle().withFont(WallpaperFont.MATRIX))
        assertEquals(WallpaperFont.MATRIX, TaskWallStore(file).settings.wallpaper.font)
    }

    @Test
    fun onlyClassicIsFree() {
        assertFalse(WallpaperFont.CLASSIC.isPro)
        assertTrue(WallpaperFont.MATRIX.isPro)
        assertTrue(WallpaperFont.ORBIT.isPro)
    }

    @Test
    fun losingProKeepsEverythingButTheFont() {
        val pro = WallpaperStyle().withTheme(WallpaperTheme.SIGNAL).withLayout(WallpaperLayout.TABLE).withFont(WallpaperFont.ORBIT)
        val free = pro.withoutProFeatures()
        assertEquals(WallpaperFont.CLASSIC, free.font)
        assertEquals(WallpaperTheme.SIGNAL, free.theme)
        assertEquals(WallpaperLayout.TABLE, free.layout)
        val classic = WallpaperStyle().withLayout(WallpaperLayout.TABLE)
        assertEquals(classic, classic.withoutProFeatures())
    }

    @Test
    fun changingTheFontMakesTheLockScreenOutOfDate() {
        val store = TaskWallStore(InMemoryTextFileStore())
        val before = store.wallpaperSignature(CalendarDay(2026, 10, 21))
        store.setWallpaperStyle(store.settings.wallpaper.withFont(WallpaperFont.MATRIX))
        assertTrue(before != store.wallpaperSignature(CalendarDay(2026, 10, 21)))
    }

    @Test
    fun signalIsOfferedInPlaceOfSageAndKeepsTheFlagVisible() {
        assertEquals(
            listOf(WallpaperTheme.PAPER, WallpaperTheme.INK, WallpaperTheme.SIGNAL, WallpaperTheme.CLAY, WallpaperTheme.NAVY),
            WallpaperTheme.picker,
        )
        // A red flag would vanish on the red Signal background, so it uses the text colour.
        val signal = WallpaperTheme.SIGNAL.palette
        assertEquals(signal.foreground, signal.flag)
        assertEquals(0xFFFF5F57L, WallpaperTheme.INK.palette.flag)
    }

    @Test
    fun proPlansAreFoundByProductId() {
        assertEquals(ProPlan.YEARLY, ProPlan.forProductId("app.taskwall.pro.yearly"))
        assertEquals(ProPlan.MONTHLY, ProPlan.forProductId("app.taskwall.pro.monthly"))
        assertEquals(null, ProPlan.forProductId("app.taskwall.tip.espresso"))
    }
}
