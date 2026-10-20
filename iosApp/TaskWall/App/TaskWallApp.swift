import SwiftUI
import UIKit
import Shared

@main
struct TaskWallApp: App {
    @State private var model = LaunchOptions.makeModel()
    @State private var tips = TipStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.brand)
                .toggleStyle(BrandSwitchStyle())
                .preferredColorScheme(LaunchOptions.colorScheme)
                .environment(model)
                .environment(tips)
                .onOpenURL { model.handle($0) }
                .task { await tips.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.becameActive()
            case .background: model.appClosed()
            default: break
            }
        }
    }
}

enum AppTab: Hashable {
    case tasks, wallpaper, settings
    /// Not a screen: the floating button at the end of the tab bar adds a task.
    case newTask
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .tasks
    @State private var addingTask = false

    var body: some View {
        if model.settings.onboardingComplete {
            TabView(selection: Binding(
                get: { tab },
                set: { picked in
                    // The add button opens the editor and leaves you where you were.
                    if picked == .newTask { addingTask = true } else { tab = picked }
                }
            )) {
                Tab("Tasks", image: "task-done-01", value: AppTab.tasks) {
                    TasksView()
                }
                Tab("Wallpaper", image: "smartphone", value: AppTab.wallpaper) {
                    WallpaperView()
                }
                Tab("Settings", image: "settings-02", value: AppTab.settings) {
                    SettingsView()
                }
                // The separate circle at the trailing end of the tab bar, where iOS puts
                // the search tab, is the easiest spot to reach; adding is the main action.
                Tab("New Task", image: "add-01", value: AppTab.newTask, role: .search) {
                    Color.clear
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .sheet(isPresented: $addingTask) {
                TaskEditor(target: .new)
            }
        } else {
            OnboardingView()
        }
    }
}

/// Flags the UI tests launch the app with. They do nothing in normal use.
///
/// - `-uiTesting`: keep data in a separate file and turn animations off.
/// - `-reset`: start with no tasks and no settings.
/// - `-skipOnboarding`: open straight on the Tasks tab.
/// - `-seed`: start with a few example tasks.
/// - `-appearance dark|light`: force dark or light mode (screenshots).
enum LaunchOptions {
    private static let arguments = Set(CommandLine.arguments)

    static var isUITesting: Bool { arguments.contains("-uiTesting") }

    static var colorScheme: ColorScheme? {
        let args = CommandLine.arguments
        guard isUITesting, let i = args.firstIndex(of: "-appearance"), i + 1 < args.count else { return nil }
        return args[i + 1] == "dark" ? .dark : .light
    }

    @MainActor
    static func makeModel() -> AppModel {
        guard isUITesting else { return AppModel() }
        UIView.setAnimationsEnabled(false)
        let file = AppGroupFileStore(fileName: "taskwall-uitests.json")
        if arguments.contains("-reset") { file.reset() }
        let model = AppModel(store: TaskWallStore(file: file))
        if arguments.contains("-skipOnboarding") { model.completeOnboarding() }
        if arguments.contains("-seed") { seed(model) }
        return model
    }

    private static func seed(_ model: AppModel) {
        let store = model.store
        let today = CalendarDay.today
        let now = Date().millis
        _ = store.addTask(title: "Buy milk", notes: "Oat, not dairy", priority: .high, dueDay: today, dueMinutes: kotlinInt(17 * 60), showOnWallpaper: true, nowMillis: now)
        _ = store.addTask(title: "Call mum", notes: "", priority: .noPriority, dueDay: nil, dueMinutes: nil, showOnWallpaper: true, nowMillis: now)
        _ = store.addTask(title: "Dentist", notes: "", priority: .medium, dueDay: today.plusDays(days: 1), dueMinutes: kotlinInt(9 * 60), showOnWallpaper: true, nowMillis: now)
        _ = store.addTask(title: "Renew passport", notes: "", priority: .high, dueDay: today.plusDays(days: -1), dueMinutes: nil, showOnWallpaper: true, nowMillis: now)
        let done = store.addTask(title: "Pay rent", notes: "", priority: .noPriority, dueDay: today, dueMinutes: nil, showOnWallpaper: true, nowMillis: now)
        store.setDone(id: done.id, done: true, today: today, nowMillis: now)
    }
}
