package app.taskwall.shared

import kotlin.random.Random
import kotlinx.serialization.json.Json

/** Returned by [TaskWallStore.addListener]; call [close] to stop listening. */
class ListenerHandle internal constructor(private val onClose: () -> Unit) {
    fun close() = onClose()
}

/**
 * The single source of truth for tasks and settings.
 *
 * Every change is saved straight away, on top of what's in the file: the
 * shortcut and Siri save to the same file while the app keeps its own store
 * open, so a change never starts from this store's older copy. Methods that
 * depend on the date or the time take them as arguments, so the platform stays
 * in charge of clocks and time zones. Not thread-safe: call it from one thread
 * (the main thread on iOS).
 */
class TaskWallStore(private val file: TextFileStore) {

    companion object {
        /**
         * A shortcut run this close to TaskWall closing counts as the close automation.
         * Either can be recorded first: the shortcut can finish before the app hears it closed.
         */
        const val CLOSE_RUN_WINDOW_MILLIS = 2 * 60 * 1000L

        private fun isCloseRun(closedMillis: Long?, runMillis: Long?): Boolean =
            closedMillis != null && runMillis != null &&
                kotlin.math.abs(runMillis - closedMillis) <= CLOSE_RUN_WINDOW_MILLIS
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    private val listeners = mutableListOf<(AppState) -> Unit>()

    var state: AppState = load()
        private set

    val tasks: List<TaskItem> get() = state.tasks
    val settings: AppSettings get() = state.settings

    fun addListener(listener: (AppState) -> Unit): ListenerHandle {
        listeners += listener
        listener(state)
        return ListenerHandle { listeners -= listener }
    }

    /** Re-reads the file, e.g. after a shortcut changed it in the background. */
    fun reload() {
        val fresh = load()
        if (fresh != state) {
            state = fresh
            notifyListeners()
        }
    }

    // Tasks

    fun addTask(
        title: String,
        notes: String,
        priority: Priority,
        dueDay: CalendarDay?,
        dueMinutes: Int?,
        showOnWallpaper: Boolean,
        nowMillis: Long,
    ): TaskItem {
        val draft = TaskItem(
            id = newId(),
            title = title.trim(),
            notes = notes.trim(),
            priority = priority,
            dueDay = dueDay,
            dueMinutes = dueMinutes,
            showOnWallpaper = showOnWallpaper,
            createdAtMillis = nowMillis,
        )
        var task = draft
        update { s ->
            task = draft.copy(sortOrder = (s.tasks.maxOfOrNull { it.sortOrder } ?: -1) + 1)
            s.copy(tasks = s.tasks + task)
        }
        return task
    }

    /** Quick add with no date: shows on today's wallpaper. Used by onboarding and Siri. */
    fun addQuickTask(title: String, nowMillis: Long): TaskItem =
        addTask(title, "", Priority.NO_PRIORITY, null, null, true, nowMillis)

    fun updateTask(task: TaskItem) {
        update { s -> s.copy(tasks = s.tasks.map { if (it.id == task.id) task else it }) }
    }

    fun setDone(id: String, done: Boolean, today: CalendarDay, nowMillis: Long) {
        update { s ->
            s.copy(tasks = s.tasks.map {
                when {
                    it.id != id -> it
                    done -> it.copy(isDone = true, completedOn = today, completedAtMillis = nowMillis)
                    else -> it.copy(isDone = false, completedOn = null, completedAtMillis = null)
                }
            })
        }
    }

    fun toggleDone(id: String, today: CalendarDay, nowMillis: Long) {
        syncWithFile()
        val task = state.tasks.firstOrNull { it.id == id } ?: return
        setDone(id, !task.isDone, today, nowMillis)
    }

    fun deleteTask(id: String) {
        update { s -> s.copy(tasks = s.tasks.filterNot { it.id == id }) }
    }

    /** Applies a manual order; ids not listed keep their relative order after these. */
    fun reorder(orderedIds: List<String>) {
        val position = orderedIds.withIndex().associate { (i, id) -> id to i }
        update { s ->
            val reordered = s.tasks.sortedWith(compareBy({ position[it.id] ?: Int.MAX_VALUE }, { it.sortOrder }))
            s.copy(tasks = reordered.mapIndexed { i, t -> t.copy(sortOrder = i) })
        }
    }

    /**
     * Once a day, removes tasks finished before [today] if the person turned
     * that on. Returns how many were removed.
     */
    fun clearCompletedIfDue(today: CalendarDay): Int {
        var stale = 0
        update { s ->
            if (!s.settings.clearCompletedEachMorning || s.settings.lastClearedDay == today) return@update s
            val kept = s.tasks.filterNot { it.isDone && (it.completedOn ?: today) < today }
            stale = s.tasks.size - kept.size
            s.copy(tasks = kept, settings = s.settings.copy(lastClearedDay = today))
        }
        return stale
    }

    /** Removes every finished task. Returns how many were removed. */
    fun clearCompleted(): Int {
        var count = 0
        update { s ->
            count = s.tasks.count { it.isDone }
            s.copy(tasks = s.tasks.filterNot { it.isDone })
        }
        return count
    }

    // Settings

    fun updateSettings(transform: (AppSettings) -> AppSettings) {
        update { it.copy(settings = transform(it.settings)) }
    }

    fun setWallpaperStyle(style: WallpaperStyle) = updateSettings { it.copy(wallpaper = style) }

    fun setAutomation(automation: AutomationSettings) = updateSettings { it.copy(automation = automation) }

    fun completeOnboarding() = updateSettings { it.copy(onboardingComplete = true) }

    fun setClearCompletedEachMorning(on: Boolean) = updateSettings { it.withClearCompletedEachMorning(on) }

    fun setScreen(metrics: ScreenMetrics) = updateSettings { it.copy(screen = metrics) }

    /**
     * Called when TaskWall goes to the background, to recognise the close automation.
     * The automation's shortcut may already have run by the time this is heard.
     */
    fun recordAppClosed(nowMillis: Long) = updateSettings { s ->
        val afterRun = isCloseRun(closedMillis = nowMillis, runMillis = s.automation.lastUpdateMillis)
        s.copy(
            automation = s.automation.copy(
                lastAppClosedMillis = nowMillis,
                updatesWhenClosed = s.automation.updatesWhenClosed || afterRun,
            ),
        )
    }

    /**
     * Called by the shortcut each time it makes a wallpaper. Remembers what the
     * wallpaper shows, and notices when the run came right after TaskWall closed.
     */
    fun recordWallpaperUpdate(nowMillis: Long, today: CalendarDay) = update { s ->
        val automation = s.settings.automation
        val afterClose = isCloseRun(closedMillis = automation.lastAppClosedMillis, runMillis = nowMillis)
        s.copy(
            settings = s.settings.copy(
                automation = automation.copy(
                    lastUpdateMillis = nowMillis,
                    lastWallpaperSignature = signature(s, today),
                    updatesWhenClosed = automation.updatesWhenClosed || afterClose,
                ),
            ),
        )
    }

    /** Whether the Lock Screen already shows today's tasks in the current style. */
    fun isWallpaperCurrent(today: CalendarDay): Boolean =
        state.settings.automation.lastWallpaperSignature == wallpaperSignature(today)

    // Derived data for the screens

    fun sections(today: CalendarDay, filter: TaskFilter): List<TaskSection> =
        TaskQueries.sections(state.tasks, today, filter)

    fun todayProgress(today: CalendarDay): TaskProgress = TaskQueries.todayProgress(state.tasks, today)

    fun wallpaperContent(today: CalendarDay): WallpaperContent = wallpaperContent(state, today)

    /**
     * A stable fingerprint of what the wallpaper would show now. Built from text,
     * not hashCode(), so the app and the shortcut (separate processes) agree.
     */
    fun wallpaperSignature(today: CalendarDay): String = signature(state, today)

    private fun wallpaperContent(state: AppState, today: CalendarDay): WallpaperContent {
        val style = state.settings.wallpaper
        return WallpaperComposer.compose(state.tasks, today, WallpaperGeometry.maxLines(style.layout, style.showProgress))
    }

    private fun signature(state: AppState, today: CalendarDay): String {
        val text = wallpaperContent(state, today).toString() + "|" + state.settings.wallpaper.toString()
        var hash = 0xcbf29ce484222325uL
        for (byte in text.encodeToByteArray()) {
            hash = (hash xor byte.toUByte().toULong()) * 0x100000001b3uL
        }
        return hash.toString(16)
    }

    fun resolvedAppearance(): ResolvedAppearance = WallpaperAppearance.resolve(state.settings.wallpaper)

    fun search(query: String, today: CalendarDay): List<TaskItem> {
        val q = query.trim()
        if (q.isEmpty()) return emptyList()
        return TaskQueries.sorted(
            state.tasks.filter { it.title.contains(q, ignoreCase = true) || it.notes.contains(q, ignoreCase = true) },
            today,
        )
    }

    // Internals

    private fun update(transform: (AppState) -> AppState) {
        syncWithFile()
        val next = transform(state)
        if (next == state) return
        state = next
        file.write(json.encodeToString(AppState.serializer(), next))
        notifyListeners()
    }

    /**
     * Takes up what another store saved, so the next change builds on it. Keeps this
     * store's copy if the file can't be read, so a bad read never loses data.
     */
    private fun syncWithFile() {
        val saved = loadSaved() ?: return
        if (saved != state) {
            state = saved
            notifyListeners()
        }
    }

    private fun notifyListeners() {
        listeners.toList().forEach { it(state) }
    }

    // A damaged file shouldn't lock people out; start fresh rather than crash.
    private fun load(): AppState = loadSaved() ?: AppState()

    private fun loadSaved(): AppState? {
        val text = file.read() ?: return null
        return try {
            json.decodeFromString(AppState.serializer(), text)
        } catch (e: Exception) {
            null
        }
    }

    private fun newId(): String {
        val chars = "0123456789abcdef"
        return (1..20).map { chars[Random.nextInt(chars.length)] }.joinToString("")
    }
}
