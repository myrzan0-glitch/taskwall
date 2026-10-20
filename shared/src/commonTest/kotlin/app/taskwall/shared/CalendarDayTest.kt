package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class CalendarDayTest {

    @Test
    fun epochDayMatchesKnownDates() {
        assertEquals(0L, CalendarDay(1970, 1, 1).epochDay)
        assertEquals(10957L, CalendarDay(2000, 1, 1).epochDay)
        assertEquals(11017L, CalendarDay(2000, 3, 1).epochDay) // 2000 is a leap year
        assertEquals(CalendarDay(2026, 10, 20), CalendarDay.fromEpochDay(CalendarDay(2026, 10, 20).epochDay))
    }

    @Test
    fun roundTripsAcrossManyYears() {
        var day = CalendarDay(1899, 12, 25)
        repeat(60_000) {
            val next = day.plusDays(1)
            assertEquals(1, day.daysUntil(next))
            assertEquals(next, CalendarDay.fromEpochDay(next.epochDay))
            day = next
        }
    }

    @Test
    fun dayOfWeekIsIso() {
        assertEquals(4, CalendarDay(1970, 1, 1).dayOfWeek) // Thursday
        assertEquals(2, CalendarDay(2026, 10, 20).dayOfWeek) // Tuesday
        assertEquals(7, CalendarDay(2026, 10, 25).dayOfWeek) // Sunday
    }

    @Test
    fun handlesMonthAndLeapYearEdges() {
        assertEquals(CalendarDay(2024, 2, 29), CalendarDay(2024, 2, 28).plusDays(1))
        assertEquals(CalendarDay(2025, 3, 1), CalendarDay(2025, 2, 28).plusDays(1))
        assertEquals(CalendarDay(2027, 1, 1), CalendarDay(2026, 12, 31).plusDays(1))
        assertTrue(CalendarDay(2026, 10, 19) < CalendarDay(2026, 10, 20))
    }

    @Test
    fun rejectsImpossibleDates() {
        assertFailsWith<IllegalArgumentException> { CalendarDay(2025, 2, 29) }
        assertFailsWith<IllegalArgumentException> { CalendarDay(2026, 13, 1) }
    }
}
