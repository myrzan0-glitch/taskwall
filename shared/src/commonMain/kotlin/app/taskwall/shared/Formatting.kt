package app.taskwall.shared

/**
 * Default English formatting. The apps can format with the device locale
 * instead; these keep the wallpaper renderable from shared code alone.
 */
object Formatting {
    private val MONTHS = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    private val WEEKDAYS = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")

    /** 24-hour time, e.g. 17:00. */
    fun time(minutesAfterMidnight: Int): String {
        val h = minutesAfterMidnight / 60
        val m = minutesAfterMidnight % 60
        return h.toString().padStart(2, '0') + ":" + m.toString().padStart(2, '0')
    }

    /** e.g. "18 Oct". */
    fun shortDate(day: CalendarDay): String = "${day.day} ${MONTHS[day.month - 1]}"

    /** "Today", "Tomorrow", a weekday within the next week, otherwise "18 Oct". */
    fun relativeDay(day: CalendarDay, today: CalendarDay): String = when (val diff = today.daysUntil(day)) {
        0 -> "Today"
        1 -> "Tomorrow"
        -1 -> "Yesterday"
        in 2..6 -> WEEKDAYS[day.dayOfWeek - 1]
        else -> shortDate(day)
    }

    /** The line under a task title in the app, e.g. "Overdue, 18 Oct" or "Tomorrow, 09:30". */
    fun dueLabel(task: TaskItem, today: CalendarDay): String? {
        val day = task.dueDay ?: return task.dueMinutes?.let { time(it) }
        if (TaskQueries.kindOf(task, today) == SectionKind.OVERDUE) return "Overdue, " + shortDate(day)
        val dayPart = relativeDay(day, today)
        return task.dueMinutes?.let { "$dayPart, ${time(it)}" } ?: dayPart
    }
}
