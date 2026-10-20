package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals

internal val TODAY = CalendarDay(2026, 10, 20)

internal fun task(
    id: String,
    due: CalendarDay? = TODAY,
    minutes: Int? = null,
    priority: Priority = Priority.NO_PRIORITY,
    done: Boolean = false,
    completedAt: Long? = null,
    order: Int = 0,
    onWallpaper: Boolean = true,
) = TaskItem(
    id = id,
    title = "Task $id",
    priority = priority,
    dueDay = due,
    dueMinutes = minutes,
    showOnWallpaper = onWallpaper,
    isDone = done,
    completedOn = if (done) TODAY else null,
    completedAtMillis = completedAt,
    sortOrder = order,
)

class TaskQueriesTest {

    @Test
    fun classifiesTasksByDueDay() {
        assertEquals(SectionKind.OVERDUE, TaskQueries.kindOf(task("a", due = TODAY.plusDays(-2)), TODAY))
        assertEquals(SectionKind.TODAY, TaskQueries.kindOf(task("b"), TODAY))
        assertEquals(SectionKind.UPCOMING, TaskQueries.kindOf(task("c", due = TODAY.plusDays(1)), TODAY))
        assertEquals(SectionKind.ANYTIME, TaskQueries.kindOf(task("d", due = null), TODAY))
        // Finishing an overdue task moves it into today's list.
        assertEquals(SectionKind.TODAY, TaskQueries.kindOf(task("e", due = TODAY.plusDays(-2), done = true), TODAY))
    }

    @Test
    fun filtersSections() {
        val tasks = listOf(
            task("late", due = TODAY.plusDays(-1)),
            task("now"),
            task("whenever", due = null),
            task("later", due = TODAY.plusDays(3)),
        )
        assertEquals(
            listOf(SectionKind.OVERDUE, SectionKind.TODAY, SectionKind.ANYTIME, SectionKind.UPCOMING),
            TaskQueries.sections(tasks, TODAY, TaskFilter.ALL).map { it.kind },
        )
        assertEquals(
            listOf(SectionKind.OVERDUE, SectionKind.TODAY, SectionKind.ANYTIME),
            TaskQueries.sections(tasks, TODAY, TaskFilter.TODAY).map { it.kind },
        )
        assertEquals(listOf("later"), TaskQueries.sections(tasks, TODAY, TaskFilter.UPCOMING).single().tasks.map { it.id })
    }

    @Test
    fun sortsOpenByPriorityThenTimeAndDoneLast() {
        val tasks = listOf(
            task("done-early", done = true, completedAt = 1),
            task("low-9am", minutes = 9 * 60, priority = Priority.LOW),
            task("high", priority = Priority.HIGH),
            task("low-8am", minutes = 8 * 60, priority = Priority.LOW),
            task("done-late", done = true, completedAt = 5),
        )
        assertEquals(
            listOf("high", "low-8am", "low-9am", "done-early", "done-late"),
            TaskQueries.sorted(tasks, TODAY).map { it.id },
        )
    }

    @Test
    fun countsTodayProgressWithoutUpcoming() {
        val tasks = listOf(
            task("a", done = true),
            task("b"),
            task("c", due = TODAY.plusDays(-1)),
            task("d", due = TODAY.plusDays(1), done = true),
        )
        assertEquals(TaskProgress(done = 1, total = 3), TaskQueries.todayProgress(tasks, TODAY))
    }
}
