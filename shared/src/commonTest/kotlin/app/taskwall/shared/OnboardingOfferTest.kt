package app.taskwall.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class OnboardingOfferTest {

    @Test
    fun withNothingPickedTheGeneralIdeasShow() {
        assertEquals(SampleData.suggestions, SampleData.ideas(emptySet()))
    }

    @Test
    fun everyPickShowsUpAmongTheFirstIdeas() {
        val ideas = SampleData.ideas(setOf(FocusArea.HEALTH, FocusArea.HOME))
        assertEquals(listOf("Buy groceries", "Workout", "Pay rent", "Go for a walk"), ideas.take(4))
        assertEquals(8, ideas.size)
    }

    @Test
    fun anIdeaIsOfferedOnce() {
        val ideas = SampleData.ideas(FocusArea.entries.toSet())
        assertEquals(ideas.distinct(), ideas)
    }

    @Test
    fun theOfferListsBestValueFirstAndLifetimeIsNoSubscription() {
        assertEquals(listOf(ProPlan.YEARLY, ProPlan.LIFETIME, ProPlan.MONTHLY), ProPlan.offered)
        assertEquals(ProPlan.entries.toSet(), ProPlan.offered.toSet())
        assertFalse(ProPlan.LIFETIME.isSubscription)
        assertTrue(ProPlan.YEARLY.isSubscription && ProPlan.MONTHLY.isSubscription)
        assertEquals(ProPlan.LIFETIME, ProPlan.forProductId("app.taskwall.pro.lifetime"))
    }
}
