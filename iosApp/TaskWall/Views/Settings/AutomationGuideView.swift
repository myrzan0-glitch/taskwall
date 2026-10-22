import SwiftUI

/// Step 2 of automatic updates: the Shortcuts automation that runs the TaskWall
/// shortcut when TaskWall closes, so a finished task reaches the Lock Screen as
/// soon as the person leaves. iOS doesn't let apps create automations, so this
/// walks through the few taps in Shortcuts.
struct AutomationGuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let onAdded: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Update when you close the app").font(.title3.bold())
                        Text("Tick off a task, leave Wallist, and your Lock Screen catches up a moment later. You set this up once in Shortcuts.")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                }

                Section {
                    step(1, "Tap **Open Shortcuts** below and go to the **Automation** tab.")
                    step(2, "Tap **+** and choose **App**.")
                    step(3, "Choose **Wallist**, select **Is Closed** and deselect **Is Opened**. Choose **Run Immediately**.")
                    step(4, "Tap **Next** and pick the **Wallist** shortcut.")
                } header: {
                    Text("When you close Wallist")
                } footer: {
                    Text("If iOS asks whether Wallist can set the wallpaper, choose Always Allow.")
                }
            }
            .navigationTitle("Automation")
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
