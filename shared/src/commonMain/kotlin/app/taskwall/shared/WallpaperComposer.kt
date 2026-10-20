package app.taskwall.shared

data class WallpaperLine(
    val id: String,
    val title: String,
    /** "17:00", "Overdue, 18 Oct", or null when there's nothing to add. */
    val detail: String?,
    val isDone: Boolean,
    val isHighPriority: Boolean,
    val isOverdue: Boolean,
)

data class WallpaperContent(
    val heading: String,
    val doneCount: Int,
    val totalCount: Int,
    val lines: List<WallpaperLine>,
    /** Open tasks that didn't fit; shown as "+3 more". */
    val hiddenCount: Int,
) {
    val progress: Double get() = if (totalCount == 0) 0.0 else doneCount.toDouble() / totalCount
    val progressLabel: String get() = "$doneCount of $totalCount done"
}

/** Picks and orders what today's wallpaper shows. */
object WallpaperComposer {

    fun compose(tasks: List<TaskItem>, today: CalendarDay, maxLines: Int): WallpaperContent {
        val todays = tasks.filter { it.showOnWallpaper && TaskQueries.kindOf(it, today) != SectionKind.UPCOMING }
        val ordered = TaskQueries.sorted(todays, today)
        val open = ordered.filter { !it.isDone }
        val done = ordered.filter { it.isDone }

        // Open tasks always win the space; finished ones fill what's left.
        val shownOpen = open.take(maxLines)
        val shownDone = done.take((maxLines - shownOpen.size).coerceAtLeast(0))

        return WallpaperContent(
            heading = "Today",
            doneCount = done.size,
            totalCount = todays.size,
            lines = (shownOpen + shownDone).map { line(it, today) },
            hiddenCount = open.size - shownOpen.size,
        )
    }

    private fun line(task: TaskItem, today: CalendarDay): WallpaperLine {
        val overdue = TaskQueries.kindOf(task, today) == SectionKind.OVERDUE
        val detail = when {
            overdue -> "Overdue, " + Formatting.shortDate(task.dueDay!!)
            task.dueMinutes != null -> Formatting.time(task.dueMinutes)
            else -> null
        }
        return WallpaperLine(
            id = task.id,
            title = task.title,
            detail = detail,
            isDone = task.isDone,
            isHighPriority = task.priority == Priority.HIGH,
            isOverdue = overdue,
        )
    }
}
