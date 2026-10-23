package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ShortcutConfirmTest {
    private val today = CalendarDay(2026, 10, 23)
    private fun newStore(file: TextFileStore = InMemoryTextFileStore()) = TaskWallStore(file)

    @Test
    fun anOlderShortcutStillCountsWhenItMakesTheWallpaper() {
        val store = newStore()
        store.addQuickTask("Buy milk", 1)
        store.recordWallpaperUpdate(nowMillis = 10, today = today)
        assertTrue(store.isWallpaperCurrent(today))
        assertFalse(store.settings.automation.shortcutConfirms)
    }

    @Test
    fun aConfirmingShortcutCountsOnlyOnceTheWallpaperIsSet() {
        val store = newStore()
        val task = store.addQuickTask("Buy milk", 1)
        store.recordWallpaperUpdate(nowMillis = 10, today = today)
        store.confirmWallpaperSet(nowMillis = 11)
        assertTrue(store.settings.automation.shortcutConfirms)
        assertTrue(store.isWallpaperCurrent(today))

        store.toggleDone(task.id, today, 20)
        store.recordWallpaperUpdate(nowMillis = 30, today = today)
        assertFalse(store.isWallpaperCurrent(today), "handed over, but iOS hasn't set it yet")
        assertEquals(11L, store.settings.automation.lastUpdateMillis)

        store.confirmWallpaperSet(nowMillis = 31)
        assertTrue(store.isWallpaperCurrent(today))
        assertEquals(31L, store.settings.automation.lastUpdateMillis)
        assertNull(store.settings.automation.pendingWallpaperSignature)
    }

    @Test
    fun aRunThatStopsBeforeConfirmingLeavesTheLockScreenOutOfDate() {
        val store = newStore()
        val task = store.addQuickTask("Buy milk", 1)
        store.recordWallpaperUpdate(nowMillis = 10, today = today)
        store.confirmWallpaperSet(nowMillis = 11)

        store.toggleDone(task.id, today, 20)
        store.recordWallpaperUpdate(nowMillis = 30, today = today) // Set Wallpaper then fails
        assertFalse(store.isWallpaperCurrent(today))
    }

    @Test
    fun confirmingIsSavedForTheNextLaunch() {
        val file = InMemoryTextFileStore()
        val store = newStore(file)
        store.recordWallpaperUpdate(nowMillis = 10, today = today)
        store.confirmWallpaperSet(nowMillis = 11)
        assertTrue(newStore(file).settings.automation.shortcutConfirms)
    }

    @Test
    fun theShortcutSetsBothScreensForNow() {
        assertEquals("both", newStore().shortcutMode.value)
        assertEquals(listOf("both", "lock"), ShortcutMode.entries.map { it.value })
    }
}
