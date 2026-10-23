import AppIntents
import UniformTypeIdentifiers
import Shared

/// The action the Wallist shortcut runs: it returns today's wallpaper as an
/// image for Shortcuts' own "Set Wallpaper" action. Runs without opening the app.
struct MakeWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Make Wallpaper"
    static let description = IntentDescription(
        "Makes a wallpaper for the Lock Screen and Home Screen from today's tasks. Pass it to Set Wallpaper.",
        categoryName: "Wallpaper"
    )
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let store = TaskWallStore(file: AppGroupFileStore.shared)
        let today = CalendarDay.today
        _ = store.clearCompletedIfDue(today: today)
        guard let data = WallpaperRenderer.pngData(store: store, today: today) else {
            throw TaskWallIntentError.renderFailed
        }
        store.recordWallpaperUpdate(nowMillis: Date().millis, today: today)
        return .result(value: IntentFile(data: data, filename: "Wallist.png", type: .png))
    }
}

/// The Wallist shortcut's first step: which screens to set this run. The shortcut
/// handles every mode, so the app can change it without the shortcut being added again.
struct WallpaperModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Wallpaper Mode"
    static let description = IntentDescription(
        "Tells the Wallist shortcut which screens to set: “both” for the Lock Screen and Home Screen, or “lock” for the Lock Screen only.",
        categoryName: "Wallpaper"
    )
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = TaskWallStore(file: AppGroupFileStore.shared)
        return .result(value: store.shortcutMode.value)
    }
}

/// The Wallist shortcut's last step. It only runs if Set Wallpaper worked, so
/// Wallist shows the Lock Screen as up to date only once it really is.
struct ConfirmWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Confirm Wallpaper Set"
    static let description = IntentDescription(
        "Tells Wallist the wallpaper was set. Put it after Set Wallpaper.",
        categoryName: "Wallpaper"
    )
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = TaskWallStore(file: AppGroupFileStore.shared)
        store.confirmWallpaperSet(nowMillis: Date().millis)
        return .result()
    }
}

/// "Add a task to Wallist" from Siri, Spotlight or a shortcut.
struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Adds a task to today's list in Wallist.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Task")
    var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TaskWallIntentError.emptyTitle }
        let store = TaskWallStore(file: AppGroupFileStore.shared)
        _ = store.addQuickTask(title: trimmed, nowMillis: Date().millis)
        return .result(dialog: "Added “\(trimmed)”.")
    }
}

enum TaskWallIntentError: Error, CustomLocalizedStringResourceConvertible {
    case renderFailed
    case emptyTitle

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .renderFailed: "Wallist couldn't make the wallpaper. Open Wallist once, then try again."
        case .emptyTitle: "The task needs a title."
        }
    }
}

/// Available as soon as Wallist is installed; no setup needed.
struct TaskWallShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MakeWallpaperIntent(),
            phrases: [
                "Update my \(.applicationName) wallpaper",
                "Make a \(.applicationName) wallpaper",
            ],
            shortTitle: "Make Wallpaper",
            systemImageName: "photo.on.rectangle"
        )
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: ["Add a task to \(.applicationName)"],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
    }
}
