import XCTest

/// Captures every screen for design review. The app is dark only.
/// Skipped unless SCREENSHOTS is set; `scripts/test.sh screenshots` sets it and
/// exports the images to `iosApp/build/screenshots`.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] != nil, "Set SCREENSHOTS=1 to capture screens")
        // Keep going if one screen can't be reached, so the rest still get captured.
        continueAfterFailure = true
    }

    private func launch(_ flags: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-reset"] + flags
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        // Let sheets and glass finish settling.
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @discardableResult
    private func tap(_ element: XCUIElement, until result: XCUIElement) -> Bool {
        for _ in 0..<3 {
            guard element.waitForExistence(timeout: 10) else { return false }
            element.tap()
            if result.waitForExistence(timeout: 4) { return true }
        }
        return false
    }

    /// Sheets have no close button: pull one down from its header, as a person would.
    private func pullDownSheet(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
    }

    /// The composer floats over the dimmed list. Tapping above it closes it without saving;
    /// pulling it down by its header does the same.
    private func closeComposer(_ app: XCUIApplication) {
        let title = app.textFields["taskTitle"]
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        if !title.waitForNonExistence(timeout: 3) {
            let header = app.staticTexts["New task"].exists ? app.staticTexts["New task"] : app.staticTexts["Edit task"]
            header.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)),
                         withVelocity: .fast, thenHoldForDuration: 0)
            _ = title.waitForNonExistence(timeout: 3)
        }
    }

    private func row(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "taskRow").staticTexts[title].firstMatch
    }

    func testOnboarding() {
        let app = launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 15))
        snap(app, "01-welcome")

        tap(app.buttons["Get started"], until: app.textFields["Add a task"])
        app.buttons["Add Workout"].firstMatch.tap()
        app.buttons["Add Call mum"].firstMatch.tap()
        snap(app, "02-first-tasks")

        tap(app.buttons["Continue"], until: app.buttons["Choose a photo"])
        snap(app, "03-pick-look")

        tap(app.buttons["Continue"], until: app.buttons["finishSetup"])
        snap(app, "04-automatic-updates")
    }

    func testToday() {
        let empty = launch("-skipOnboarding")
        XCTAssertTrue(empty.buttons["New Task"].waitForExistence(timeout: 15))
        snap(empty, "10-today-empty")
        empty.terminate()

        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(app.buttons["New Task"].waitForExistence(timeout: 15))
        snap(app, "11-today")

        if tap(app.buttons["New Task"], until: app.textFields["taskTitle"]) {
            snap(app, "12-new-task")
            closeComposer(app)
        }

        if tap(row(app, "Buy milk"), until: app.textFields["taskTitle"]) {
            snap(app, "13-edit-task")
            if tap(app.buttons["dateChip"], until: app.datePickers.firstMatch) {
                snap(app, "14-date")
                app.buttons["Done"].firstMatch.tap()
            }
            if tap(app.buttons["timeChip"], until: app.datePickers.firstMatch) {
                snap(app, "15-time")
                app.swipeDown()
            }
            closeComposer(app)
        }

        let overdue = row(app, "Renew passport")
        if overdue.waitForExistence(timeout: 5) {
            overdue.press(forDuration: 0.8)
            if app.buttons["Delete"].waitForExistence(timeout: 4) {
                snap(app, "16-task-actions")
            }
        }
    }

    func testWallpaper() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))
        snap(app, "20-wallpaper")
    }

    func testSettings() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(tap(app.buttons["Settings"], until: app.navigationBars["Settings"]))
        snap(app, "30-settings")

        if tap(app.buttons["tipJar"], until: app.buttons["tipButton"]) {
            snap(app, "31-tip-jar")
            pullDownSheet(app)
        }

        if tap(app.buttons["automaticUpdates"], until: app.buttons["finishSetup"]) {
            snap(app, "32-automatic-updates")
            if tap(app.buttons["Add"], until: app.buttons["shortcutAdded"]) {
                snap(app, "33-add-shortcut")
            }
        }
    }
}
