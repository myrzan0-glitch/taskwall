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
    fun splitsIntoTodayUpcomingAndPastGroupedByDate() {
        val tasks = listOf(
            task("late", due = TODAY.plusDays(-1)),
            task("older", due = TODAY.plusDays(-3)),
            task("older-done", due = TODAY.plusDays(-3), done = true),
            task("now"),
            task("whenever", due = null),
            task("soon", due = TODAY.plusDays(1)),
            task("later", due = TODAY.plusDays(3)),
            task("later-too", due = TODAY.plusDays(3)),
        )
        val today = TaskQueries.sections(tasks, TODAY, TaskFilter.TODAY)
        assertEquals(listOf("Today", "Anytime"), today.map { it.title })
        assertEquals(listOf(listOf("now"), listOf("whenever")), today.map { s -> s.tasks.map { it.id } })
        assertEquals(listOf(null, null), today.map { it.day })

        // Soonest date first.
        val upcoming = TaskQueries.sections(tasks, TODAY, TaskFilter.UPCOMING)
        assertEquals(listOf("Tomorrow", "Friday, 23 Oct"), upcoming.map { it.title })
        assertEquals(listOf(TODAY.plusDays(1), TODAY.plusDays(3)), upcoming.map { it.day })
        assertEquals(listOf("later", "later-too"), upcoming[1].tasks.map { it.id })

        // Most recent date first; finished and unfinished tasks both stay under their date.
        val past = TaskQueries.sections(tasks, TODAY, TaskFilter.PAST)
        assertEquals(listOf("Yesterday", "Saturday, 17 Oct"), past.map { it.title })
        assertEquals(listOf("older", "older-done"), past[1].tasks.map { it.id })
    }

    @Test
    fun emptyGroupsAreLeftOut() {
        val tasks = listOf(task("whenever", due = null))
        assertEquals(listOf("Anytime"), TaskQueries.sections(tasks, TODAY, TaskFilter.TODAY).map { it.title })
        assertEquals(emptyList(), TaskQueries.sections(tasks, TODAY, TaskFilter.UPCOMING))
        assertEquals(emptyList(), TaskQueries.sections(tasks, TODAY, TaskFilter.PAST))
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

    @Test
    fun weekRunsMondayToSunday() {
        // 20 Oct 2026 is a Tuesday.
        val week = TaskQueries.week(TODAY)
        assertEquals(CalendarDay(2026, 10, 19), week.first())
        assertEquals(CalendarDay(2026, 10, 25), week.last())
        assertEquals(7, week.size)
        assertEquals((1..7).toList(), week.map { it.dayOfWeek })
        // A Sunday belongs to the week that ends on it, and weeks cross month ends.
        assertEquals(CalendarDay(2026, 10, 19), TaskQueries.week(CalendarDay(2026, 10, 25)).first())
        assertEquals(CalendarDay(2026, 11, 1), TaskQueries.week(CalendarDay(2026, 10, 28)).last())
    }

    @Test
    fun todayListsOverdueUndatedAndToday() {
        val tasks = listOf(
            task("late", due = TODAY.plusDays(-2)),
            task("late-done", due = TODAY.plusDays(-2), done = true, completedAt = 5),
            task("now", priority = Priority.HIGH),
            task("whenever", due = null),
            task("soon", due = TODAY.plusDays(1)),
        )
        assertEquals(listOf("now", "late", "whenever", "late-done"), TaskQueries.forDay(tasks, TODAY, TODAY).map { it.id })
        assertEquals(listOf("soon"), TaskQueries.forDay(tasks, TODAY.plusDays(1), TODAY).map { it.id })
        // Another day lists only what is due then; the open overdue task also stays on today.
        assertEquals(listOf("late", "late-done"), TaskQueries.forDay(tasks, TODAY.plusDays(-2), TODAY).map { it.id })
        assertEquals(emptyList(), TaskQueries.forDay(tasks, TODAY.plusDays(3), TODAY))
    }

    @Test
    fun dotMarksDaysWithOpenTasks() {
        val tasks = listOf(
            task("soon", due = TODAY.plusDays(1)),
            task("done-later", due = TODAY.plusDays(2), done = true),
        )
        assertEquals(false, TaskQueries.hasOpenTasks(tasks, TODAY, TODAY))
        assertEquals(true, TaskQueries.hasOpenTasks(tasks, TODAY.plusDays(1), TODAY))
        assertEquals(false, TaskQueries.hasOpenTasks(tasks, TODAY.plusDays(2), TODAY))
    }
}
