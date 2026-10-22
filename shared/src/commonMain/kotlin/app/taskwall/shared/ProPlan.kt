package app.taskwall.shared

/**
 * Wallist Pro: auto-renewable subscriptions in one App Store subscription group.
 * Pro unlocks the Matrix and Orbit wallpaper fonts; tasks stay free.
 */
enum class ProPlan(val productId: String, val displayName: String, val note: String) {
    YEARLY("app.taskwall.pro.yearly", "Yearly", "Billed once a year"),
    MONTHLY("app.taskwall.pro.monthly", "Monthly", "Billed every month");

    companion object {
        fun forProductId(id: String): ProPlan? = entries.firstOrNull { it.productId == id }
    }
}
