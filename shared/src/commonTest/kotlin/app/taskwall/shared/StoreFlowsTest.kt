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
        val second = store.addTask("  Second  ", " notes ", Priority.NO_PRIORITY, null, null, false, 2)
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

        assertEquals(listOf("Anytime"), store.sections(TODAY, TaskFilter.TODAY).map { it.title })
        assertEquals(listOf("Yesterday"), store.sections(TODAY, TaskFilter.PAST).map { it.title })
        assertEquals(listOf(TODAY.plusDays(2)), store.sections(TODAY, TaskFilter.UPCOMING).map { it.day })
        assertEquals(TaskProgress(0, 2), store.todayProgress(TODAY))

        store.toggleDone(late.id, TODAY, 4)
        store.toggleDone(today.id, TODAY, 5)
        // Finished tasks stay under their date; the overdue one still counts towards today's progress.
        assertEquals(listOf("Anytime"), store.sections(TODAY, TaskFilter.TODAY).map { it.title })
        assertEquals(listOf(late.id), store.sections(TODAY, TaskFilter.PAST).single().tasks.map { it.id })
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
        store.setAutomation(store.settings.automation.withAutomationAdded(true))
        assertFalse(store.settings.automation.isSetUp, "needs one successful run")
        store.recordWallpaperUpdate(nowMillis = 1234, today = TODAY)
        assertTrue(store.settings.automation.isSetUp)
        assertEquals(1234L, store.settings.automation.lastUpdateMillis)
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

    // Keeping the Lock Screen current

    @Test
    fun completingATaskMakesTheWallpaperOutOfDate() {
        val store = newStore()
        val task = store.addQuickTask("Buy milk", 1)
        assertFalse(store.isWallpaperCurrent(TODAY), "never rendered")

        store.recordWallpaperUpdate(nowMillis = 10, today = TODAY)
        assertTrue(store.isWallpaperCurrent(TODAY))

        store.toggleDone(task.id, TODAY, 20)
        assertFalse(store.isWallpaperCurrent(TODAY), "the Lock Screen still shows it as open")
        store.recordWallpaperUpdate(nowMillis = 30, today = TODAY)
        assertTrue(store.isWallpaperCurrent(TODAY))
    }

    @Test
    fun styleChangesAndANewDayAlsoNeedAnUpdate() {
        val store = newStore()
        store.addTask("Dentist", "", Priority.NO_PRIORITY, TODAY.plusDays(1), null, true, 1)
        store.addQuickTask("Call mum", 2)
        store.recordWallpaperUpdate(nowMillis = 10, today = TODAY)

        store.setWallpaperStyle(store.settings.wallpaper.withTheme(WallpaperTheme.PAPER))
        assertFalse(store.isWallpaperCurrent(TODAY))
        store.recordWallpaperUpdate(nowMillis = 20, today = TODAY)

        // Tomorrow the dentist appointment joins the list.
        assertFalse(store.isWallpaperCurrent(TODAY.plusDays(1)))
    }

    @Test
    fun hiddenTasksDontMakeTheWallpaperStale() {
        val store = newStore()
        store.recordWallpaperUpdate(nowMillis = 10, today = TODAY)
        store.addTask("Private", "", Priority.NO_PRIORITY, TODAY, null, false, 11)
        store.addTask("Next week", "", Priority.NO_PRIORITY, TODAY.plusDays(7), null, true, 12)
        assertTrue(store.isWallpaperCurrent(TODAY))
    }

    @Test
    fun signatureIsTheSameInEveryProcess() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        app.addQuickTask("Shared", 1)
        // A second store on the same file stands in for the shortcut's process.
        assertEquals(app.wallpaperSignature(TODAY), newStore(file).wallpaperSignature(TODAY))
        newStore(file).recordWallpaperUpdate(nowMillis = 5, today = TODAY)
        app.reload()
        assertTrue(app.isWallpaperCurrent(TODAY))
    }

    @Test
    fun recognisesTheCloseAutomationFromItsTiming() {
        val store = newStore()
        store.recordAppClosed(nowMillis = 1_000)
        store.recordWallpaperUpdate(nowMillis = 1_000 + TaskWallStore.CLOSE_RUN_WINDOW_MILLIS + 1, today = TODAY)
        assertFalse(store.settings.automation.updatesWhenClosed, "too long after closing: a morning run")

        store.recordAppClosed(nowMillis = 500_000)
        store.recordWallpaperUpdate(nowMillis = 503_000, today = TODAY)
        assertTrue(store.settings.automation.updatesWhenClosed)

        // Later runs at other times don't undo it.
        store.recordWallpaperUpdate(nowMillis = 9_000_000, today = TODAY)
        assertTrue(store.settings.automation.updatesWhenClosed)
    }

    @Test
    fun aRunBeforeTheAppEverClosedIsNotTheCloseAutomation() {
        val store = newStore()
        store.recordWallpaperUpdate(nowMillis = 100, today = TODAY)
        assertFalse(store.settings.automation.updatesWhenClosed)
    }

    // The shortcut and the app share one file

    @Test
    fun shortcutRunSeenByTheAppAfterReload() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        val task = app.addQuickTask("Shared", 1)

        val shortcut = newStore(file)
        assertEquals(listOf(task), shortcut.tasks)
        shortcut.recordWallpaperUpdate(nowMillis = 7, today = TODAY)
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

    // Tester report: the shortcut worked when run in Shortcuts, but not from the close automation.

    @Test
    fun closeAutomationThatFinishesBeforeTheAppHearsItClosedIsKept() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        app.addQuickTask("Buy milk", 1)

        // The shortcut runs while the app is still open in the background...
        newStore(file).recordWallpaperUpdate(nowMillis = 10_000, today = TODAY)
        // ...then the app records that it closed, from its own copy of the data.
        app.recordAppClosed(nowMillis = 10_500)

        val saved = newStore(file)
        assertEquals(10_000L, saved.settings.automation.lastUpdateMillis, "the run isn't overwritten")
        assertTrue(saved.isWallpaperCurrent(TODAY))
        assertTrue(saved.settings.automation.updatesWhenClosed)
        assertEquals(saved.state, app.state)
    }

    @Test
    fun closeAutomationRunningJustAfterTheAppClosedIsRecognised() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        app.addQuickTask("Buy milk", 1)
        app.recordAppClosed(nowMillis = 10_000)
        newStore(file).recordWallpaperUpdate(nowMillis = 12_000, today = TODAY)

        app.reload()
        assertTrue(app.isWallpaperCurrent(TODAY))
        assertTrue(app.settings.automation.updatesWhenClosed)
    }

    @Test
    fun aRunLongBeforeClosingIsNotTheCloseAutomation() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        newStore(file).recordWallpaperUpdate(nowMillis = 1_000, today = TODAY)
        app.recordAppClosed(nowMillis = 1_000 + TaskWallStore.CLOSE_RUN_WINDOW_MILLIS + 1)
        assertFalse(app.settings.automation.updatesWhenClosed)
        assertEquals(1_000L, app.settings.automation.lastUpdateMillis)
    }

    @Test
    fun aTaskAddedBySiriWhileTheAppIsOpenIsKept() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        app.addQuickTask("From the app", 1)
        newStore(file).addQuickTask("From Siri", 2)

        app.addQuickTask("Also from the app", 3)
        assertEquals(listOf("From the app", "From Siri", "Also from the app"), newStore(file).tasks.map { it.title })
        assertEquals(listOf(0, 1, 2), app.tasks.map { it.sortOrder })
    }

    @Test
    fun everyKindOfChangeBuildsOnWhatTheShortcutSaved() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        val task = app.addQuickTask("Buy milk", 1)
        val shortcut = newStore(file)
        shortcut.recordWallpaperUpdate(nowMillis = 5, today = TODAY)

        app.toggleDone(task.id, TODAY, 6)
        app.setWallpaperStyle(app.settings.wallpaper.withLayout(WallpaperLayout.TABLE))
        app.setScreen(ScreenMetrics(393.0, 852.0, 3.0))
        app.clearCompleted()
        assertEquals(5L, newStore(file).settings.automation.lastUpdateMillis)
    }

    @Test
    fun theAppSeesWhatTheShortcutSavedWhenItChangesSomething() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        var latest: AppState? = null
        app.addListener { latest = it }
        newStore(file).addQuickTask("From Siri", 1)

        app.recordAppClosed(nowMillis = 2)
        assertEquals("From Siri", latest?.tasks?.single()?.title)
    }

    @Test
    fun anUnreadableFileDoesNotWipeTheAppsCopy() {
        val file = InMemoryTextFileStore()
        val app = newStore(file)
        app.addQuickTask("Buy milk", 1)
        file.write("not json")
        app.addQuickTask("Bread", 2)
        assertEquals(listOf("Buy milk", "Bread"), newStore(file).tasks.map { it.title })
    }

    @Test
    fun oldFilesWithUnknownFieldsStillOpen() {
        val json = """{"version":1,"tasks":[{"id":"a","title":"Old","futureField":true}],"settings":{"newThing":1}}"""
        val store = newStore(InMemoryTextFileStore(json))
        assertEquals("Old", store.tasks.single().title)
        assertEquals(WallpaperStyle(), store.settings.wallpaper)
    }
}
