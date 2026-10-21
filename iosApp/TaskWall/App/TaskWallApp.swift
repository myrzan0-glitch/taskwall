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
                .tint(.peach)
                .toggleStyle(BrandSwitchStyle())
                // The design is dark only.
                .preferredColorScheme(.dark)
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

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.settings.onboardingComplete {
            TasksView()
        } else {
            OnboardingView()
        }
    }
}

/// Flags the UI tests launch the app with. They do nothing in normal use.
///
/// - `-uiTesting`: keep data in a separate file and turn animations off.
/// - `-reset`: start with no tasks and no settings.
/// - `-skipOnboarding`: open straight on Today.
/// - `-seed`: start with a few example tasks.
enum LaunchOptions {
    private static let arguments = Set(CommandLine.arguments)

    static var isUITesting: Bool { arguments.contains("-uiTesting") }

    @MainActor
    static func makeModel() -> AppModel {
        guard isUITesting else { return AppModel() }
        UIView.setAnimationsEnabled(false)
        let file = AppGroupFileStore(fileName: "taskwall-uitests.json")
        if arguments.contains("-reset") {
            file.reset()
            UserDefaults.standard.removeObject(forKey: "hideCompleted")
        }
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
        _ = store.addTask(title: "Dentist", notes: "", priority: .noPriority, dueDay: today.plusDays(days: 1), dueMinutes: kotlinInt(9 * 60), showOnWallpaper: true, nowMillis: now)
        _ = store.addTask(title: "Renew passport", notes: "", priority: .high, dueDay: today.plusDays(days: -1), dueMinutes: nil, showOnWallpaper: true, nowMillis: now)
        let done = store.addTask(title: "Pay rent", notes: "", priority: .noPriority, dueDay: today, dueMinutes: nil, showOnWallpaper: true, nowMillis: now)
        store.setDone(id: done.id, done: true, today: today, nowMillis: now)
    }
}
