import XCTest

/// Walks through every screen the way a person would.
/// The app is launched with `-uiTesting`, which keeps test data apart from real data.
final class TaskWallUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// On a failure, print the accessibility tree so the CI log shows what the test saw.
    override func tearDown() {
        if let run = testRun, run.failureCount > 0 {
            let lines = XCUIApplication().debugDescription.components(separatedBy: "\n")
            print("HIERARCHY (\(lines.count) lines)\n" + lines.prefix(600).joined(separator: "\n"))
        }
        super.tearDown()
    }

    /// The rows of the task list, as opposed to the same titles drawn in the Lock Screen preview.
    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "taskRow")
    }

    private func task(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        rows(app).staticTexts[title].firstMatch
    }

    private func launch(_ flags: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-reset"] + flags
        app.launch()
        if flags.contains("-skipOnboarding") {
            // Start every test on the Tasks tab, whatever the system restored.
            let tasks = app.navigationBars["Tasks"]
            if !tasks.waitForExistence(timeout: 10) {
                tab(app, "Tasks").tap()
                XCTAssertTrue(tasks.waitForExistence(timeout: 5), "couldn't get to the Tasks tab")
            }
        }
        return app
    }

    /// Taps `element` until `result` shows up. The first tap after launch can be
    /// swallowed while the Liquid Glass toolbar settles on slower simulators.
    @discardableResult
    private func tap(_ element: XCUIElement, until result: XCUIElement, attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) never appeared")
            element.tap()
            if result.waitForExistence(timeout: 4) { return true }
        }
        return false
    }

    private func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[name]
        return inBar.exists ? inBar : app.buttons[name].firstMatch
    }

    // MARK: Onboarding

    func testOnboardingAddsAFirstTaskAndFinishes() {
        let app = launch()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 10))
        app.buttons["Get Started"].tap()

        let field = app.textFields["Add a task"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Feed the cat\n")
        XCTAssertTrue(app.staticTexts["Feed the cat"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Pick a look"].waitForExistence(timeout: 3))
        app.buttons["Table"].tap()
        app.buttons["Sage theme"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Make it automatic"].waitForExistence(timeout: 3))
        app.buttons["Set Up Later"].tap()

        XCTAssertTrue(app.navigationBars["Tasks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Feed the cat"].exists)
    }

    func testOnboardingCanBeSkippedAndGoneBack() {
        let app = launch()
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 3))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.staticTexts["Pick a look"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["What's on today?"].waitForExistence(timeout: 3))
    }

    // MARK: Tasks

    func testAddEditCompleteAndDeleteATask() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 10))

        let title = app.textFields["taskTitle"]
        XCTAssertTrue(tap(app.buttons["New Task"].firstMatch, until: title))
        XCTAssertFalse(app.buttons["saveTask"].isEnabled, "no title, nothing to save")
        title.tap()
        title.typeText("Buy milk")
        app.buttons["saveTask"].tap()
        XCTAssertTrue(task(app, "Buy milk").waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Nothing here yet"].exists)

        app.buttons["Mark done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Mark not done"].waitForExistence(timeout: 3))

        task(app, "Buy milk").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "milk".count) + "oat milk")
        app.buttons["saveTask"].tap()
        XCTAssertTrue(task(app, "Buy oat milk").waitForExistence(timeout: 3))

        task(app, "Buy oat milk").swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 3))
    }

    func testClosingAnEditedTaskAsksFirst() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(app.buttons["New Task"].firstMatch.waitForExistence(timeout: 10))
        let title = app.textFields["taskTitle"]
        XCTAssertTrue(tap(app.buttons["New Task"].firstMatch, until: title))
        title.tap()
        title.typeText("Half typed")
        app.buttons["closeEditor"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 3))
        let keep = app.buttons["Keep Editing"]
        let discard = app.buttons["Discard Changes"]
        if keep.waitForExistence(timeout: 2) {
            keep.tap()
        } else {
            // Anchored to the close button, the dialog has no cancel button: tapping outside keeps editing.
            // Tap above the keyboard (a tap on a key leaves the dialog open), and retry if it stays.
            for _ in 0..<3 where discard.exists {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
                _ = discard.waitForNonExistence(timeout: 2)
            }
        }
        XCTAssertFalse(discard.exists, "the dialog closes and editing goes on")
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        app.buttons["closeEditor"].tap()
        app.buttons["Discard Changes"].tap()
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 3))
    }

    func testDeleteFromTheEditor() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Call mum").waitForExistence(timeout: 10))
        task(app, "Call mum").tap()
        XCTAssertTrue(app.buttons["Delete Task"].waitForExistence(timeout: 3))
        app.buttons["Delete Task"].tap()
        XCTAssertTrue(task(app, "Buy milk").waitForExistence(timeout: 3))
        XCTAssertFalse(task(app, "Call mum").exists)
    }

    func testFilterAndClearCompleted() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Buy milk").waitForExistence(timeout: 10))
        XCTAssertFalse(task(app, "Dentist").exists, "tomorrow's task is not in Today")
        XCTAssertFalse(task(app, "Renew passport").exists, "yesterday's task is not in Today")

        app.buttons["Upcoming"].tap()
        XCTAssertTrue(task(app, "Dentist").waitForExistence(timeout: 3))
        XCTAssertEqual(rows(app).count, 1, "only tomorrow's task is upcoming")
        XCTAssertTrue(app.staticTexts["Tomorrow"].firstMatch.exists, "upcoming tasks are grouped by date")

        app.buttons["Past"].tap()
        XCTAssertTrue(task(app, "Renew passport").waitForExistence(timeout: 3))
        XCTAssertEqual(rows(app).count, 1, "only yesterday's task is in the past")
        XCTAssertTrue(app.staticTexts["Yesterday"].firstMatch.exists, "past tasks are grouped by date")

        app.buttons["Today"].tap()
        XCTAssertTrue(task(app, "Pay rent").waitForExistence(timeout: 3))
        app.buttons["More"].tap()
        app.buttons["Clear Completed"].tap()
        XCTAssertFalse(task(app, "Pay rent").waitForExistence(timeout: 2))
        XCTAssertTrue(task(app, "Buy milk").exists)
    }

    func testDataSurvivesARelaunch() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Buy milk").waitForExistence(timeout: 10))
        app.terminate()

        let again = XCUIApplication()
        again.launchArguments = ["-uiTesting"]
        again.launch()
        XCTAssertTrue(again.staticTexts["Buy milk"].waitForExistence(timeout: 10))
        XCTAssertTrue(again.navigationBars["Tasks"].exists, "onboarding doesn't come back")
    }

    // MARK: Search

    func testSearchFindsTasksByTitle() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Buy milk").waitForExistence(timeout: 10))
        app.buttons["Search"].firstMatch.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("mum")
        XCTAssertTrue(task(app, "Call mum").waitForExistence(timeout: 3))
        XCTAssertEqual(rows(app).count, 1)
        field.typeText("zzz")
        XCTAssertTrue(app.staticTexts["No Results for “mumzzz”"].waitForExistence(timeout: 3))
    }

    // MARK: Wallpaper

    func testWallpaperLayoutAndThemes() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(app.buttons["New Task"].firstMatch.waitForExistence(timeout: 10))
        tab(app, "Wallpaper").tap()
        XCTAssertTrue(app.navigationBars["Wallpaper"].waitForExistence(timeout: 3))

        app.buttons["Table"].tap()
        XCTAssertTrue(app.buttons["Table"].isSelected)

        app.buttons["Themes"].tap()
        XCTAssertTrue(app.navigationBars["Themes"].waitForExistence(timeout: 3))
        app.buttons["Sage theme"].tap()
        XCTAssertTrue(app.buttons["Sage theme"].isSelected)
        app.navigationBars["Themes"].buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Sage"].waitForExistence(timeout: 3))

        app.staticTexts["Automatic Updates"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Automatic Updates"].waitForExistence(timeout: 3))
    }

    // MARK: Automatic updates

    func testAutomationSetupOpensFromTheTasksList() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(app.buttons["setUpAutomation"].waitForExistence(timeout: 10))
        XCTAssertTrue(tap(app.buttons["setUpAutomation"], until: app.staticTexts["Make it automatic"]))
        XCTAssertTrue(app.buttons["Add"].isEnabled)
        XCTAssertFalse(app.buttons["Set Up"].exists, "steps go in order")

        // Add opens the install sheet; nothing is marked done until the person confirms.
        app.buttons["Add"].tap()
        let added = app.buttons["shortcutAdded"]
        XCTAssertTrue(added.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["openShortcutsEditor"].exists || app.buttons["shareShortcut"].exists)
        app.buttons["closeAddShortcut"].tap()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 3), "closing without adding keeps step 1 open")

        app.buttons["Add"].tap()
        XCTAssertTrue(added.waitForExistence(timeout: 3))
        added.tap()
        XCTAssertTrue(app.buttons["Set Up"].waitForExistence(timeout: 3), "step 2 is next")
        XCTAssertFalse(app.buttons["Add"].exists)

        // Step 2 walks through the automations and is done once confirmed.
        XCTAssertTrue(tap(app.buttons["Set Up"], until: app.buttons["automationAdded"]))
        XCTAssertTrue(app.staticTexts["When you close Wallist"].exists)
        app.buttons["automationAdded"].tap()
        XCTAssertTrue(app.buttons["Test"].waitForExistence(timeout: 3), "step 3 is next")

        app.buttons["Set Up Later"].tap()
        XCTAssertFalse(app.staticTexts["Make it automatic"].waitForExistence(timeout: 2))
    }

    // MARK: Settings

    func testSettingsToggleAndTipJar() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(app.buttons["New Task"].firstMatch.waitForExistence(timeout: 10))
        tab(app, "Settings").tap()

        let toggle = app.switches["Clear Completed Each Morning"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        let before = toggle.value as? String
        // The whole row toggles. Tapping the element (not a coordinate) scrolls it
        // out from under the tab bar first.
        toggle.tap()
        let flipped = NSPredicate { _, _ in (toggle.value as? String) != before }
        wait(for: [expectation(for: flipped, evaluatedWith: nil)], timeout: 3)

        app.buttons["tipJar"].tap()
        XCTAssertTrue(app.staticTexts["Keep Wallist free"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Espresso'")).firstMatch.exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }
}
