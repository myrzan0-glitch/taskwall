import SwiftUI
import Shared

/// The Settings sheet, from the right button on Today.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(ProStore.self) private var pro
    @Environment(\.openURL) private var openURL
    @State private var showPro = false
    @State private var showGuide = false
    @State private var path: [Route] = []

    enum Route: Hashable { case automation }

    /// Set once the app is on the App Store, e.g.
    /// `URL(string: "https://apps.apple.com/app/id1234567890?action=write-review")`.
    /// Until then the Rate row is hidden.
    private let reviewURL: URL? = nil
    private let feedbackURL = URL(string: "mailto:izimbetov.myrzan@icloud.com?subject=Task%20on%20Wallpaper%20feedback")!

    var body: some View {
        let automation = model.automation
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    Button { showPro = true } label: { proCard }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("proCard")
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        NavigationLink(value: Route.automation) {
                            row("Automatic updates", icon: "refresh") {
                                Text(automation.isSetUp ? "On" : "Off").foregroundStyle(Color.muted)
                                chevron
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("automaticUpdates")
                        DottedDivider()

                        row("Lock Screen", icon: "square-lock-02") {
                            Text(lastUpdateText)
                                .font(.subheadline)
                                .foregroundStyle(Color.muted)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(Capsule().fill(Color.control))
                            Button("Update") { openURL(ShortcutLinks.runShortcut) }
                                .font(.subheadline.weight(.semibold))
                                .prominentButton()
                                .accessibilityIdentifier("updateNow")
                        }
                        DottedDivider()

                        row("Update when I close the app", icon: "smartphone") {
                            // Read from what actually happened, not a setting: the app can't
                            // create the automation, only notice the shortcut running after it closes.
                            if automation.updatesWhenClosed {
                                Text("On").foregroundStyle(Color.muted)
                            } else if automation.automationAdded {
                                Text("Waiting").foregroundStyle(Color.muted)
                            } else {
                                Button("Set up") { showGuide = true }
                                    .font(.subheadline.weight(.semibold))
                                    .buttonStyle(.glass)
                                    .buttonBorderShape(.capsule)
                                    .accessibilityIdentifier("setUpCloseAutomation")
                            }
                        }
                        DottedDivider()

                        if let reviewURL {
                            Link(destination: reviewURL) {
                                row("Rate on the App Store", icon: "star") { chevron }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("rateApp")
                            DottedDivider()
                        }

                        Link(destination: feedbackURL) {
                            row("Send feedback", icon: "message-01") { chevron }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sendFeedback")
                        DottedDivider()

                        row("Version", icon: "information-circle") {
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                                .foregroundStyle(Color.muted)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .foregroundStyle(Color.ink)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { _ in
                AutomationSetupView(finishTitle: "Done", onFinish: { path.removeAll() })
            }
        }
        .toggleStyle(BrandSwitchStyle())
        .tint(.ink)
        .presentationBackground(Color.sheet)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPro) {
            ProView()
        }
        .sheet(isPresented: $showGuide) {
            AutomationGuideView {
                model.setAutomation(model.automation.withAutomationAdded(added: true))
            }
        }
    }

    /// Wallist Pro, where the tip jar used to be.
    private var proCard: some View {
        HStack(spacing: 14) {
            Text("Aa")
                .font(.custom("DotoRounded-Black", fixedSize: 26))
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Wallist Pro")
                    .font(.system(size: 20, weight: .bold))
                Text(pro.isPro ? "Matrix and Orbit fonts are yours." : "Matrix and Orbit wallpaper fonts.")
                    .font(.subheadline)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(pro.isPro ? "Active" : "Pro")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Capsule().fill(Color.ground.opacity(0.9)))
        }
        .foregroundStyle(Color.ground)
        .padding(.horizontal, 20)
        .frame(minHeight: 96)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.peach))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pro.isPro ? "Wallist Pro, active" : "Wallist Pro. Matrix and Orbit wallpaper fonts.")
        .accessibilityAddTraits(.isButton)
    }

    private var chevron: some View {
        Image("arrow-right-01")
            .renderingMode(.template)
            .resizable()
            .frame(width: 18, height: 18)
            .foregroundStyle(Color.muted)
    }

    private func row<Trailing: View>(_ title: String, icon: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.muted)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 19, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .frame(minHeight: 68)
        .contentShape(Rectangle())
    }

    private var lastUpdateText: String {
        guard let date = model.lastUpdate else { return "Never" }
        return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}

