package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class DailyQuotesTest {
    private val day = CalendarDay(2026, 10, 23)

    @Test
    fun theQuoteStaysTheSameAllDay() {
        assertEquals(DailyQuotes.quoteFor(day), DailyQuotes.quoteFor(CalendarDay(2026, 10, 23)))
    }

    @Test
    fun tomorrowBringsAnotherQuote() {
        assertNotEquals(DailyQuotes.quoteFor(day), DailyQuotes.quoteFor(day.plusDays(1)))
    }

    @Test
    fun everyQuoteComesRoundBeforeAnyRepeats() {
        val run = (0 until DailyQuotes.all.size).map { DailyQuotes.quoteFor(day.plusDays(it)) }
        assertEquals(DailyQuotes.all.toSet(), run.toSet())
        assertEquals(DailyQuotes.quoteFor(day), DailyQuotes.quoteFor(day.plusDays(DailyQuotes.all.size)))
    }

    @Test
    fun daysBefore1970StillHaveAQuote() {
        assertTrue(DailyQuotes.quoteFor(CalendarDay(1969, 12, 31)) in DailyQuotes.all)
    }

    @Test
    fun quotesAreShortAndDistinct() {
        assertEquals(DailyQuotes.all.size, DailyQuotes.all.map { it.text }.toSet().size, "no quote twice")
        for (quote in DailyQuotes.all) {
            assertTrue(quote.text.isNotBlank() && quote.author.isNotBlank())
            // At most three lines of 15 pt text above the add button.
            assertTrue(quote.text.length <= 90, "too long for three lines: ${quote.text}")
        }
    }
}
