package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class ReadsTest {
    @Test
    fun everyReadIsComplete() {
        assertEquals(3, Reads.all.size)
        assertEquals(Reads.all.size, Reads.all.map { it.id }.toSet().size, "ids are unique")
        for (read in Reads.all) {
            assertTrue(read.title.isNotBlank() && read.author.isNotBlank() && read.quote.isNotBlank(), read.id)
            assertTrue(read.opening.isNotEmpty() && read.closing.isNotEmpty(), read.id)
            assertTrue(read.minutes in 1..10, read.id)
            assertNotNull(Reads.byId(read.id))
        }
    }

    @Test
    fun sharingSendsTheTitleQuoteAndAuthor() {
        val read = Reads.all.first()
        assertTrue(read.shareText.startsWith(read.title))
        assertTrue(read.quote in read.shareText && read.shareText.endsWith(read.author))
    }
}
