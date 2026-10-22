import XCTest

/// Settings and the tip jar.
final class SettingsUITests: UITestCase {

    func testSettingsAndTipJar() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(tap(app.buttons["Settings"], until: app.navigationBars["Settings"]))

        app.buttons["tipJar"].tap()
        let size = app.buttons["tipSize"]
        XCTAssertTrue(size.appears(within: 5))
        XCTAssertTrue(size.label.hasPrefix("Flat White"))
        size.tap()
        XCTAssertTrue(size.label.hasPrefix("Coffee & Cake"), "tapping the card shows the next size")
        XCTAssertTrue(app.buttons["tipButton"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.navigationBars["Settings"].appears(within: 3))

        XCTAssertTrue(tap(app.buttons["automaticUpdates"], until: app.buttons["Add"]))
        app.buttons["finishSetup"].tap()
        XCTAssertTrue(app.buttons["tipJar"].appears(within: 3), "Done goes back to Settings")
    }
}
