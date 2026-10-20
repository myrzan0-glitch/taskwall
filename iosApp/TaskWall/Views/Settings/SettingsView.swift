import SwiftUI
import Shared

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showTips = false

    /// Replace with the App Store ID once the app is listed.
    private let reviewURL = URL(string: "https://apps.apple.com/app/idREPLACE_WITH_APP_ID?action=write-review")!
    private let feedbackURL = URL(string: "mailto:REPLACE_WITH_EMAIL?subject=TaskWall%20feedback")!

    var body: some View {
        NavigationStack {
            Form {
                AutomationSection()

                Section {
                    Button {
                        showTips = true
                    } label: {
                        settingsRow("Buy Me a Coffee", icon: "coffee-02", filled: true)
                    }
                    .accessibilityIdentifier("tipJar")
                    Link(destination: reviewURL) {
                        settingsRow("Rate on the App Store", icon: "star")
                    }
                    .accessibilityIdentifier("rateApp")
                    Link(destination: feedbackURL) {
                        settingsRow("Send Feedback", icon: "message-01")
                    }
                    .accessibilityIdentifier("sendFeedback")
                } header: {
                    Text("Support TaskWall")
                } footer: {
                    Text("TaskWall is free. No ads, no account, no tracking.")
                }

                Section("Tasks") {
                    Toggle("Clear Completed Each Morning", isOn: Binding(
                        get: { model.settings.clearCompletedEachMorning },
                        set: { model.setClearCompletedEachMorning($0) }
                    ))
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showTips) {
                TipJarView()
            }
        }
    }

    private func settingsRow(_ title: String, icon: String, filled: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(filled ? Color(.systemBackground) : .primary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(filled ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                )
            Text(title).foregroundStyle(.primary)
            Spacer()
            Image("arrow-right-01")
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(.tertiary)
        }
        // The icons are decoration; VoiceOver should read the title only.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// Automatic updates: status, schedule, and a way back into setup.
struct AutomationSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showSetup = false
    @State private var showGuide = false

    var body: some View {
        let automation = model.automation
        Section {
            HStack(spacing: 12) {
                Image(automation.isSetUp ? "checkmark-circle-02" : "clock-01")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(automation.isSetUp ? "On" : "Not set up").font(.headline)
                    Text(lastUpdateText).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Update Now") { openURL(ShortcutLinks.runShortcut) }
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }

            DatePicker("Every Morning At", selection: Binding(
                get: { Date.at(minutesAfterMidnight: Int(automation.morningMinutes)) },
                set: { model.setAutomation(model.automation.withMorningMinutes(minutes: Int32($0.minutesAfterMidnight))) }
            ), displayedComponents: .hourAndMinute)

            // Read from what actually happened, not a setting: TaskWall can't
            // create the automation, only notice the shortcut running after it closes.
            LabeledContent("When I Close TaskWall") {
                if automation.updatesWhenClosed {
                    Text("On")
                } else if automation.automationAdded {
                    Text("Waiting for first run")
                } else {
                    Button("Set Up") { showGuide = true }
                        .accessibilityIdentifier("setUpCloseAutomation")
                }
            }

            Button(automation.isSetUp ? "Set Up Again" : "Set Up Automatic Updates") { showSetup = true }
        } header: {
            Text("Automatic Updates")
        } footer: {
            Text("Runs through the TaskWall shortcut and automations in the Shortcuts app, the only app iOS lets change your wallpaper. Set the morning time there too.")
        }
        .sheet(isPresented: $showGuide) {
            AutomationGuideView {
                model.setAutomation(model.automation.withAutomationAdded(added: true))
            }
        }
        .sheet(isPresented: $showSetup) {
            NavigationStack {
                AutomationSetupView(onFinish: { showSetup = false })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close) { showSetup = false }
                        }
                    }
            }
        }
    }

    private var lastUpdateText: String {
        guard let date = model.lastUpdate else { return "Hasn't run yet" }
        return "Last update " + date.formatted(.relative(presentation: .named))
    }
}

/// Pushed from the Wallpaper tab.
struct AutomationSettingsView: View {
    var body: some View {
        Form { AutomationSection() }
            .navigationTitle("Automatic Updates")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// The three steps that connect TaskWall to Shortcuts. iOS has no way for an
/// app to create an automation itself, so this keeps it to a few taps.
struct AutomationSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var addingShortcut = false
    @State private var addingAutomation = false
    var showsHeader = true
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case add, automate, test

        var title: String {
            switch self {
            case .add: "Add the TaskWall shortcut"
            case .automate: "Update when you close TaskWall"
            case .test: "Run a quick test"
            }
        }

        var detail: String {
            switch self {
            case .add: "One tap. It makes your wallpaper and sets it."
            case .automate: "An automation in Shortcuts, so finished tasks reach your Lock Screen as soon as you leave."
            case .test: "Watch your Lock Screen update."
            }
        }

        var action: String {
            switch self {
            case .add: "Add"
            case .automate: "Set Up"
            case .test: "Test"
            }
        }
    }

    var body: some View {
        let automation = model.automation
        let current = currentStep(automation)
        List {
            if showsHeader {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make it automatic").font(.largeTitle.bold())
                        Text("TaskWall updates your Lock Screen on its own. iOS asks you to approve that once in Shortcuts. It takes about 30 seconds.")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                }
            }

            Section {
                ForEach(Step.allCases, id: \.self) { step in
                    stepRow(step, current: current)
                }
            }

            Section("Update My Wallpaper") {
                DatePicker("Every Morning At", selection: Binding(
                    get: { Date.at(minutesAfterMidnight: Int(automation.morningMinutes)) },
                    set: { model.setAutomation(model.automation.withMorningMinutes(minutes: Int32($0.minutesAfterMidnight))) }
                ), displayedComponents: .hourAndMinute)
            }

            if automation.isSetUp {
                Section {
                    Label("Automation is on. Your Lock Screen updates when you close TaskWall and at \(morningText).", image: "refresh")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .listRowBackground(Color.primary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            Button(action: onFinish) {
                Text(automation.isSetUp ? "Done" : "Set Up Later").frame(maxWidth: .infinity)
            }
            .prominentButton()
            .controlSize(.large)
            .padding()
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

    private var morningText: String {
        Date.at(minutesAfterMidnight: Int(model.automation.morningMinutes)).formatted(date: .omitted, time: .shortened)
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
                    Circle().fill(.primary)
                    Image("tick-02").renderingMode(.template).resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color(.systemBackground))
                } else {
                    Circle().strokeBorder(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary), lineWidth: 1.5)
                    Text("\(step.rawValue + 1)").font(.subheadline.bold())
                        .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title).font(.headline)
                    .foregroundStyle(done || isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                Text(step.detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            // Only the next step gets a button; disabled filled buttons for later
            // steps were nearly invisible in light mode.
            if isCurrent {
                Button(step.action) { run(step) }
                    .prominentButton()
            }
        }
        .padding(.vertical, 6)
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
