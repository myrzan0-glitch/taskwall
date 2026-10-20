package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class TaskWallStoreTest {

    @Test
    fun savesEveryChangeAndReadsItBack() {
        val file = InMemoryTextFileStore()
        val store = TaskWallStore(file)
        val added = store.addTask("Submit lab report", "Appendix B", Priority.HIGH, TODAY, 17 * 60, true, nowMillis = 1)
        store.setWallpaperStyle(store.settings.wallpaper.copy(source = BackgroundSource.PHOTO, photoFileName = "photo.jpg"))

        val reopened = TaskWallStore(file)
        assertEquals(listOf(added), reopened.tasks)
        assertEquals(BackgroundSource.PHOTO, reopened.settings.wallpaper.source)
    }

    @Test
    fun togglesDoneWithTheDayItWasFinished() {
        val store = TaskWallStore(InMemoryTextFileStore())
        val t = store.addQuickTask("Buy groceries", nowMillis = 1)
        store.toggleDone(t.id, TODAY, nowMillis = 50)
        val done = store.tasks.single()
        assertTrue(done.isDone)
        assertEquals(TODAY, done.completedOn)
        assertEquals(50L, done.completedAtMillis)

        store.toggleDone(t.id, TODAY, nowMillis = 60)
        assertFalse(store.tasks.single().isDone)
    }

    @Test
    fun clearsYesterdaysFinishedTasksOncePerDay() {
        val store = TaskWallStore(InMemoryTextFileStore())
        val old = store.addQuickTask("Old", 1)
        val fresh = store.addQuickTask("Fresh", 2)
        val open = store.addQuickTask("Open", 3)
        store.setDone(old.id, true, TODAY.plusDays(-1), 10)
        store.setDone(fresh.id, true, TODAY, 20)

        assertEquals(1, store.clearCompletedIfDue(TODAY))
        assertEquals(listOf(fresh.id, open.id), store.tasks.map { it.id })
        assertEquals(0, store.clearCompletedIfDue(TODAY))
    }

    @Test
    fun clearCompletedRemovesAllFinishedTasks() {
        val store = TaskWallStore(InMemoryTextFileStore())
        val done = store.addQuickTask("Done", 1)
        store.addQuickTask("Open", 2)
        store.setDone(done.id, true, TODAY, 3)
        assertEquals(1, store.clearCompleted())
        assertEquals(listOf("Open"), store.tasks.map { it.title })
    }

    @Test
    fun leavesFinishedTasksWhenClearingIsOff() {
        val store = TaskWallStore(InMemoryTextFileStore())
        store.updateSettings { it.copy(clearCompletedEachMorning = false) }
        val t = store.addQuickTask("Keep me", 1)
        store.setDone(t.id, true, TODAY.plusDays(-3), 10)
        assertEquals(0, store.clearCompletedIfDue(TODAY))
        assertEquals(1, store.tasks.size)
    }

    @Test
    fun notifiesListenersUntilClosed() {
        val store = TaskWallStore(InMemoryTextFileStore())
        var calls = 0
        val subscription = store.addListener { calls++ }
        assertEquals(1, calls) // current state on subscribe
        store.addQuickTask("One", 1)
        assertEquals(2, calls)
        subscription.close()
        store.addQuickTask("Two", 2)
        assertEquals(2, calls)
    }

    @Test
    fun reloadPicksUpChangesFromAnotherProcess() {
        val file = InMemoryTextFileStore()
        val app = TaskWallStore(file)
        val shortcut = TaskWallStore(file)
        shortcut.recordWallpaperUpdate(nowMillis = 99)
        app.reload()
        assertEquals(99L, app.settings.automation.lastUpdateMillis)
    }

    @Test
    fun damagedFileStartsFresh() {
        val store = TaskWallStore(InMemoryTextFileStore("{not json"))
        assertEquals(AppState(), store.state)
    }

    @Test
    fun reorderSetsSortOrder() {
        val store = TaskWallStore(InMemoryTextFileStore())
        val a = store.addQuickTask("A", 1)
        val b = store.addQuickTask("B", 2)
        val c = store.addQuickTask("C", 3)
        store.reorder(listOf(c.id, a.id))
        assertEquals(listOf(c.id, a.id, b.id), store.tasks.map { it.id })
        assertEquals(listOf(0, 1, 2), store.tasks.map { it.sortOrder })
    }

    @Test
    fun resolvesPhotoAppearanceFromAnalysis() {
        val store = TaskWallStore(InMemoryTextFileStore())
        val analysis = LegibilityResult(TextTone.DARK, Backdrop.SHADE, 2.0, 4.0, 0.4)
        store.setWallpaperStyle(
            WallpaperStyle(source = BackgroundSource.PHOTO, photoFileName = "p.jpg", photoAnalysis = analysis),
        )
        val auto = store.resolvedAppearance()
        assertEquals(TextTone.DARK, auto.tone)
        assertEquals(Backdrop.SHADE, auto.backdrop)

        store.setWallpaperStyle(store.settings.wallpaper.copy(backdrop = BackdropSetting.GLASS, textTone = ToneSetting.LIGHT))
        val manual = store.resolvedAppearance()
        assertEquals(TextTone.LIGHT, manual.tone)
        assertEquals(Backdrop.GLASS, manual.backdrop)
    }

    @Test
    fun formatsDueLabels() {
        assertEquals("Overdue, 18 Oct", Formatting.dueLabel(task("a", due = CalendarDay(2026, 10, 18)), TODAY))
        assertEquals("Today, 09:30", Formatting.dueLabel(task("b", minutes = 9 * 60 + 30), TODAY))
        assertEquals("Tomorrow", Formatting.dueLabel(task("c", due = TODAY.plusDays(1)), TODAY))
        assertEquals("Thursday", Formatting.dueLabel(task("d", due = TODAY.plusDays(2)), TODAY))
        assertEquals("3 Nov", Formatting.dueLabel(task("e", due = CalendarDay(2026, 11, 3)), TODAY))
    }
}
