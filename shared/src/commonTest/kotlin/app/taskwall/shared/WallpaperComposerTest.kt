package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class WallpaperComposerTest {

    @Test
    fun showsTodaysTasksOnlyAndLabelsThem() {
        val content = WallpaperComposer.compose(
            listOf(
                task("report", minutes = 17 * 60, priority = Priority.HIGH),
                task("gym", due = CalendarDay(2026, 10, 18)),
                task("groceries", due = null),
                task("dentist", due = TODAY.plusDays(1)),
                task("private", onWallpaper = false),
                task("slides", done = true, completedAt = 10),
            ),
            TODAY,
            maxLines = 6,
        )
        assertEquals(listOf("report", "gym", "groceries", "slides"), content.lines.map { it.id })
        assertEquals("17:00", content.lines[0].detail)
        assertTrue(content.lines[0].isHighPriority)
        assertEquals("Overdue, 18 Oct", content.lines[1].detail)
        assertTrue(content.lines[1].isOverdue)
        assertNull(content.lines[2].detail)
        assertEquals("1 of 4 done", content.progressLabel)
        assertEquals(0, content.hiddenCount)
    }

    @Test
    fun openTasksWinTheSpaceWhenTheListIsLong() {
        val tasks = (1..8).map { task("open$it", order = it) } + task("done", done = true)
        val content = WallpaperComposer.compose(tasks, TODAY, maxLines = 6)
        assertEquals(6, content.lines.size)
        assertTrue(content.lines.none { it.isDone })
        assertEquals(2, content.hiddenCount)
        assertEquals(9, content.totalCount)
    }

    @Test
    fun finishedTasksFillLeftoverSpace() {
        val tasks = listOf(task("a"), task("b", done = true, completedAt = 1), task("c", done = true, completedAt = 2))
        val content = WallpaperComposer.compose(tasks, TODAY, maxLines = 2)
        assertEquals(listOf("a", "b"), content.lines.map { it.id })
        assertEquals(0, content.hiddenCount)
    }
}

class WallpaperStyleTest {

    @Test
    fun photoSourceNeedsAPhoto() {
        val style = WallpaperStyle()
        assertEquals(BackgroundSource.COLOR, style.withSource(BackgroundSource.PHOTO).source)
        val withPhoto = style.withPhoto("a.jpg").withFraming(2.0, 0.1, -0.1).withAnalysis(
            LegibilityResult(TextTone.DARK, Backdrop.CLEAR, 1.0, 5.0, 0.5),
        )
        // Picking a new photo resets framing and measurements.
        val replaced = withPhoto.withPhoto("b.jpg")
        assertEquals(1.0, replaced.photoZoom)
        assertNull(replaced.photoAnalysis)
        assertEquals(BackgroundSource.COLOR, withPhoto.withTheme(WallpaperTheme.SAGE).source)
        assertEquals(4.0, style.withFraming(9.0, 0.0, 0.0).photoZoom)
    }

    @Test
    fun sampleWallpaperMatchesTheDesign() {
        val content = SampleData.wallpaperContent(TODAY)
        assertEquals("2 of 5 done", content.progressLabel)
        assertEquals("Submit lab report", content.lines.first().title)
    }
}
