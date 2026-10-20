package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** One test per thing a person can do in the app, run against the shared store. */
class StoreFlowsTest {

    private fun newStore(file: InMemoryTextFileStore = InMemoryTextFileStore()) = TaskWallStore(file)

    // Onboarding

    @Test
    fun onboardingCompletesOnceAndSurvivesRestart() {
        val file = InMemoryTextFileStore()
        val store = newStore(file)
        assertFalse(store.settings.onboardingComplete)
        store.addQuickTask("Reply to emails", 1)
        store.completeOnboarding()
        assertTrue(store.settings.onboardingComplete)

        val reopened = newStore(file)
        assertTrue(reopened.settings.onboardingComplete)
        assertEquals(listOf("Reply to emails"), reopened.tasks.map { it.title })
    }

    // New task / edit task

    @Test
    fun newTaskTrimsTextAndGoesToTheEnd() {
        val store = newStore()
        store.addQuickTask("First", 1)
        val second = store.addTask("  Second  ", " notes ", Priority.MEDIUM, TODAY, 9 * 60, false, 2)
        assertEquals("Second", second.title)
        assertEquals("notes", second.notes)
        assertEquals(1, second.sortOrder)
        assertEquals(2L, second.createdAtMillis)
        assertFalse(second.showOnWallpaper)
        assertEquals(listOf("First", "Second"), store.tasks.map { it.title })
    }

    @Test
    fun editingKeepsIdentityAndDropsTimeWithoutADate() {
        val store = newStore()
        val task = store.addTask("Dentist", "", Priority.LOW, TODAY, 10 * 60, true, 1)
        store.setDone(task.id, true, TODAY, 5)
        store.updateTask(store.tasks.single().edited("Dentist appointment", "Bring card", Priority.HIGH, null, 10 * 60, true))

        val edited = store.tasks.single()
        assertEquals(task.id, edited.id)
        assertEquals("Dentist appointment", edited.title)
        assertEquals(Priority.HIGH, edited.priority)
        assertNull(edited.dueDay)
        assertNull(edited.dueMinutes, "a time without a date means nothing")
        assertTrue(edited.isDone, "editing never changes whether it's done")
        assertEquals(1L, edited.createdAtMillis)
    }

    @Test
    fun updatingAnUnknownTaskChangesNothing() {
        val store = newStore()
        store.addQuickTask("Only", 1)
        var notified = 0
        store.addListener { notified++ }
        store.updateTask(TaskItem("missing", "Ghost"))
        assertEquals(1, notified)
        assertEquals(listOf("Only"), store.tasks.map { it.title })
    }

    @Test
    fun rejectsImpossibleTimesAndDates() {
        assertFailsWith<IllegalArgumentException> { TaskItem("x", "Bad", dueMinutes = 24 * 60) }
        assertFailsWith<IllegalArgumentException> { TaskItem("x", "Bad", dueMinutes = -1) }
        assertFailsWith<IllegalArgumentException> { CalendarDay(2026, 2, 29) }
        assertFailsWith<IllegalArgumentException> { CalendarDay(2026, 13, 1) }
        CalendarDay(2028, 2, 29) // leap year
    }

    // Tasks list

    @Test
    fun deletingAndTogglingUnknownIdsIsHarmless() {
        val store = newStore()
        val task = store.addQuickTask("Keep", 1)
        store.deleteTask("nope")
        store.toggleDone("nope", TODAY, 2)
        assertEquals(listOf(task), store.tasks)
        store.deleteTask(task.id)
        assertTrue(store.tasks.isEmpty())
    }

    @Test
    fun sectionsAndProgressFollowTheTasks() {
        val store = newStore()
        val late = store.addTask("Late", "", Priority.NO_PRIORITY, TODAY.plusDays(-1), null, true, 1)
        val today = store.addQuickTask("Today", 2)
        store.addTask("Later", "", Priority.NO_PRIORITY, TODAY.plusDays(2), null, true, 3)

        assertEquals(
            listOf(SectionKind.OVERDUE, SectionKind.ANYTIME, SectionKind.UPCOMING),
            store.sections(TODAY, TaskFilter.ALL).map { it.kind },
        )
        assertEquals(TaskProgress(0, 2), store.todayProgress(TODAY))

        store.toggleDone(late.id, TODAY, 4)
        store.toggleDone(today.id, TODAY, 5)
        // A finished overdue task moves into Today; an undated one stays in Anytime.
        assertEquals(
            listOf(SectionKind.TODAY, SectionKind.ANYTIME, SectionKind.UPCOMING),
            store.sections(TODAY, TaskFilter.ALL).map { it.kind },
        )
        assertEquals(TaskProgress(2, 2), store.todayProgress(TODAY))
        assertEquals(1.0, store.todayProgress(TODAY).fraction)
    }

