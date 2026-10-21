import SwiftUI
import PhotosUI
import Shared

/// Welcome, then three short steps: first tasks, a look, automatic updates.
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
                default:
                    AutomationSetupView(stepLabel: "Step 3", finishTitle: "Continue", onFinish: { model.completeOnboarding() })
                }
            }
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { step -= 1 } label: {
                            Image("arrow-left-01").renderingMode(.template)
                        }
                        .accessibilityLabel("Back")
                    }
                    ToolbarItem(placement: .principal) {
                        StepDots(current: step, total: 3)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        if step == 0 || step == 3 { model.completeOnboarding() } else { step += 1 }
                    }
                }
            }
            .animation(.default, value: step)
        }
        .tint(.ink)
    }
}

private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.ink : Color.control)
                    .frame(width: 28, height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

/// "Step 1" and a large title with an icon in the line, as in the design.
private struct StepHeading: View {
    let step: String
    let title: Text
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step).font(.subheadline.weight(.semibold))
            title
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Color.muted)
            }
        }
    }
}

private func inlineIcon(_ name: String) -> Text {
    Text(Image(name)).foregroundStyle(Color.peach)
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image("wallpaper")
                .renderingMode(.template)
                .resizable()
                .frame(width: 48, height: 48)
                .foregroundStyle(Color.peach)
                .frame(width: 96, height: 96)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: 0x1A1A1C)))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                Text("Welcome")
                    .font(.subheadline)
                    .foregroundStyle(Color.muted)
                Text("Your tasks, on your Lock Screen")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ground.ignoresSafeArea())
        .safeAreaBar(edge: .bottom) {
            PrimaryButton("Get started", action: next)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
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
        let tasks = model.state.tasks
        let titles = tasks.map { $0.title }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StepHeading(step: "Step 1", title: Text("What's on \(inlineIcon("checkmark-circle-02")) today?"))

                VStack(spacing: 0) {
                    ForEach(tasks, id: \.id) { task in
                        HStack(spacing: 12) {
                            CheckCircle(done: false)
                            Text(task.title).font(.body)
                            Spacer()
                            Button { model.delete(task) } label: {
                                Image("cancel-01").renderingMode(.template).resizable()
                                    .frame(width: 16, height: 16)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.muted)
                            .accessibilityLabel("Remove \(task.title)")
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: 52)
                        DottedDivider()
                    }
                    HStack(spacing: 12) {
                        Image("add-01").renderingMode(.template).resizable()
                            .frame(width: 20, height: 20)
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        TextField("Add a task", text: $draft)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit(add)
                    }
                    .padding(.horizontal, 8)
                    .frame(minHeight: 52)
                }

                FlowLayout(spacing: 8) {
                    ForEach(SampleData.shared.suggestions.filter { !titles.contains($0) }.prefix(4), id: \.self) { idea in
                        Button { model.addQuickTask(idea) } label: {
                            ChipLabel(title: idea)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(idea)")
                    }
                }
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ground.ignoresSafeArea())
        .safeAreaBar(edge: .bottom) {
            PrimaryButton("Continue", action: next)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
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
    @State private var showPhotoPicker = false
    let next: () -> Void

    var body: some View {
        let style = model.style
        VStack(alignment: .leading, spacing: 0) {
            LockScreenPreview(width: 150)
                .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 22) {
                StepHeading(step: "Step 2", title: Text("Pick a \(inlineIcon("paint-board")) look"), subtitle: "A colour, or any photo.")
                ThemeSwatches(
                    selected: style.source == BackgroundSource.photo ? nil : style.theme,
                    photoSelected: style.source == BackgroundSource.photo,
                    onSelect: { model.setStyle(style.withTheme(theme: $0)) },
                    onPhoto: {
                        if style.hasPhoto { model.setStyle(style.withSource(source: .photo)) } else { showPhotoPicker = true }
                    }
                )
            }
            .padding(.bottom, 16)
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 24)
        .background(Color.ground.ignoresSafeArea())
        .safeAreaBar(edge: .bottom) {
            PrimaryButton("Continue", action: next)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
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
