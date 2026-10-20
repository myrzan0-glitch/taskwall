package app.taskwall.shared

/**
 * One-time tips. They are consumable in-app purchases that unlock nothing;
 * App Review requires tips to go through in-app purchase (guideline 3.1.1).
 */
enum class Tip(val productId: String, val displayName: String, val isPopular: Boolean) {
    ESPRESSO("app.taskwall.tip.espresso", "Espresso", false),
    FLAT_WHITE("app.taskwall.tip.flatwhite", "Flat White", true),
    COFFEE_AND_CAKE("app.taskwall.tip.coffeecake", "Coffee & Cake", false);

    companion object {
        fun forProductId(id: String): Tip? = entries.firstOrNull { it.productId == id }
    }
}