    @Test
    fun clearCompletedEachMorningCanBeTurnedOff() {
        val store = newStore()
        assertTrue(store.settings.clearCompletedEachMorning)
        store.setClearCompletedEachMorning(false)
        assertFalse(store.settings.clearCompletedEachMorning)
        val t = store.addQuickTask("Done yesterday", 1)
        store.setDone(t.id, true, TODAY.plusDays(-1), 2)
        assertEquals(0, store.clearCompletedIfDue(TODAY))
        store.setClearCompletedEachMorning(true)
        assertEquals(1, store.clearCompletedIfDue(TODAY))
    }

    @Test
    fun clearingRunsAgainOnTheNextDay() {
        val store = newStore()
        val a = store.addQuickTask("A", 1)
        store.setDone(a.id, true, TODAY, 2)
        assertEquals(0, store.clearCompletedIfDue(TODAY), "today's finished tasks stay until tomorrow")
        assertEquals(1, store.clearCompletedIfDue(TODAY.plusDays(1)))
        assertEquals(TODAY.plusDays(1), store.settings.lastClearedDay)
    }

    // Search

    @Test
    fun searchMatchesTitleAndNotesIgnoringCase() {
        val store = newStore()
        store.addTask("Buy milk", "and eggs", Priority.NO_PRIORITY, null, null, true, 1)
        store.addTask("Call mum", "", Priority.HIGH, TODAY, null, true, 2)
        store.addTask("Pay rent", "", Priority.NO_PRIORITY, TODAY.plusDays(1), null, true, 3)

        assertEquals(listOf("Buy milk"), store.search("MILK", TODAY).map { it.title })
        assertEquals(listOf("Buy milk"), store.search("eggs", TODAY).map { it.title })
        assertEquals(listOf("Call mum", "Buy milk"), store.search("m", TODAY).map { it.title }, "high priority first")
        assertTrue(store.search("   ", TODAY).isEmpty())
        assertTrue(store.search("zzz", TODAY).isEmpty())
    }

    // Wallpaper

    @Test
    fun wallpaperContentUsesTheChosenLayout() {
        val store = newStore()
        repeat(9) { store.addQuickTask("Task $it", it.toLong()) }
        assertEquals(6, store.wallpaperContent(TODAY).lines.size)
        assertEquals(3, store.wallpaperContent(TODAY).hiddenCount)

        store.setWallpaperStyle(store.settings.wallpaper.withLayout(WallpaperLayout.TABLE).withShowProgress(false))
        assertEquals(8, store.wallpaperContent(TODAY).lines.size)
        assertEquals(1, store.wallpaperContent(TODAY).hiddenCount)
    }

    @Test
    fun colourThemesResolveWithoutAPhoto() {
        val store = newStore()
        store.setWallpaperStyle(store.settings.wallpaper.withTheme(WallpaperTheme.PAPER))
        val paper = store.resolvedAppearance()
        assertFalse(paper.isPhoto)
        assertEquals(TextTone.DARK, paper.tone)
        assertEquals(Backdrop.CLEAR, paper.backdrop)

        store.setWallpaperStyle(store.settings.wallpaper.withTheme(WallpaperTheme.NAVY))
        assertEquals(TextTone.LIGHT, store.resolvedAppearance().tone)
    }

    @Test
    fun choosingAPhotoThenAColourKeepsThePhotoForLater() {
        val store = newStore()
        store.setWallpaperStyle(store.settings.wallpaper.withPhoto("p.jpg"))
        assertEquals(BackgroundSource.PHOTO, store.settings.wallpaper.source)
        assertTrue(store.resolvedAppearance().isPhoto)

        store.setWallpaperStyle(store.settings.wallpaper.withTheme(WallpaperTheme.SAGE))
        assertEquals(BackgroundSource.COLOR, store.settings.wallpaper.source)
        assertTrue(store.settings.wallpaper.hasPhoto)
        assertFalse(store.resolvedAppearance().isPhoto)

        store.setWallpaperStyle(store.settings.wallpaper.withSource(BackgroundSource.PHOTO))
        assertEquals("p.jpg", store.settings.wallpaper.photoFileName)
        assertTrue(store.resolvedAppearance().isPhoto)
    }

