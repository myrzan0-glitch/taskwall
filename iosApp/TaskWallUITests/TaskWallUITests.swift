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
            XCTAssertTrue(app.buttons["New Task"].waitForExistence(timeout: 10), "Today never appeared")
        }
        return app
    }

    /// Taps `element` until `result` shows up. The first tap after launch can be
    /// swallowed while the Liquid Glass bar settles on slower simulators.
    @discardableResult
    private func tap(_ element: XCUIElement, until result: XCUIElement, attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) never appeared")
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
            header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)),
                       withVelocity: .fast, thenHoldForDuration: 0)
            XCTAssertTrue(title.waitForNonExistence(timeout: 3), "the composer closes")
        }
    }

    private func label(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    // MARK: Onboarding

    func testOnboardingAddsAFirstTaskAndFinishes() {
        let app = launch()
        let field = app.textFields["Add a task"]
        XCTAssertTrue(tap(app.buttons["Get started"], until: field))
        field.tap()
        field.typeText("Feed the cat\n")
        XCTAssertTrue(app.staticTexts["Feed the cat"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["Sage theme"].waitForExistence(timeout: 3))
        app.buttons["Sage theme"].tap()
        XCTAssertTrue(app.buttons["Sage theme"].isSelected)
        app.buttons["Continue"].tap()

        let finish = app.buttons["finishSetup"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add"].exists, "the first setup step is open")
        finish.tap()

        XCTAssertTrue(app.buttons["New Task"].waitForExistence(timeout: 5))
        XCTAssertTrue(task(app, "Feed the cat").exists)
    }

    func testOnboardingCanBeSkippedAndGoneBack() {
        let app = launch()
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 3))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["Sage theme"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.textFields["Add a task"].waitForExistence(timeout: 3))
    }

    // MARK: Tasks

    func testAddEditCompleteAndDeleteATask() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 10))

        let title = app.textFields["taskTitle"]
        XCTAssertTrue(tap(app.buttons["New Task"], until: title))
        XCTAssertFalse(app.buttons["saveTask"].exists, "no title, nothing to add")
        title.tap()
        title.typeText("Buy milk")
        XCTAssertTrue(app.buttons["saveTask"].waitForExistence(timeout: 3))
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

        // A long press opens Done, Edit and Delete.
        task(app, "Buy oat milk").press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 3))
    }

    func testClosingTheComposerSavesNothing() {
        let app = launch("-skipOnboarding")
        let title = app.textFields["taskTitle"]
        XCTAssertTrue(tap(app.buttons["New Task"], until: title))
        title.tap()
        title.typeText("Half typed")
        closeComposer(app)
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 3))
        XCTAssertFalse(task(app, "Half typed").exists, "only Add saves a task")
    }

    func testPriorityIsOneRedFlag() {
        let app = launch("-skipOnboarding")
        let title = app.textFields["taskTitle"]
        XCTAssertTrue(tap(app.buttons["New Task"], until: title))
        title.tap()
        title.typeText("Pay the bill")
        let flag = app.buttons["priorityChip"]
        XCTAssertFalse(flag.isSelected)
        flag.tap()
        XCTAssertTrue(flag.isSelected)
        app.buttons["saveTask"].tap()
        XCTAssertTrue(task(app, "Pay the bill").waitForExistence(timeout: 3))
        XCTAssertTrue(rows(app).images["Priority"].firstMatch.exists)
    }

    func testWeekStripShowsAnotherDay() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Buy milk").waitForExistence(timeout: 10))
        XCTAssertTrue(task(app, "Renew passport").exists, "yesterday's open task stays on Today")
        XCTAssertFalse(task(app, "Dentist").exists, "tomorrow's task is not on Today")

        // Pick another day of this week: tomorrow, or yesterday on a Sunday.
        let calendar = Calendar(identifier: .gregorian)
        let isSunday = calendar.component(.weekday, from: Date()) == 1
        let other = calendar.date(byAdding: .day, value: isSunday ? -1 : 1, to: Date())!
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label(other))).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 3))
        day.tap()
        XCTAssertTrue(task(app, isSunday ? "Renew passport" : "Dentist").waitForExistence(timeout: 3))
        XCTAssertFalse(task(app, "Buy milk").exists)
        XCTAssertTrue(day.isSelected)
    }

    func testHideCompleted() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Pay rent").waitForExistence(timeout: 10))
        app.buttons["Hide completed"].tap()
        XCTAssertFalse(task(app, "Pay rent").waitForExistence(timeout: 2))
        XCTAssertTrue(task(app, "Buy milk").exists)
        app.buttons["Show completed"].tap()
        XCTAssertTrue(task(app, "Pay rent").waitForExistence(timeout: 3))
    }

    func testDataSurvivesARelaunch() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Buy milk").waitForExistence(timeout: 10))
        app.terminate()

        let again = XCUIApplication()
        again.launchArguments = ["-uiTesting"]
        again.launch()
        XCTAssertTrue(again.staticTexts["Buy milk"].waitForExistence(timeout: 10))
        XCTAssertTrue(again.buttons["New Task"].exists, "onboarding doesn't come back")
    }

    // MARK: Wallpaper

    func testWallpaperThemesAndLayout() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))

        app.buttons["Sage theme"].tap()
        XCTAssertTrue(app.buttons["Sage theme"].isSelected)
        XCTAssertFalse(app.buttons["Ink theme"].isSelected)

        // The menu's button is named after its current value, so find it by identifier or by "List".
        let layout = app.buttons.matching(NSPredicate(format: "identifier == 'layoutPicker' OR label == 'List'")).firstMatch
        XCTAssertTrue(layout.waitForExistence(timeout: 5))
        layout.tap()
        XCTAssertTrue(app.buttons["Table"].waitForExistence(timeout: 3))
        app.buttons["Table"].tap()
        let table = NSPredicate(format: "label CONTAINS 'Table' OR value CONTAINS 'Table'")
        XCTAssertTrue(app.buttons.matching(table).firstMatch.waitForExistence(timeout: 3))

        XCTAssertTrue(app.buttons["usePhoto"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.buttons["New Task"].waitForExistence(timeout: 3))
    }

    // MARK: Automatic updates

    func testAutomationSetupOpensFromToday() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(tap(app.buttons["setUpAutomation"], until: app.buttons["Add"]))
        XCTAssertTrue(app.buttons["Add"].isEnabled)
        XCTAssertFalse(app.buttons["Set up"].exists, "steps go in order")

        // Add opens the install sheet; nothing is marked done until the person confirms.
        app.buttons["Add"].tap()
        let added = app.buttons["shortcutAdded"]
        XCTAssertTrue(added.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["openShortcutsEditor"].exists || app.buttons["shareShortcut"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 3), "closing without adding keeps step 1 open")

        app.buttons["Add"].tap()
        XCTAssertTrue(added.waitForExistence(timeout: 3))
        added.tap()
        XCTAssertTrue(app.buttons["Set up"].waitForExistence(timeout: 3), "step 2 is next")
        XCTAssertFalse(app.buttons["Add"].exists)

        // Step 2 walks through the automation and is done once confirmed.
        XCTAssertTrue(tap(app.buttons["Set up"], until: app.buttons["automationAdded"]))
        XCTAssertTrue(app.staticTexts["When you close Task on Wallpaper"].exists)
        app.buttons["automationAdded"].tap()
        XCTAssertTrue(app.buttons["Test"].waitForExistence(timeout: 3), "step 3 is next")

        app.buttons["finishSetup"].tap()
        XCTAssertFalse(app.buttons["Test"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["New Task"].exists)
    }

    // MARK: Settings

    func testSettingsAndTipJar() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(tap(app.buttons["Settings"], until: app.navigationBars["Settings"]))

        app.buttons["tipJar"].tap()
        let size = app.buttons["tipSize"]
        XCTAssertTrue(size.waitForExistence(timeout: 5))
        XCTAssertTrue(size.label.hasPrefix("Flat White"))
        size.tap()
        XCTAssertTrue(size.label.hasPrefix("Coffee & Cake"), "tapping the card shows the next size")
        XCTAssertTrue(app.buttons["tipButton"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        XCTAssertTrue(tap(app.buttons["automaticUpdates"], until: app.buttons["Add"]))
        app.buttons["finishSetup"].tap()
        XCTAssertTrue(app.buttons["tipJar"].waitForExistence(timeout: 3), "Done goes back to Settings")
    }
}
