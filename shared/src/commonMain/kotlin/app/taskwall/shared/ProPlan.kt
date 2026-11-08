package app.taskwall.shared

/**
 * Wallist Pro: a monthly auto-renewable subscription ($1.99) or a one-time
 * Lifetime purchase ($9.99). Pro unlocks the Matrix, Orbit and Grace wallpaper
 * fonts; tasks stay free. There's no free trial: every Pro font can be tried in the
 * preview first.
 */
enum class ProPlan(val productId: String, val displayName: String, val note: String, val isSubscription: Boolean) {
    MONTHLY("app.taskwall.pro.sub.monthly", "Monthly", "Billed every month", true),
    LIFETIME("app.taskwall.pro.lifetime", "Lifetime", "Pay once, keep it forever", false);

    companion object {
        /** The order the paywall lists them in, best value first. */
        val offered: List<ProPlan> = listOf(LIFETIME, MONTHLY)

        fun forProductId(id: String): ProPlan? = entries.firstOrNull { it.productId == id }
    }
}
