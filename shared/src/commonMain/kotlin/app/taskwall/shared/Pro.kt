package app.taskwall.shared

/**
 * Wallist Pro, bought through the App Store. Monthly is an auto-renewable
 * subscription; Lifetime is a one-time (non-consumable) purchase. Both unlock
 * the same things, listed in [WallpaperStyle.usesPro]: any photo, the Pro
 * themes, the table layout and the progress bar. Tasks, the list layout,
 * the free themes and automatic updates stay free.
 */
enum class ProPlan(val productId: String, val displayName: String) {
    MONTHLY("app.taskwall.pro.monthly", "Monthly"),
    LIFETIME("app.taskwall.pro.lifetime", "Lifetime");

    companion object {
        fun forProductId(id: String): ProPlan? = entries.firstOrNull { it.productId == id }

        /** Lifetime wins when an account owns both, e.g. after switching from Monthly. */
        fun best(plans: List<ProPlan>): ProPlan? =
            if (LIFETIME in plans) LIFETIME else plans.firstOrNull()
    }
}
