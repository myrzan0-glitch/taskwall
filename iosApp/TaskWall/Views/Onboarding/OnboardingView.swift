import SwiftUI
import PhotosUI
import Shared

/// Welcome, then four short steps: what to keep in view, first tasks, a look, and
/// automatic updates. Between the look and the updates, the person sees their own
/// Lock Screen, then Pro is offered once; "Not now" carries on. Every step can be
/// skipped and changed later.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(ProStore.self) private var pro
    @State private var step: Step = .welcome
    @State private var focus: Set<FocusArea> = []
    /// A Pro font tried on the look step: previewed, and kept only if Pro starts.
    @State private var trying: WallpaperFont?

    private enum Step: Int {
        case welcome, focus, tasks, look, reveal, offer, automate

        /// The numbered steps. The reveal and the offer sit between 3 and 4 without one.
        var number: Int? {
            switch self {
            case .focus: 1
            case .tasks: 2
            case .look: 3
            case .automate: 4
            default: nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome: WelcomeStep { step = .focus }
                case .focus: FocusStep(focus: $focus) { step = .tasks }
                case .tasks: FirstTasksStep(focus: focus) { step = .look }
                case .look: PickLookStep(trying: $trying) { step = .reveal }
                case .reveal: RevealStep(style: lookStyle, next: afterReveal)
                case .offer:
                    ProOfferStep(trying: trying, onUnlocked: { keepTriedFont(); step = .automate }, onNotNow: notNow)
                case .automate:
                    AutomationSetupView(stepLabel: "Step 4", finishTitle: "Continue", onFinish: { model.completeOnboarding() })
                }
            }
            .toolbar {
                if step != .welcome && step != .offer {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Haptic.tap.play()
                            goBack()
                        } label: {
                            Image("arrow-left-01").renderingMode(.template)
                        }
                        .accessibilityLabel("Back")
                    }
                }
                if let number = step.number {
                    ToolbarItem(placement: .principal) {
                        StepDots(current: number, total: 4)
                    }
                }
                if step == .offer {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptic.tap.play()
                            notNow()
                        } label: {
                            Image("cancel-01").renderingMode(.template)
                        }
                        .accessibilityLabel("Close")
                    }
                } else if step != .reveal {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") {
                            Haptic.tap.play()
                            skip()
                        }
                    }
                }
            }
            .animation(.default, value: step)
        }
        .tint(.ink)
        // Pro can also start from a restore or a purchase on another device.
        .onChange(of: pro.isPro) { _, isPro in
            if isPro { keepTriedFont() }
        }
    }

    /// The look as chosen, with the Pro font being tried.
    private var lookStyle: WallpaperStyle {
        trying.map { model.style.withFont(font: $0) } ?? model.style
    }

    private func afterReveal() {
        if pro.isPro {
            keepTriedFont()
            step = .automate
        } else {
            step = .offer
        }
    }

    private func notNow() {
        trying = nil
        step = .automate
    }

    private func keepTriedFont() {
        guard let font = trying else { return }
        trying = nil
        model.setStyle(model.style.withFont(font: font))
    }

    private func goBack() {
        switch step {
        case .automate: step = .reveal
        default: step = Step(rawValue: step.rawValue - 1) ?? .welcome
        }
    }

    private func skip() {
        switch step {
        case .welcome, .automate: model.completeOnboarding()
        case .look: step = .reveal
        default: step = Step(rawValue: step.rawValue + 1) ?? .automate
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
    @Environment(AppModel.self) private var model
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LockScreenPreview(content: SampleData.shared.wallpaperContent(today: model.today, style: model.style), width: 170)
                .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
                .padding(.top, 12)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Text("Welcome to Wallist")
                    .font(.subheadline)
                    .foregroundStyle(Color.muted)
                Text("Your tasks, on your Lock Screen")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text("See today’s list every time you pick up your phone. No app to open.")
                    .font(.body)
                    .foregroundStyle(Color.muted)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 16)
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

// MARK: - What to keep in view

private struct FocusStep: View {
    @Binding var focus: Set<FocusArea>
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            StepHeading(
                step: "Step 1",
                title: Text("What do you want to keep in view?"),
                subtitle: "Pick any. We’ll suggest a few tasks to start."
            )
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(FocusArea.entries, id: \.self) { area in
                    tile(area)
                }
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ground.ignoresSafeArea())
        .safeAreaBar(edge: .bottom) {
            PrimaryButton("Continue", action: next)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    private func tile(_ area: FocusArea) -> some View {
        let on = focus.contains(area)
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Button {
            if on { focus.remove(area) } else { focus.insert(area) }
        } label: {
            VStack(alignment: .leading) {
                Image(systemName: icon(area))
                    .font(.system(size: 24))
                    .foregroundStyle(on ? Color.ground : Color.peach)
                Spacer(minLength: 12)
                Text(area.displayName)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .foregroundStyle(on ? Color.ground : Color.ink)
            .background(shape.fill(on ? Color.ink : Color.raised))
            .overlay(shape.strokeBorder(Color.white.opacity(on ? 0 : 0.08)))
            .contentShape(shape)
            .animation(.easeOut(duration: 0.18), value: on)
        }
        .hapticButtonStyle(.plain)
        .accessibilityLabel(area.displayName)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func icon(_ area: FocusArea) -> String {
        if area == .work { return "briefcase.fill" }
        if area == .home { return "house.fill" }
        if area == .health { return "heart.fill" }
        return "flag.fill"
    }
}

// MARK: - First tasks

private struct FirstTasksStep: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @FocusState private var focused: Bool
    /// What the person picked on step 1, for the ideas.
    let focus: Set<FocusArea>
    let next: () -> Void

    var body: some View {
        let tasks = model.state.tasks
        let titles = tasks.map { $0.title }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StepHeading(step: "Step 2", title: Text("What's on \(inlineIcon("checkmark-circle-02")) today?"))

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
                            .hapticButtonStyle(.plain)
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

                Text(focus.isEmpty ? "Ideas" : "Ideas for you")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .padding(.bottom, -10)
                FlowLayout(spacing: 8) {
                    ForEach(SampleData.shared.ideas(focus: focus).filter { !titles.contains($0) }.prefix(4), id: \.self) { idea in
                        Button { model.addQuickTask(idea) } label: {
                            ChipLabel(title: idea)
                        }
                        .hapticButtonStyle(.plain)
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
    @Environment(ProStore.self) private var pro
    /// A Pro font being tried without Pro: shown in the preview, not saved.
    @Binding var trying: WallpaperFont?
    @State private var pickedItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    let next: () -> Void

    var body: some View {
        let style = model.style
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LockScreenPreview(style: trying.map { style.withFont(font: $0) }, width: 130)
                        .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                    Spacer(minLength: 24)

                    VStack(alignment: .leading, spacing: 20) {
                        StepHeading(step: "Step 3", title: Text("Pick a \(inlineIcon("paint-board")) look"), subtitle: "A colour or any photo, and a font.")
                        ThemeSwatches(
                            selected: style.source == BackgroundSource.photo ? nil : style.theme,
                            photoSelected: style.source == BackgroundSource.photo,
                            onSelect: { model.setStyle(style.withTheme(theme: $0)) },
                            onPhoto: {
                                if style.hasPhoto { model.setStyle(style.withSource(source: .photo)) } else { showPhotoPicker = true }
                            }
                        )
                        FontPicker(selected: trying ?? style.font, isPro: pro.isPro, onSelect: pickFont)
                        if let trying {
                            Text("\(trying.displayName) is a Pro font. Try it here, keep it with Pro.")
                                .font(.subheadline)
                                .foregroundStyle(Color.peach)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
                // At least the screen's height, so the controls sit low as on the other steps.
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(Color.ink)
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

    /// Free fonts are saved at once; a Pro font without Pro is only previewed.
    private func pickFont(_ font: WallpaperFont) {
        if font.isPro && !pro.isPro {
            trying = font
        } else {
            trying = nil
            model.setStyle(model.style.withFont(font: font))
        }
    }
}

// MARK: - This is your Lock Screen

/// The look on the whole screen, as it will be: the moment before Pro is offered.
private struct RevealStep: View {
    let style: WallpaperStyle
    let next: () -> Void

    var body: some View {
        GeometryReader { proxy in
            LockScreenPreview(style: style, width: proxy.size.width)
        }
        .ignoresSafeArea()
        .background(Color.ground.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("This is your Lock Screen")
                    .font(.system(size: 28, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("reveal")
                Text("In \(style.font.displayName) on \(backgroundName). Tick a task off in Wallist and it leaves your Lock Screen too.")
                    .font(.subheadline)
                    .foregroundStyle(Color.ink.opacity(0.7))
                PrimaryButton("Looks great", action: next)
                    .padding(.top, 10)
            }
            .foregroundStyle(Color.ink)
            .padding(20)
            .glassEffect(.regular.tint(Color.ground.opacity(0.55)), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var backgroundName: String {
        style.source == BackgroundSource.photo ? String(localized: "your photo") : style.theme.displayName
    }
}

// MARK: - Pro, once

/// Pro offered once, right after the reveal: the font they tried in the headline,
/// what Pro adds, the plans, and "Not now".
private struct ProOfferStep: View {
    let trying: WallpaperFont?
    let onUnlocked: () -> Void
    let onNotNow: () -> Void
    @State private var selected: ProPlan = .yearly

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProFontsTile(size: 60)
                headline
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("proOffer")

                VStack(alignment: .leading, spacing: 12) {
                    perk("paint-board", "Matrix, Orbit and Grace on your Lock Screen")
                    perk("star", "Every new font as it lands")
                    perk("checkmark-circle-02", "Tasks, colours and photos stay free")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(Color.ink)
        .background(Color.ground.ignoresSafeArea())
        .safeAreaBar(edge: .bottom) {
            ProPurchase(selected: $selected, notNow: onNotNow, onUnlocked: onUnlocked)
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var headline: some View {
        if let trying {
            Text("Keep \(Text(trying.displayName).font(nameFont(trying)).foregroundStyle(Color.peach)) with Pro")
        } else {
            Text("Make it yours with Pro")
        }
    }

    /// The tried font's own name, set in that font.
    private func nameFont(_ font: WallpaperFont) -> Font {
        if font == .matrix { return .custom("DotoRounded-Black", fixedSize: 32) }
        if font == .orbit { return Font(WallpaperFont.orbit(size: 22)) }
        return .custom(WallpaperFonts.grace, fixedSize: 40)
    }

    private func perk(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.ground)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.peach))
                .accessibilityHidden(true)
            Text(text).font(.body)
        }
    }
}
