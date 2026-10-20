import SwiftUI

/// Step 2 of automatic updates: the Shortcuts automations that run the TaskWall
/// shortcut on their own. iOS doesn't let apps create automations, so this walks
/// through the few taps in Shortcuts. The close automation is what makes a
/// finished task reach the Lock Screen as soon as the person leaves TaskWall.
struct AutomationGuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let onAdded: () -> Void

    var body: some View {
        let morning = Date.at(minutesAfterMidnight: Int(model.automation.morningMinutes))
            .formatted(date: .omitted, time: .shortened)
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Update when you close TaskWall").font(.title3.bold())
                        Text("Tick off a task, leave TaskWall, and your Lock Screen catches up a moment later. You set this up once in Shortcuts.")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                }

                Section("When you close TaskWall") {
                    step(1, "Tap **Open Shortcuts** below and go to the **Automation** tab.")
                    step(2, "Tap **+** and choose **App**.")
                    step(3, "Choose **TaskWall**, select **Is Closed** and deselect **Is Opened**. Choose **Run Immediately**.")
                    step(4, "Tap **Next** and pick the **TaskWall** shortcut.")
                }

                Section {
                    step(1, "In the **Automation** tab, tap **+** and choose **Time of Day**.")
                    step(2, "Set **\(morning)**, **Daily**, and choose **Run Immediately**.")
                    step(3, "Tap **Next** and pick the **TaskWall** shortcut.")
                } header: {
                    Text("Every morning (optional)")
                } footer: {
                    Text("Keeps the date and overdue tasks right even on days you don't open TaskWall. If iOS asks whether TaskWall can set the wallpaper, choose Always Allow.")
                }
            }
            .navigationTitle("Automations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier("closeAutomationGuide")
                }
            }
            .safeAreaBar(edge: .bottom) {
                VStack(spacing: 8) {
                    Button { openURL(ShortcutLinks.openShortcuts) } label: {
                        Text("Open Shortcuts").frame(maxWidth: .infinity)
                    }
                    .prominentButton()
                    Button("I've Set It Up") {
                        onAdded()
                        dismiss()
                    }
                    .accessibilityIdentifier("automationAdded")
                }
                .controlSize(.large)
                .padding()
            }
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .frame(width: 24, height: 24)
                .background(Circle().strokeBorder(.primary, lineWidth: 1.5))
            Text(text)
        }
        .padding(.vertical, 4)
    }
}
