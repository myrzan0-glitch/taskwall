package app.taskwall.shared

import kotlinx.serialization.Serializable

/** Named `TaskItem` (not `Task`) so it doesn't clash with Swift's concurrency `Task`. */
@Serializable
data class TaskItem(
    val id: String,
    val title: String,
    val notes: String = "",
    val priority: Priority = Priority.NO_PRIORITY,
    val dueDay: CalendarDay? = null,
    /** Minutes after midnight, or null for "any time that day". */
    val dueMinutes: Int? = null,
    val showOnWallpaper: Boolean = true,
    val isDone: Boolean = false,
    val completedOn: CalendarDay? = null,
    val completedAtMillis: Long? = null,
    val createdAtMillis: Long = 0,
    val sortOrder: Int = 0,
) {
    init {
        require(dueMinutes == null || dueMinutes in 0 until 24 * 60) { "dueMinutes out of range: $dueMinutes" }
    }

    /** Swift-friendly copy for the edit screen. */
    fun edited(
        title: String,
        notes: String,
        priority: Priority,
        dueDay: CalendarDay?,
        dueMinutes: Int?,
        showOnWallpaper: Boolean,
    ) = copy(
        title = title.trim(),
        notes = notes.trim(),
        priority = priority,
        dueDay = dueDay,
        dueMinutes = if (dueDay == null) null else dueMinutes,
        showOnWallpaper = showOnWallpaper,
    )
}

enum class Priority(val rank: Int) {
    NO_PRIORITY(0),
    LOW(1),
    MEDIUM(2),
    HIGH(3),
}
