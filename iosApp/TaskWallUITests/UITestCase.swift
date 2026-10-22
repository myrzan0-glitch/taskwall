import XCTest

/// Shared helpers for the UI tests, which walk through every screen the way a person would.
/// The app is launched with `-uiTesting`, which keeps test data apart from real data.
///
/// The tests are split into one class per area because Xcode runs classes, not single
/// tests, side by side on simulator clones (`TEST_WORKERS=2 scripts/test.sh`).
class UITestCase: XCTestCase {

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
    func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "taskRow")
    }

    func task(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        rows(app).staticTexts[title].firstMatch
    }

    func launch(_ flags: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-reset"] + flags
        app.launch()
        if flags.contains("-skipOnboarding") {
            XCTAssertTrue(app.buttons["New Task"].appears(within: 10), "Today never appeared")
        }
        return app
    }

    /// Taps `element` until `result` shows up. The first tap after launch can be
    /// swallowed while the Liquid Glass bar settles on slower simulators.
    @discardableResult
    func tap(_ element: XCUIElement, until result: XCUIElement, attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            XCTAssertTrue(element.appears(within: 10), "\(element) never appeared")
            element.tap()
            if result.appears(within: 4) { return true }
        }
        return false
    }

    /// Sheets have no close button: pull one down from its header, as a person would.
    func pullDownSheet(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
    }

    /// The composer floats over the dimmed list. Tapping above it closes it without saving;
    /// pulling it down by its header does the same.
    func closeComposer(_ app: XCUIApplication) {
        let title = app.textFields["taskTitle"]
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        if !title.vanishes(within: 3) {
            let header = app.staticTexts["New task"].exists ? app.staticTexts["New task"] : app.staticTexts["Edit task"]
            header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)),
                       withVelocity: .fast, thenHoldForDuration: 0)
            XCTAssertTrue(title.vanishes(within: 3), "the composer closes")
        }
    }

    func label(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

extension XCUIElement {
    /// Like `waitForExistence(timeout:)`, which checks once a second and so takes at least
    /// a second even when the element is already there.
    func appears(within timeout: TimeInterval) -> Bool {
        exists || waitForExistence(timeout: timeout)
    }

    /// Like `waitForNonExistence(timeout:)`, without its one-second wait when the element is already gone.
    func vanishes(within timeout: TimeInterval) -> Bool {
        !exists || waitForNonExistence(timeout: timeout)
    }
}
