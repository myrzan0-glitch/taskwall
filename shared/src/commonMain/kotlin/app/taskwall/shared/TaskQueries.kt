package app.taskwall.shared

enum class TaskFilter { TODAY, UPCOMING, PAST }

enum class SectionKind { OVERDUE, TODAY, ANYTIME, UPCOMING }

/**
 * A titled group in the task list. [day] is set when the group is a single
 * date (Upcoming and Past), so rows can leave the date out.
 */
data class TaskSection(val title: String, val tasks: List<TaskItem>, val day: CalendarDay? = null)

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

    /**
     * Today: due today, then undated. Upcoming: one group per date, soonest
     * first. Past: one group per date before today, most recent first.
     */
    fun sections(tasks: List<TaskItem>, today: CalendarDay, filter: TaskFilter): List<TaskSection> = when (filter) {
        TaskFilter.TODAY -> listOfNotNull(
            section("Today", tasks.filter { it.dueDay == today }, today),
            section("Anytime", tasks.filter { it.dueDay == null }, today),
        )
        TaskFilter.UPCOMING -> byDay(tasks.filter { it.dueDay?.let { day -> day > today } == true }, today)
        TaskFilter.PAST -> byDay(tasks.filter { it.dueDay?.let { day -> day < today } == true }, today).reversed()
    }

    private fun section(title: String, tasks: List<TaskItem>, today: CalendarDay): TaskSection? =
        tasks.takeIf { it.isNotEmpty() }?.let { TaskSection(title, sorted(it, today)) }

    private fun byDay(tasks: List<TaskItem>, today: CalendarDay): List<TaskSection> =
        tasks.groupBy { it.dueDay!! }.entries.sortedBy { it.key }.map { (day, dayTasks) ->
            TaskSection(Formatting.dayHeading(day, today), sorted(dayTasks, today), day)
        }

    /** Monday to Sunday of the week that contains [day], for the week strip. */
    fun week(day: CalendarDay): List<CalendarDay> {
        val monday = day.plusDays(1 - day.dayOfWeek)
        return (0 until 7).map { monday.plusDays(it) }
    }

    /**
     * The list for one day of the week strip. Today also carries what is still
     * open from earlier days and the tasks without a date, the same set the
     * wallpaper and its progress count use. Any other day lists what is due then.
     */
    fun forDay(tasks: List<TaskItem>, day: CalendarDay, today: CalendarDay): List<TaskItem> {
        val list = if (day == today) {
            tasks.filter { kindOf(it, today) != SectionKind.UPCOMING }
        } else {
            tasks.filter { it.dueDay == day }
        }
        return sorted(list, today)
    }

    /** Whether [day] still has something open: the dot over a day in the week strip. */
    fun hasOpenTasks(tasks: List<TaskItem>, day: CalendarDay, today: CalendarDay): Boolean =
        forDay(tasks, day, today).any { !it.isDone }

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
