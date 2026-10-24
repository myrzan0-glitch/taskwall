package app.taskwall.shared

/** The example list used in onboarding previews and the theme gallery. */
object SampleData {
    fun tasks(today: CalendarDay): List<TaskItem> = listOf(
        TaskItem("s1", "Submit lab report", priority = Priority.HIGH, dueDay = today, dueMinutes = 17 * 60),
        TaskItem("s2", "Reply to Sara about Friday", priority = Priority.MEDIUM, dueDay = today, sortOrder = 1),
        TaskItem("s3", "Renew gym membership", priority = Priority.LOW, dueDay = today.plusDays(-2), sortOrder = 2),
        TaskItem(
            "s4", "Prepare slides for standup", priority = Priority.HIGH, dueDay = today, dueMinutes = 9 * 60 + 30,
            isDone = true, completedOn = today, completedAtMillis = 1, sortOrder = 3,
        ),
        TaskItem(
            "s5", "Buy groceries", priority = Priority.MEDIUM, dueDay = today,
            isDone = true, completedOn = today, completedAtMillis = 2, sortOrder = 4,
        ),
    )

    fun wallpaperContent(today: CalendarDay, style: WallpaperStyle = WallpaperStyle()): WallpaperContent =
        WallpaperComposer.compose(tasks(today), today, WallpaperGeometry.maxLines(style.layout, style.showProgress))

    /** Ideas offered on the first-tasks onboarding screen. */
    val suggestions: List<String> = listOf("Reply to emails", "Workout", "Call mum", "Buy groceries", "Pay rent", "Water plants")

    /**
     * Ideas for what the person said they want to keep in view, taking one from each
     * pick in turn so every pick shows up early. With nothing picked, the general ones.
     */
    fun ideas(focus: Set<FocusArea>): List<String> {
        val lists = FocusArea.entries.filter { it in focus }.map { it.ideas }
        if (lists.isEmpty()) return suggestions
        return (0 until lists.maxOf { it.size }).flatMap { i -> lists.mapNotNull { it.getOrNull(i) } }.distinct()
    }
}

/** What someone wants their Lock Screen to keep in front of them; asked in onboarding. */
enum class FocusArea(val displayName: String, val ideas: List<String>) {
    WORK("Work & study", listOf("Reply to emails", "Prepare slides", "Read 20 pages", "Plan tomorrow")),
    HOME("Home & errands", listOf("Buy groceries", "Pay rent", "Call mum", "Water plants")),
    HEALTH("Health & habits", listOf("Workout", "Go for a walk", "Drink more water", "Sleep by 11")),
    GOALS("Big goals", listOf("Write 500 words", "Practise guitar", "Learn 10 new words", "Save for a trip")),
}
