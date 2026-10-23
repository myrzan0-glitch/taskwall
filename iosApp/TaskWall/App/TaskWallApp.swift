import SwiftUI
import UIKit
import Shared

@main
struct TaskWallApp: App {
    @State private var model = LaunchOptions.makeModel()
    @State private var pro = ProStore(alwaysPro: LaunchOptions.isPro)
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WallpaperFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.peach)
                .toggleStyle(BrandSwitchStyle())
                // The design is dark only.
                .preferredColorScheme(.dark)
                .environment(model)
                .environment(pro)
                .onOpenURL { model.handle($0) }
                .task { await pro.load() }
                // Pro fonts go back to Classic when Pro ends, so the Lock Screen
                // never keeps a font the person no longer has.
                .onChange(of: pro.status) { _, status in
                    if status == .free { model.dropProFeatures() }
                }
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
/// - `-seedCyrillic`: add a task written in Russian.
/// - `-pro`: act as if Pro is active, without the App Store.
enum LaunchOptions {
    private static let arguments = Set(CommandLine.arguments)

    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var isPro: Bool { isUITesting && arguments.contains("-pro") }

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
        if arguments.contains("-seedCyrillic") {
            _ = model.store.addTask(title: "Закончить приложение", notes: "", priority: .high, dueDay: nil, dueMinutes: nil, showOnWallpaper: true, nowMillis: Date().millis)
        }
        return model
    }

    @MainActor
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
