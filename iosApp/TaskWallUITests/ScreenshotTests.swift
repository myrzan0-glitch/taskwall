import XCTest

/// Captures every screen in dark and light mode for design review.
/// Skipped unless SCREENSHOTS is set; `scripts/test.sh screenshots` sets it and
/// exports the images to `iosApp/build/screenshots`.
final class ScreenshotTests: XCTestCase {

    private let appearances = ["dark", "light"]

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] != nil, "Set SCREENSHOTS=1 to capture screens")
        // Keep going if one screen can't be reached, so the rest still get captured.
        continueAfterFailure = true
    }

    private func launch(_ appearance: String, _ flags: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-reset", "-appearance", appearance] + flags
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ appearance: String, _ name: String) {
        // Let sheets and glass finish settling.
        Thread.sleep(forTimeInterval: 1)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(appearance)-\(name)"
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

    private func tab(_ app: XCUIApplication, _ name: String) {
        let button = app.tabBars.buttons[name]
        if button.waitForExistence(timeout: 5) { button.tap() } else { app.buttons[name].firstMatch.tap() }
    }

    func testOnboarding() {
        for look in appearances {
            let app = launch(look)
            XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 15))
            snap(app, look, "01-welcome")

            tap(app.buttons["Get Started"], until: app.textFields["Add a task"])
            app.buttons["Workout"].firstMatch.tap()
            app.buttons["Call mum"].firstMatch.tap()
            snap(app, look, "02-first-tasks")

            tap(app.buttons["Continue"], until: app.staticTexts["Pick a look"])
            snap(app, look, "03-pick-look")

            tap(app.buttons["Continue"], until: app.staticTexts["Make it automatic"])
            snap(app, look, "04-make-it-automatic")
            app.terminate()
        }
    }

    func testTasks() {
        for look in appearances {
            let empty = launch(look, "-skipOnboarding")
            XCTAssertTrue(empty.navigationBars["Today"].waitForExistence(timeout: 15))
            snap(empty, look, "10-tasks-empty")
            empty.terminate()

            let app = launch(look, "-skipOnboarding", "-seed")
            XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 15))
            snap(app, look, "11-tasks")

            if tap(app.buttons["New Task"].firstMatch, until: app.textFields["taskTitle"]) {
                snap(app, look, "12-new-task")
                app.buttons["closeEditor"].tap()
            }

            let row = app.descendants(matching: .any).matching(identifier: "taskRow").staticTexts["Buy milk"].firstMatch
            if tap(row, until: app.textFields["taskTitle"]) {
                snap(app, look, "13-edit-task")
                app.buttons["closeEditor"].tap()
            }

            // Swipe actions and the overdue section.
            let overdue = app.descendants(matching: .any).matching(identifier: "taskRow").staticTexts["Renew passport"].firstMatch
            if overdue.waitForExistence(timeout: 5) {
                overdue.swipeLeft()
                snap(app, look, "15-swipe-delete")
                app.navigationBars.firstMatch.tap()
            }

            app.buttons["Search"].firstMatch.tap()
            let field = app.searchFields.firstMatch
            if field.waitForExistence(timeout: 5) {
                field.tap()
                field.typeText("m")
                snap(app, look, "14-search")
            }
            app.terminate()
        }
    }

    func testWallpaper() {
        for look in appearances {
            let app = launch(look, "-skipOnboarding", "-seed")
            XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 15))
            tab(app, "Wallpaper")
            XCTAssertTrue(app.navigationBars["Wallpaper"].waitForExistence(timeout: 5))
            snap(app, look, "20-wallpaper")

            if tap(app.buttons["Themes"], until: app.navigationBars["Themes"]) {
                snap(app, look, "21-themes")
                app.navigationBars["Themes"].buttons.firstMatch.tap()
            }

            if tap(app.staticTexts["Automatic Updates"].firstMatch, until: app.navigationBars["Automatic Updates"]) {
                snap(app, look, "22-automatic-updates")
            }
            app.terminate()
        }
    }

    func testSettings() {
        for look in appearances {
            let app = launch(look, "-skipOnboarding", "-seed")
            XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 15))
            tab(app, "Settings")
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            snap(app, look, "30-settings")

            if tap(app.buttons["tipJar"], until: app.staticTexts["Keep TaskWall free"]) {
                snap(app, look, "31-tip-jar")
                app.buttons["Close"].firstMatch.tap()
            }

            let setUp = app.buttons["Set Up Automatic Updates"].firstMatch
            if tap(setUp, until: app.staticTexts["Make it automatic"]) {
                snap(app, look, "32-setup")
                if tap(app.buttons["Add"], until: app.buttons["shortcutAdded"]) {
                    snap(app, look, "33-add-shortcut")
                }
            }
            app.terminate()
        }
    }
}
