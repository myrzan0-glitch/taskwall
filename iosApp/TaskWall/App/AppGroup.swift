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

    /// Deletes the file. Used by the UI tests to start from nothing.
    func reset() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Links into the Shortcuts app. iOS only lets Shortcuts set the wallpaper.
enum ShortcutLinks {
    static let shortcutName = "Wallist"

    /// The signed Wallist shortcut ([Make Wallpaper] → [Set Wallpaper]) shipped
    /// inside the app. Nil until `Resources/Wallist.shortcut` is added (see docs/shortcut.md);
    /// without it, setup shows how to build the shortcut instead.
    static var bundledFile: URL? {
        Bundle.main.url(forResource: shortcutName, withExtension: "shortcut")
    }

    static let openShortcuts = URL(string: "shortcuts://")!

    /// Opens Shortcuts on a new, empty shortcut.
    static let createShortcut = URL(string: "shortcuts://create-shortcut")!

    /// Runs the shortcut, then comes back to the app.
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
