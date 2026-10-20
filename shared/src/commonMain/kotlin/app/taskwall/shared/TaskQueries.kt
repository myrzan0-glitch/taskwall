package app.taskwall.shared

enum class TaskFilter { ALL, TODAY, UPCOMING }

enum class SectionKind { OVERDUE, TODAY, ANYTIME, UPCOMING }

data class TaskSection(val kind: SectionKind, val tasks: List<TaskItem>)

data class TaskProgress(val done: Int, val total: Int) {
    val fraction: Double get() = if (total == 0) 0.0 else done.toDouble() / total
}

object TaskQueries {

    /** Which list a task belongs to on [today]. */
    fun kindOf(task: TaskItem, today: CalendarDay): SectionKind {
        val due = task.dueDay ?: return SectionKind.ANYTIME
        return when {
            due > today -> SectionKind.UPCOMING
            due == today -> SectionKind.TODAY
            // Overdue tasks that were finished count as part of today's work.
            task.isDone -> SectionKind.TODAY
            else -> SectionKind.OVERDUE
        }
    }

    fun sections(tasks: List<TaskItem>, today: CalendarDay, filter: TaskFilter): List<TaskSection> {
        val kinds = when (filter) {
            TaskFilter.ALL -> listOf(SectionKind.OVERDUE, SectionKind.TODAY, SectionKind.ANYTIME, SectionKind.UPCOMING)
            TaskFilter.TODAY -> listOf(SectionKind.OVERDUE, SectionKind.TODAY, SectionKind.ANYTIME)
            TaskFilter.UPCOMING -> listOf(SectionKind.UPCOMING)
        }
        val grouped = tasks.groupBy { kindOf(it, today) }
        return kinds.mapNotNull { kind ->
            grouped[kind]?.takeIf { it.isNotEmpty() }?.let { TaskSection(kind, sorted(it, today)) }
        }
    }

    /** Progress across everything that belongs to today (overdue, today, anytime). */
    fun todayProgress(tasks: List<TaskItem>, today: CalendarDay): TaskProgress {
        val todays = tasks.filter { kindOf(it, today) != SectionKind.UPCOMING }
        return TaskProgress(done = todays.count { it.isDone }, total = todays.size)
    }

    /**
     * Open tasks first: higher priority, then overdue, then earlier due time,
     * then manual order. Finished tasks follow in the order they were done.
     */
    fun sorted(tasks: List<TaskItem>, today: CalendarDay): List<TaskItem> {
        val open = tasks.filter { !it.isDone }.sortedWith(
            compareByDescending<TaskItem> { it.priority.rank }
                .thenByDescending { kindOf(it, today) == SectionKind.OVERDUE }
                .thenBy { it.dueDay?.epochDay ?: Long.MAX_VALUE }
                .thenBy { it.dueMinutes ?: Int.MAX_VALUE }
                .thenBy { it.sortOrder }
        )
        val done = tasks.filter { it.isDone }.sortedBy { it.completedAtMillis ?: 0L }
        return open + done
    }
}
