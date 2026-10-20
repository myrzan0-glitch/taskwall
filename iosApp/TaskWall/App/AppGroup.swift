import Foundation
import Shared

/// TaskWall keeps its data in an App Group container so the app and its
/// shortcuts (which can run while the app is closed) read the same files.
enum AppGroup {
    static let identifier = "group.app.taskwall"

    static var containerURL: URL {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// The shared Kotlin store saves its JSON through this.
final class AppGroupFileStore: NSObject, TextFileStore {
    static let shared = AppGroupFileStore()

    private let url: URL

    init(fileName: String = "taskwall.json") {
        url = AppGroup.containerURL.appendingPathComponent(fileName)
    }

    func read() -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    func write(text: String) {
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Links into the Shortcuts app. iOS only lets Shortcuts set the wallpaper.
enum ShortcutLinks {
    static let shortcutName = "TaskWall"

    /// The published TaskWall shortcut: [Make TaskWall Wallpaper] → [Set Wallpaper].
    /// Replace with the real iCloud link once the shortcut is shared (see docs/shortcut.md).
    static let getShortcut = URL(string: "https://www.icloud.com/shortcuts/REPLACE_WITH_SHORTCUT_ID")!

    static let openShortcuts = URL(string: "shortcuts://")!

    /// Runs the shortcut, then comes back to TaskWall.
    static var runShortcut: URL {
        var components = URLComponents(string: "shortcuts://x-callback-url/run-shortcut")!
        components.queryItems = [
            URLQueryItem(name: "name", value: shortcutName),
            URLQueryItem(name: "x-success", value: "taskwall://shortcut-ran"),
            URLQueryItem(name: "x-error", value: "taskwall://shortcut-failed"),
        ]
        return components.url!
    }
}
