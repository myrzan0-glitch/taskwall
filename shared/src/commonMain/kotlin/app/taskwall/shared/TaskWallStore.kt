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
 * Every change is saved straight away. Methods that depend on the date or the
 * time take them as arguments, so the platform stays in charge of clocks and
 * time zones. Not thread-safe: call it from one thread (the main thread on iOS).
 */
class TaskWallStore(private val file: TextFileStore) {

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
        val task = TaskItem(
            id = newId(),
            title = title.trim(),
            notes = notes.trim(),
            priority = priority,
            dueDay = dueDay,
            dueMinutes = dueMinutes,
            showOnWallpaper = showOnWallpaper,
            createdAtMillis = nowMillis,
            sortOrder = (state.tasks.maxOfOrNull { it.sortOrder } ?: -1) + 1,
        )
        update { it.copy(tasks = it.tasks + task) }
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
        val settings = state.settings
        if (!settings.clearCompletedEachMorning || settings.lastClearedDay == today) return 0
        val stale = state.tasks.count { it.isDone && (it.completedOn ?: today) < today }
        update { s ->
            s.copy(
                tasks = s.tasks.filterNot { it.isDone && (it.completedOn ?: today) < today },
                settings = s.settings.copy(lastClearedDay = today),
            )
        }
        return stale
    }

    /** Removes every finished task. Returns how many were removed. */
    fun clearCompleted(): Int {
        val count = state.tasks.count { it.isDone }
        update { s -> s.copy(tasks = s.tasks.filterNot { it.isDone }) }
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

    fun setScreen(metrics: ScreenMetrics) {
        if (state.settings.screen != metrics) updateSettings { it.copy(screen = metrics) }
    }

    /** Called by the shortcut each time it makes a wallpaper. */
    fun recordWallpaperUpdate(nowMillis: Long) =
        updateSettings { it.copy(automation = it.automation.copy(lastUpdateMillis = nowMillis)) }

    // Derived data for the screens

    fun sections(today: CalendarDay, filter: TaskFilter): List<TaskSection> =
        TaskQueries.sections(state.tasks, today, filter)

    fun todayProgress(today: CalendarDay): TaskProgress = TaskQueries.todayProgress(state.tasks, today)

    fun wallpaperContent(today: CalendarDay): WallpaperContent {
        val style = state.settings.wallpaper
        return WallpaperComposer.compose(state.tasks, today, WallpaperGeometry.maxLines(style.layout, style.showProgress))
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
        val next = transform(state)
        if (next == state) return
        state = next
        file.write(json.encodeToString(AppState.serializer(), next))
        notifyListeners()
    }

    private fun notifyListeners() {
        listeners.toList().forEach { it(state) }
    }

    private fun load(): AppState {
        val text = file.read() ?: return AppState()
        return try {
            json.decodeFromString(AppState.serializer(), text)
        } catch (e: Exception) {
            // A damaged file shouldn't lock people out; start fresh rather than crash.
            AppState()
        }
    }

    private fun newId(): String {
        val chars = "0123456789abcdef"
        return (1..20).map { chars[Random.nextInt(chars.length)] }.joinToString("")
    }
}
