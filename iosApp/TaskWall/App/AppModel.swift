import SwiftUI
import UIKit
import Shared

/// The app's view of the shared Kotlin store. Views read `state` and call
/// the actions below; every change is saved by the store immediately.
@MainActor
@Observable
final class AppModel {
    let store: TaskWallStore
    private(set) var state: AppState
    private(set) var photo: UIImage?
    private(set) var screenSize = CGSize(width: 393, height: 852)

    @ObservationIgnored private var subscription: ListenerHandle?
    @ObservationIgnored private var loadedPhotoName: String?

    init(store: TaskWallStore = TaskWallStore(file: AppGroupFileStore.shared)) {
        self.store = store
        self.state = store.state
        self.loadedPhotoName = store.state.settings.wallpaper.photoFileName
        self.photo = PhotoStore.load(loadedPhotoName)
        if let screen = store.state.settings.screen {
            screenSize = CGSize(width: screen.widthPoints, height: screen.heightPoints)
        }
        subscription = store.addListener { [weak self] newState in
            MainActor.assumeIsolated { self?.apply(newState) }
        }
    }

    // MARK: Reading

    var settings: AppSettings { state.settings }
    var style: WallpaperStyle { state.settings.wallpaper }
    var automation: AutomationSettings { state.settings.automation }
    var today: CalendarDay { CalendarDay.today }

    func sections(_ filter: TaskFilter) -> [TaskSection] {
        TaskQueries.shared.sections(tasks: state.tasks, today: today, filter: filter)
    }

    var progress: TaskProgress {
        TaskQueries.shared.todayProgress(tasks: state.tasks, today: today)
    }

    func wallpaperContent(for style: WallpaperStyle? = nil) -> WallpaperContent {
        let style = style ?? self.style
        let maxLines = WallpaperGeometry.shared.maxLines(layout: style.layout, showProgress: style.showProgress)
        return WallpaperComposer.shared.compose(tasks: state.tasks, today: today, maxLines: maxLines)
    }

    func appearance(for style: WallpaperStyle? = nil) -> ResolvedAppearance {
        WallpaperAppearance.shared.resolve(style: style ?? self.style)
    }

    func search(_ query: String) -> [TaskItem] {
        _ = state
        return store.search(query: query, today: today)
    }

    var lastUpdate: Date? {
        automation.lastUpdateMillis.map { Date(millis: $0.int64Value) }
    }

    // MARK: Tasks

    func add(_ draft: TaskDraft) {
        _ = store.addTask(
            title: draft.title,
            notes: draft.notes,
            priority: draft.priority,
            dueDay: draft.dueDay,
            dueMinutes: draft.dueMinutes,
            showOnWallpaper: draft.showOnWallpaper,
            nowMillis: Date().millis
        )
    }

    func addQuickTask(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = store.addQuickTask(title: trimmed, nowMillis: Date().millis)
    }

    func update(_ task: TaskItem, with draft: TaskDraft) {
        store.updateTask(task: task.edited(
            title: draft.title,
            notes: draft.notes,
            priority: draft.priority,
            dueDay: draft.dueDay,
            dueMinutes: draft.dueMinutes,
            showOnWallpaper: draft.showOnWallpaper
        ))
    }

    func toggle(_ task: TaskItem) {
        store.toggleDone(id: task.id, today: today, nowMillis: Date().millis)
    }

    func delete(_ task: TaskItem) {
        store.deleteTask(id: task.id)
    }

    func clearCompleted() {
        _ = store.clearCompleted()
    }

    // MARK: Wallpaper

    func setStyle(_ style: WallpaperStyle) {
        store.setWallpaperStyle(style: style)
    }

    /// Saves a photo from the library and measures how readable tasks will be on it.
    func choosePhoto(_ image: UIImage) throws {
        let fileName = try PhotoStore.save(image, replacing: style.photoFileName)
        var next = style.withPhoto(fileName: fileName)
        let saved = PhotoStore.load(fileName) ?? image
        next = next.withAnalysis(analysis: PhotoAnalyzer.analyze(saved, style: next, canvas: screenSize))
        photo = saved
        loadedPhotoName = fileName
        setStyle(next)
    }

    /// Measures the photo again after it was moved, zoomed or the tasks moved.
    func analyzed(_ style: WallpaperStyle) -> WallpaperStyle {
        guard let photo, style.hasPhoto else { return style }
        return style.withAnalysis(analysis: PhotoAnalyzer.analyze(photo, style: style, canvas: screenSize))
    }

    func renderWallpaper() -> UIImage? {
        WallpaperRenderer.image(store: store, today: today, photo: photo)
    }

    // MARK: Settings

    func setAutomation(_ automation: AutomationSettings) {
        store.setAutomation(automation: automation)
    }

    func setClearCompletedEachMorning(_ on: Bool) {
        store.setClearCompletedEachMorning(on: on)
    }

    func completeOnboarding() {
        store.completeOnboarding()
    }

    // MARK: Lifecycle

    /// Picks up changes a shortcut made in the background and tidies up yesterday.
    func becameActive() {
        store.reload()
        _ = store.clearCompletedIfDue(today: today)
        let screen = ScreenInfo.current
        screenSize = screen.size
        store.setScreen(metrics: ScreenMetrics(
            widthPoints: screen.size.width,
            heightPoints: screen.size.height,
            scale: screen.scale
        ))
    }

    func handle(_ url: URL) {
        guard url.scheme == "taskwall" else { return }
        // The shortcut records its own run; just read the new state.
        store.reload()
    }

    private func apply(_ newState: AppState) {
        state = newState
        let name = newState.settings.wallpaper.photoFileName
        if name != loadedPhotoName {
            loadedPhotoName = name
            photo = PhotoStore.load(name)
        }
    }
}

/// The New Task / Edit Task form.
struct TaskDraft {
    var title = ""
    var notes = ""
    var priority: Priority = .noPriority
    var hasDueDate = true
    var dueDate = Date()
    var hasTime = false
    var time = Date.at(minutesAfterMidnight: 17 * 60)
    var showOnWallpaper = true

    init() {}

    init(task: TaskItem) {
        title = task.title
        notes = task.notes
        priority = task.priority
        hasDueDate = task.dueDay != nil
        dueDate = task.dueDay?.date() ?? Date()
        hasTime = task.dueMinutes != nil
        if let minutes = task.dueMinutes {
            time = Date.at(minutesAfterMidnight: Int(minutes.int32Value))
        }
        showOnWallpaper = task.showOnWallpaper
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var dueDay: CalendarDay? { hasDueDate ? CalendarDay.from(dueDate) : nil }
    var dueMinutes: KotlinInt? { hasDueDate && hasTime ? kotlinInt(time.minutesAfterMidnight) : nil }
}

@MainActor
enum ScreenInfo {
    static var current: (size: CGSize, scale: CGFloat) {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
        return (screen?.bounds.size ?? CGSize(width: 393, height: 852), screen?.scale ?? 3)
    }
}
