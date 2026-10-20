package app.taskwall.shared

/** A rectangle in fractions of the screen (0-1), origin top-left. */
data class NormalizedRect(val x: Double, val y: Double, val width: Double, val height: Double)

/**
 * Where things sit on the Lock Screen, as fractions of the screen so they work
 * on every phone size. Measured from the 390 x 844 pt design.
 */
object WallpaperGeometry {
    /** iOS draws the date and clock above this line. */
    const val CLOCK_AREA_BOTTOM = 252.0 / 844.0
    /** Tasks start here when placed below the clock. */
    const val TASKS_TOP = 262.0 / 844.0
    /** iOS draws the flashlight and camera buttons below this line. */
    const val CONTROLS_AREA_TOP = 1.0 - 116.0 / 844.0
    const val SIDE_INSET = 24.0 / 390.0

    /** The part of the photo the task list covers, used to measure readability. */
    fun analysisRegion(position: TaskPosition): NormalizedRect = when (position) {
        TaskPosition.BELOW_CLOCK -> NormalizedRect(26.0 / 390.0, TASKS_TOP, 338.0 / 390.0, 360.0 / 844.0)
        TaskPosition.BOTTOM -> NormalizedRect(26.0 / 390.0, 0.47, 338.0 / 390.0, CONTROLS_AREA_TOP - 0.47)
    }

    /** How many tasks fit before the list would run into iOS's own controls. */
    fun maxLines(layout: WallpaperLayout, showProgress: Boolean): Int {
        val base = if (layout == WallpaperLayout.TABLE) 7 else 6
        return if (showProgress) base else base + 1
    }
}
