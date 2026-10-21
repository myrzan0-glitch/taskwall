import SwiftUI
import UIKit

/// Step 1 of automatic updates: get the TaskWall shortcut into the Shortcuts app.
///
/// With a signed `TaskWall.shortcut` in the app bundle, this offers the file to
/// Shortcuts through the share sheet, which shows Shortcuts' own "Add Shortcut"
/// screen. Without one, it walks through building the two-action shortcut.
struct AddShortcutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let onAdded: () -> Void

    @State private var sharing = false
    @State private var buildByHand = ShortcutLinks.bundledFile == nil

    var body: some View {
        NavigationStack {
            Group {
                if buildByHand {
                    guide
                } else {
                    install
                }
            }
            .navigationTitle("Add the Shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier("closeAddShortcut")
                }
            }
        }
        .sheet(isPresented: $sharing) {
            if let file = ShortcutLinks.bundledFile {
                ShareSheet(items: [file]) { completed in
                    sharing = false
                    if completed { finish() }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: Bundled file

    private var install: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap Add, then choose **Shortcuts**.").font(.title3.bold())
                    Text("Shortcuts opens with the TaskWall shortcut ready. Tap **Add Shortcut** there, then come back.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            }
            Section {
                Button("Build It Myself Instead") { buildByHand = true }
                    .accessibilityIdentifier("buildShortcutByHand")
            } footer: {
                Text("If Shortcuts isn't in the list, scroll the row of apps or tap More.")
            }
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 8) {
                Button { sharing = true } label: {
                    Text("Add").frame(maxWidth: .infinity)
                }
                .prominentButton()
                .accessibilityIdentifier("shareShortcut")
                Button("I've Added It", action: finish)
                    .accessibilityIdentifier("shortcutAdded")
            }
            .controlSize(.large)
            .padding()
        }
    }

    // MARK: Build by hand

    private struct Step: Identifiable {
        let id: Int
        let text: LocalizedStringKey
    }

    private let steps: [Step] = [
        Step(id: 1, text: "Tap **Open Shortcuts** below. A new, empty shortcut opens."),
        Step(id: 2, text: "Tap the name at the top and call it **TaskWall**."),
        Step(id: 3, text: "Search actions for **Task on Wallpaper** and add **Make Wallpaper**."),
        Step(id: 4, text: "Search for **Set Wallpaper Photo**, add it, and choose **Lock Screen**."),
        Step(id: 5, text: "In Set Wallpaper Photo, open its options and turn **Show Preview** off."),
        Step(id: 6, text: "Tap **Done**, then come back to Task on Wallpaper."),
    ]

    private var guide: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Build the shortcut").font(.title3.bold())
                    Text("It takes about a minute. The name has to be exactly TaskWall, because the app runs it by name.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            }
            Section {
                ForEach(steps) { step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(step.id)")
                            .font(.subheadline.bold())
                            .frame(width: 24, height: 24)
                            .background(Circle().strokeBorder(.primary, lineWidth: 1.5))
                        Text(step.text)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 8) {
                Button { openURL(ShortcutLinks.createShortcut) } label: {
                    Text("Open Shortcuts").frame(maxWidth: .infinity)
                }
                .prominentButton()
                .accessibilityIdentifier("openShortcutsEditor")
                Button("I've Added It", action: finish)
                    .accessibilityIdentifier("shortcutAdded")
            }
            .controlSize(.large)
            .padding()
        }
    }

    private func finish() {
        onAdded()
        dismiss()
    }
}

/// The system share sheet. Reports whether the person finished sharing
/// (picked a destination) or cancelled.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
