package app.taskwall.shared

import kotlinx.serialization.Serializable

/** Everything TaskWall saves. One JSON file in the shared app container. */
@Serializable
data class AppState(
    val version: Int = CURRENT_VERSION,
    val tasks: List<TaskItem> = emptyList(),
    val settings: AppSettings = AppSettings(),
) {
    companion object {
        /** 2: open tasks keep the order people drag them into (1 always sorted by priority and time). */
        const val CURRENT_VERSION = 2
    }
}

@Serializable
data class AppSettings(
    val onboardingComplete: Boolean = false,
    val wallpaper: WallpaperStyle = WallpaperStyle(),
    val automation: AutomationSettings = AutomationSettings(),
    val clearCompletedEachMorning: Boolean = true,
    val lastClearedDay: CalendarDay? = null,
    /** Saved by the app so background shortcuts render at the right size. */
    val screen: ScreenMetrics? = null,
) {
    fun withClearCompletedEachMorning(on: Boolean) = copy(clearCompletedEachMorning = on)
}

@Serializable
data class AutomationSettings(
    val shortcutAdded: Boolean = false,
    /** The person says they added the close automation in Shortcuts. */
    val automationAdded: Boolean = false,
    /** Set each time the shortcut asks TaskWall for a wallpaper. */
    val lastUpdateMillis: Long? = null,
    /** Set each time TaskWall goes to the background. */
    val lastAppClosedMillis: Long? = null,
    /** True once the shortcut has run right after TaskWall closed, i.e. the close automation works. */
    val updatesWhenClosed: Boolean = false,
    /** Fingerprint of what the last wallpaper showed; see [TaskWallStore.isWallpaperCurrent]. */
    val lastWallpaperSignature: String? = null,
    /**
     * True once the shortcut has run "Confirm Wallpaper Set". From then on a wallpaper
     * only counts once iOS has set it, not when Wallist hands it over.
     */
    val shortcutConfirms: Boolean = false,
    /** What the wallpaper handed over but not yet confirmed shows. */
    val pendingWallpaperSignature: String? = null,
) {
    val isSetUp: Boolean get() = shortcutAdded && automationAdded && lastUpdateMillis != null

    // Swift sees Kotlin's copy() with every argument required; these read better there.
    fun withShortcutAdded(added: Boolean) = copy(shortcutAdded = added)
    fun withAutomationAdded(added: Boolean) = copy(automationAdded = added)
}

/**
 * Which screens the Wallist shortcut sets, read by its "Get Wallpaper Mode" step on
 * every run, so the app can switch modes without anyone adding the shortcut again.
 *
 * The bundled shortcut's "lock" branch doesn't yet pick Lock Screen only (its
 * Set Wallpaper Photo has no screens chosen, so it sets both). Fix that in the
 * shortcut before the app ever returns [LOCK_ONLY].
 */
enum class ShortcutMode(val value: String) {
    LOCK_AND_HOME("both"),
    LOCK_ONLY("lock"),
}

@Serializable
data class ScreenMetrics(val widthPoints: Double, val heightPoints: Double, val scale: Double)

@Serializable
data class WallpaperStyle(
    val source: BackgroundSource = BackgroundSource.COLOR,
    val theme: WallpaperTheme = WallpaperTheme.INK,
    /** File name of the chosen photo inside the shared app container. */
    val photoFileName: String? = null,
    /** How the person framed the photo in Adjust Photo. 1.0 = fill the screen. */
    val photoZoom: Double = 1.0,
    /** Offsets as a fraction of the screen size. */
    val photoOffsetX: Double = 0.0,
    val photoOffsetY: Double = 0.0,
    val layout: WallpaperLayout = WallpaperLayout.LIST,
    val showProgress: Boolean = true,
    val textTone: ToneSetting = ToneSetting.AUTOMATIC,
    val backdrop: BackdropSetting = BackdropSetting.AUTOMATIC,
    val position: TaskPosition = TaskPosition.BELOW_CLOCK,
    /** Result of measuring the current photo; null until a photo is analysed. */
    val photoAnalysis: LegibilityResult? = null,
    /** The typeface of the task list. Matrix and Orbit need Pro. */
    val font: WallpaperFont = WallpaperFont.CLASSIC,
) {
    val hasPhoto: Boolean get() = photoFileName != null

    fun withTheme(theme: WallpaperTheme) = copy(theme = theme, source = BackgroundSource.COLOR)

    /** Switches between colour and photo; photo only sticks once a photo exists. */
    fun withSource(source: BackgroundSource) =
        copy(source = if (source == BackgroundSource.PHOTO && photoFileName == null) BackgroundSource.COLOR else source)

    /** A new photo starts unframed and unmeasured. */
    fun withPhoto(fileName: String) = copy(
        source = BackgroundSource.PHOTO,
        photoFileName = fileName,
        photoZoom = 1.0,
        photoOffsetX = 0.0,
        photoOffsetY = 0.0,
        photoAnalysis = null,
    )

    fun withFraming(zoom: Double, offsetX: Double, offsetY: Double) =
        copy(photoZoom = zoom.coerceIn(1.0, 4.0), photoOffsetX = offsetX, photoOffsetY = offsetY)

    fun withAnalysis(analysis: LegibilityResult?) = copy(photoAnalysis = analysis)
    fun withLayout(layout: WallpaperLayout) = copy(layout = layout)
    fun withShowProgress(show: Boolean) = copy(showProgress = show)
    fun withTextTone(tone: ToneSetting) = copy(textTone = tone)
    fun withBackdrop(backdrop: BackdropSetting) = copy(backdrop = backdrop)
    fun withPosition(position: TaskPosition) = copy(position = position)
    fun withFont(font: WallpaperFont) = copy(font = font)

    /** What a person without Pro keeps: everything except a Pro font. */
    fun withoutProFeatures() = if (font.isPro) copy(font = WallpaperFont.CLASSIC) else this

    companion object {
        /** Swift can't call the all-defaults constructor directly. */
        val defaultStyle = WallpaperStyle()
    }
}

enum class BackgroundSource { COLOR, PHOTO }

/** Typefaces for the task list on the wallpaper. iOS draws the clock itself. */
enum class WallpaperFont(val displayName: String, val isPro: Boolean) {
    CLASSIC("Classic", false),
    /** Doto, a dot-matrix face (SIL Open Font License). */
    MATRIX("Matrix", true),
    /** Michroma, a wide geometric face (SIL Open Font License). */
    ORBIT("Orbit", true),
}

/** Named so it doesn't clash with SwiftUI's `Layout` protocol. */
enum class WallpaperLayout { LIST, TABLE }

enum class TaskPosition { BELOW_CLOCK, BOTTOM }

// Not AUTO: "auto" is a C keyword, so Swift would see it as `auto_`.
enum class ToneSetting { AUTOMATIC, LIGHT, DARK }

enum class BackdropSetting { AUTOMATIC, CLEAR, SHADE, GLASS }

/** Text colour on a photo: LIGHT = white text, DARK = black text. */
enum class TextTone { LIGHT, DARK }

enum class Backdrop { CLEAR, SHADE, GLASS }