/// The three steps that connect the app to Shortcuts. iOS has no way for an
/// app to create an automation itself, so this keeps it to a few taps.
/// Shown as the last onboarding step, from Settings, and from Today.
struct AutomationSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var addingShortcut = false
    @State private var addingAutomation = false
    /// "Step 3" above the title, during onboarding.
    var stepLabel: String? = nil
    let finishTitle: LocalizedStringKey
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case add, automate, test

        var title: String {
            switch self {
            case .add: "Add the Wallist shortcut"
            case .automate: "Update when you close the app"
            case .test: "Run a quick test"
            }
        }

        var action: String {
            switch self {
            case .add: "Add"
            case .automate: "Set up"
            case .test: "Test"
            }
        }
    }

    var body: some View {
        let automation = model.automation
        let current = currentStep(automation)
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 10) {
                if let stepLabel {
                    Text(stepLabel).font(.subheadline.weight(.semibold))
                }
                Text("Let your \(Text(Image("square-lock-02")).foregroundStyle(Color.peach)) Lock Screen update itself")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text("Three taps in Shortcuts, once.")
                    .font(.subheadline)
                    .foregroundStyle(Color.muted)
            }

            VStack(spacing: 0) {
                ForEach(Step.allCases, id: \.self) { step in
                    stepRow(step, current: current)
                    if step != .test { DottedDivider() }
                }
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0x141416)))

            if automation.isSetUp {
                Label {
                    Text("Automation is on. Your Lock Screen updates when you close the app.")
                } icon: {
                    Image("checkmark-circle-02").renderingMode(.template)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.peach)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 24)
        // Room between the steps and the button below them.
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(Color.ground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            PrimaryButton(finishTitle, action: onFinish)
                .accessibilityIdentifier("finishSetup")
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $addingShortcut) {
            AddShortcutView {
                model.setAutomation(model.automation.withShortcutAdded(added: true))
            }
        }
        .sheet(isPresented: $addingAutomation) {
            AutomationGuideView {
                model.setAutomation(model.automation.withAutomationAdded(added: true))
            }
        }
    }

    private func currentStep(_ automation: AutomationSettings) -> Step? {
        if !automation.shortcutAdded { return .add }
        if !automation.automationAdded { return .automate }
        if automation.lastUpdateMillis == nil { return .test }
        return nil
    }

    private func isDone(_ step: Step, _ automation: AutomationSettings) -> Bool {
        switch step {
        case .add: automation.shortcutAdded
        case .automate: automation.automationAdded
        case .test: automation.lastUpdateMillis != nil
        }
    }

    private func stepRow(_ step: Step, current: Step?) -> some View {
        let done = isDone(step, model.automation)
        let isCurrent = step == current
        return HStack(spacing: 14) {
            ZStack {
                if done {
                    Image("checkmark-circle-02").renderingMode(.template).resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Circle().strokeBorder(isCurrent ? Color.ink : Color(hex: 0x3A3A3C), lineWidth: 1.5)
                    Text("\(step.rawValue + 1)")
                        .font(.footnote.bold())
                        .foregroundStyle(isCurrent ? Color.ink : Color.muted)
                }
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)

            Text(step.title)
                .font(.body.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(done || !isCurrent ? Color.muted : Color.ink)
                .strikethrough(done, color: Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Only the next step gets a button, so the steps go in order.
            if isCurrent {
                Button(step.action) { run(step) }
                    .font(.footnote.weight(.semibold))
                    .prominentButton()
            }
        }
        .frame(minHeight: isCurrent ? 68 : 60)
        // The step's button stays its own element, so it can be tapped on its own.
        .accessibilityElement(children: .contain)
    }

    private func run(_ step: Step) {
        switch step {
        case .add:
            // Marked as added only once the person confirms, not on the tap.
            addingShortcut = true
        case .automate:
            addingAutomation = true
        case .test:
            // The shortcut records its run, then sends us back via taskwall://.
            openURL(ShortcutLinks.runShortcut)
        }
    }
}
