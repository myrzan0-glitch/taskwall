import AppIntents
import UniformTypeIdentifiers
import Shared

/// The action the TaskWall shortcut runs: it returns today's wallpaper as an
/// image for Shortcuts' own "Set Wallpaper" action. Runs without opening the app.
struct MakeWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Make Wallpaper"
    static let description = IntentDescription(
        "Makes a Lock Screen wallpaper from today's tasks. Pass it to Set Wallpaper.",
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
        return .result(value: IntentFile(data: data, filename: "TaskWall.png", type: .png))
    }
}

/// "Add a task to Task on Wallpaper" from Siri, Spotlight or a shortcut.
struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Adds a task to today's list in Task on Wallpaper.")
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
        case .renderFailed: "Task on Wallpaper couldn't make the wallpaper. Open Task on Wallpaper once, then try again."
        case .emptyTitle: "The task needs a title."
        }
    }
}

/// Available as soon as TaskWall is installed; no setup needed.
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