    @Test
    fun unmeasuredPhotoFallsBackToGlassWithWhiteText() {
        val store = newStore()
        store.setWallpaperStyle(store.settings.wallpaper.withPhoto("p.jpg"))
        val look = store.resolvedAppearance()
        assertEquals(Backdrop.GLASS, look.backdrop)
        assertEquals(TextTone.LIGHT, look.tone)
        assertEquals(WallpaperAppearance.lightTextOnPhoto, look.palette)
    }

    @Test
    fun reframingStaysWithinLimits() {
        val style = WallpaperStyle().withPhoto("p.jpg")
        assertEquals(1.0, style.withFraming(0.2, 0.0, 0.0).photoZoom)
        assertEquals(4.0, style.withFraming(40.0, 0.0, 0.0).photoZoom)
        val moved = style.withFraming(2.0, 0.25, -0.25)
        assertEquals(0.25, moved.photoOffsetX)
        assertEquals(-0.25, moved.photoOffsetY)
    }

    @Test
    fun legibilityAnalysisIsSavedWithTheStyle() {
        val file = InMemoryTextFileStore()
        val store = newStore(file)
        val analysis = LegibilityAnalyzer.analyzeLuminance(DoubleArray(100) { if (it < 50) 0.0 else 1.0 })
        assertEquals(Backdrop.GLASS, analysis.backdrop, "half black, half white is unreadable without glass")
        store.setWallpaperStyle(store.settings.wallpaper.withPhoto("p.jpg").withAnalysis(analysis))
        assertEquals(analysis, newStore(file).settings.wallpaper.photoAnalysis)
    }

    // Automatic updates

    @Test
    fun automationSetupIsDoneAfterTheFirstRun() {
        val store = newStore()
        assertFalse(store.settings.automation.isSetUp)
        store.setAutomation(store.settings.automation.withShortcutAdded(true))
        store.setAutomation(store.settings.automation.withRunsWithoutAsking(true))
        assertFalse(store.settings.automation.isSetUp, "needs one successful run")
        store.recordWallpaperUpdate(nowMillis = 1234)
        assertTrue(store.settings.automation.isSetUp)
        assertEquals(1234L, store.settings.automation.lastUpdateMillis)
    }

    @Test
    fun morningTimeIsClampedToTheDay() {
        val store = newStore()
        store.setAutomation(store.settings.automation.withMorningMinutes(25 * 60))
        assertEquals(24 * 60 - 1, store.settings.automation.morningMinutes)
        store.setAutomation(store.settings.automation.withMorningMinutes(-5))
        assertEquals(0, store.settings.automation.morningMinutes)
        store.setAutomation(store.settings.automation.withMorningMinutes(6 * 60 + 30).withUpdateWhenAppCloses(false))
        assertEquals(6 * 60 + 30, store.settings.automation.morningMinutes)
        assertFalse(store.settings.automation.updateWhenAppCloses)
    }

    @Test
    fun screenMetricsAreSavedOnceForTheShortcut() {
        val file = InMemoryTextFileStore()
        val store = newStore(file)
        var writes = 0
        store.addListener { writes++ }
        val metrics = ScreenMetrics(393.0, 852.0, 3.0)
        store.setScreen(metrics)
        store.setScreen(metrics)
        assertEquals(2, writes, "same metrics again shouldn't notify")
        assertEquals(metrics, newStore(file).settings.screen)
    }

    // The shortcut and the app share one file

    @Test
    fun shortcutRunSeenByTheAppAfterReload() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        val task = app.addQuickTask("Shared", 1)

        val shortcut = newStore(file)
        assertEquals(listOf(task), shortcut.tasks)
        shortcut.recordWallpaperUpdate(nowMillis = 7)
        val content = shortcut.wallpaperContent(TODAY)
        assertEquals("Shared", content.lines.single().title)

        var notified = 0
        app.addListener { notified++ }
        app.reload()
        assertEquals(2, notified)
        assertEquals(7L, app.settings.automation.lastUpdateMillis)
        app.reload()
        assertEquals(2, notified, "an unchanged file doesn't notify")
    }

    @Test
    fun oldFilesWithUnknownFieldsStillOpen() {
        val json = """{"version":1,"tasks":[{"id":"a","title":"Old","futureField":true}],"settings":{"newThing":1}}"""
        val store = newStore(InMemoryTextFileStore(json))
        assertEquals("Old", store.tasks.single().title)
        assertEquals(WallpaperStyle(), store.settings.wallpaper)
    }

    // Tips

    @Test
    fun tipsMapToTheirProducts() {
        assertEquals(Tip.FLAT_WHITE, Tip.forProductId("app.taskwall.tip.flatwhite"))
        assertNull(Tip.forProductId("app.taskwall.tip.gold"))
        assertEquals(1, Tip.entries.count { it.isPopular })
    }
}
