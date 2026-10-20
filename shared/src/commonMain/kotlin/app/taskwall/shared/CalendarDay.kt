package app.taskwall.shared

import kotlinx.serialization.Serializable

/**
 * A date without a time zone, as the person sees it on their phone.
 *
 * The platform decides what "today" is and passes it in, so the shared code
 * never reads a clock or a time zone itself.
 */
@Serializable
data class CalendarDay(val year: Int, val month: Int, val day: Int) : Comparable<CalendarDay> {

    init {
        require(month in 1..12) { "month must be 1-12, was $month" }
        require(day in 1..daysInMonth(year, month)) { "day $day is not in $year-$month" }
    }

    /** Days since 1970-01-01. */
    val epochDay: Long get() = toEpochDay(year, month, day)

    /** ISO day of week: 1 = Monday … 7 = Sunday. */
    val dayOfWeek: Int get() = (((epochDay + 3) % 7 + 7) % 7 + 1).toInt()

    fun plusDays(days: Int): CalendarDay = fromEpochDay(epochDay + days)

    fun daysUntil(other: CalendarDay): Int = (other.epochDay - epochDay).toInt()

    override fun compareTo(other: CalendarDay): Int = epochDay.compareTo(other.epochDay)

    override fun toString(): String =
        "$year-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}"

    companion object {
        fun isLeapYear(year: Int): Boolean = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0

        fun daysInMonth(year: Int, month: Int): Int = when (month) {
            2 -> if (isLeapYear(year)) 29 else 28
            4, 6, 9, 11 -> 30
            else -> 31
        }

        // Howard Hinnant's days_from_civil / civil_from_days.
        private fun toEpochDay(year: Int, month: Int, day: Int): Long {
            val y = (if (month <= 2) year - 1 else year).toLong()
            val era = (if (y >= 0) y else y - 399) / 400
            val yearOfEra = y - era * 400
            val shiftedMonth = (month + 9) % 12
            val dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
            val dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
            return era * 146097 + dayOfEra - 719468
        }

        fun fromEpochDay(epochDay: Long): CalendarDay {
            val z = epochDay + 719468
            val era = (if (z >= 0) z else z - 146096) / 146097
            val dayOfEra = z - era * 146097
            val yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146096) / 365
            val dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
            val shiftedMonth = (5 * dayOfYear + 2) / 153
            val day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
            val month = if (shiftedMonth < 10) shiftedMonth + 3 else shiftedMonth - 9
            val year = yearOfEra + era * 400 + if (month <= 2) 1 else 0
            return CalendarDay(year.toInt(), month.toInt(), day.toInt())
        }
    }
}
