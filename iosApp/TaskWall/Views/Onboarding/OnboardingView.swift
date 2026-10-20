import SwiftUI
import PhotosUI
import Shared

/// Four short steps: welcome, first tasks, pick a look, make it automatic.
/// Every step can be skipped and changed later.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: WelcomeStep { step = 1 }
                case 1: FirstTasksStep { step = 2 }
                case 2: PickLookStep { step = 3 }
                default: AutomationSetupView(onFinish: { model.completeOnboarding() })
                }
            }
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { step -= 1 } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Back")
                    }
                    ToolbarItem(placement: .principal) {
                        StepDots(current: step, total: 3)
                    }
                    if step < 3 {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Skip") { step += 1 }
                        }
                    }
                }
            }
            .animation(.default, value: step)
        }
    }
}

private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                    .frame(width: 28, height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    @Environment(AppModel.self) private var model
    let next: () -> Void

    var body: some View {
        let sample = SampleData.shared.wallpaperContent(today: model.today, style: WallpaperStyle.companion.defaultStyle)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    sampleScreen(.paper, content: sample, width: 136).rotationEffect(.degrees(-9)).offset(x: -78, y: 30)
                    sampleScreen(.sage, content: sample, width: 136, layout: .table).rotationEffect(.degrees(9)).offset(x: 78, y: 30)
                    sampleScreen(.ink, content: sample, width: 156)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your to-dos, on your Lock Screen.")
                        .font(.largeTitle.bold())
                    Text("Write today's tasks. TaskWall turns them into a wallpaper and keeps it up to date for you.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    feature("refresh", "Updates itself every morning")
                    feature("image-01", "Use any photo, tasks stay readable")
                    feature("favourite", "Free. No account, no ads")
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Get Started", action: next)
        }
    }

    private func sampleScreen(_ theme: WallpaperTheme, content: WallpaperContent, width: CGFloat, layout: WallpaperLayout = .list) -> some View {
        let style = WallpaperStyle.companion.defaultStyle.withTheme(theme: theme).withLayout(layout: layout)
        return LockScreenPreview(style: style, content: content, width: width)
            .shadow(color: .black.opacity(0.2), radius: 18, y: 12)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline.weight(.medium))
        } icon: {
            Image(icon).renderingMode(.template).resizable().frame(width: 22, height: 22)
        }
    }
}

// MARK: - First tasks

private struct FirstTasksStep: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @FocusState private var focused: Bool
    let next: () -> Void

    var body: some View {
        let titles = model.state.tasks.map { $0.title }
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's on today?").font(.largeTitle.bold())
                    Text("Add a few things. They'll be on your Lock Screen in a minute.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            }

            Section {
                HStack {
                    TextField("Add a task", text: $draft)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button(action: add) {
                        Image("add-01").renderingMode(.template)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add task")
                }
            }

            Section("Suggestions") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SampleData.shared.suggestions.filter { !titles.contains($0) }, id: \.self) { idea in
                            Button {
                                model.addQuickTask(idea)
                            } label: {
                                Label(idea, image: "add-01")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if !model.state.tasks.isEmpty {
                Section("Today · \(model.state.tasks.count)") {
                    ForEach(model.state.tasks, id: \.id) { task in
                        HStack {
                            CheckCircle(done: false)
                            Text(task.title)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { model.state.tasks[$0] }.forEach(model.delete)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Continue", action: next)
        }
    }

    private func add() {
        model.addQuickTask(draft)
        draft = ""
        focused = true
    }
}

// MARK: - Pick a look

private struct PickLookStep: View {
    @Environment(AppModel.self) private var model
    @State private var pickedItem: PhotosPickerItem?
    let next: () -> Void

    var body: some View {
        let style = model.style
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick a look").font(.largeTitle.bold())
                    Text("Use a colour or any photo from your library. Your tasks stay readable on both.")
                        .foregroundStyle(.secondary)
                }

                LockScreenPreview(width: 176)
                    .shadow(color: .black.opacity(0.2), radius: 18, y: 12)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    ThemeSwatches(selected: style.source == .color ? style.theme : WallpaperTheme.paper) {
                        model.setStyle(style.withTheme(theme: $0))
                    }
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Image("image-01").renderingMode(.template)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Use your own photo")
                }

                Picker("Layout", selection: Binding(
                    get: { model.style.layout },
                    set: { model.setStyle(model.style.withLayout(layout: $0)) }
                )) {
                    Text("List").tag(WallpaperLayout.list)
                    Text("Table").tag(WallpaperLayout.table)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Continue", action: next)
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    try? model.choosePhoto(image)
                }
                pickedItem = nil
            }
        }
    }
}
