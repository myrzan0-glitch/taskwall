import SwiftUI
import Shared

@main
struct TaskWallApp: App {
    @State private var model = AppModel()
    @State private var tips = TipStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(tips)
                .onOpenURL { model.handle($0) }
                .task { await tips.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
    }
}

enum AppTab: Hashable {
    case tasks, wallpaper, settings, search
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .tasks

    var body: some View {
        if model.settings.onboardingComplete {
            TabView(selection: $tab) {
                Tab("Tasks", image: "task-done-01", value: AppTab.tasks) {
                    TasksView()
                }
                Tab("Wallpaper", image: "smartphone", value: AppTab.wallpaper) {
                    WallpaperView()
                }
                Tab("Settings", image: "settings-02", value: AppTab.settings) {
                    SettingsView()
                }
                Tab(value: AppTab.search, role: .search) {
                    SearchView()
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            OnboardingView()
        }
    }
}
