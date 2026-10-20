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

            Toggle("When I Close TaskWall", isOn: Binding(
                get: { automation.updateWhenAppCloses },
                set: { model.setAutomation(model.automation.withUpdateWhenAppCloses(on: $0)) }
            ))

            Button(automation.isSetUp ? "Set Up Again" : "Set Up Automatic Updates") { showSetup = true }
        } header: {
            Text("Automatic Updates")
        } footer: {
            Text("Runs through the TaskWall shortcut. iOS only lets the Shortcuts app change your wallpaper, so the time is set there too.")
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
    var showsHeader = true
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case add, allow, test

        var title: String {
            switch self {
            case .add: "Add the TaskWall shortcut"
            case .allow: "Let it run on its own"
            case .test: "Run a quick test"
            }
        }

        var detail: String {
            switch self {
            case .add: "One tap. It makes your wallpaper and sets it."
            case .allow: "In Shortcuts, open TaskWall › Automation and turn on Allow Running When Locked."
            case .test: "Watch your Lock Screen update."
            }
        }

        var action: String {
            switch self {
            case .add: "Add"
            case .allow: "Open"
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
                Toggle("When I Close TaskWall", isOn: Binding(
                    get: { automation.updateWhenAppCloses },
                    set: { model.setAutomation(model.automation.withUpdateWhenAppCloses(on: $0)) }
                ))
            }

            if automation.isSetUp {
                Section {
                    Label("Automation is on. Next update at \(morningText).", image: "refresh")
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
    }

    private var morningText: String {
        Date.at(minutesAfterMidnight: Int(model.automation.morningMinutes)).formatted(date: .omitted, time: .shortened)
    }

    private func currentStep(_ automation: AutomationSettings) -> Step? {
        if !automation.shortcutAdded { return .add }
        if !automation.runsWithoutAsking { return .allow }
        if automation.lastUpdateMillis == nil { return .test }
        return nil
    }

    private func isDone(_ step: Step, _ automation: AutomationSettings) -> Bool {
        switch step {
        case .add: automation.shortcutAdded
        case .allow: automation.runsWithoutAsking
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
        let automation = model.automation
        switch step {
        case .add:
            // Marked as added only once the person confirms, not on the tap.
            addingShortcut = true
        case .allow:
            openURL(ShortcutLinks.openShortcuts)
            model.setAutomation(automation.withRunsWithoutAsking(on: true))
        case .test:
            // The shortcut records its run, then sends us back via taskwall://.
            openURL(ShortcutLinks.runShortcut)
        }
    }
}
