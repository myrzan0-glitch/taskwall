import XCTest

/// Settings and Wallist Pro.
final class SettingsUITests: UITestCase {

    func testSettingsAndPro() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(tap(app.buttons["Settings"], until: app.navigationBars["Settings"]))
        XCTAssertFalse(app.buttons["tipJar"].exists, "the tip jar is gone")

        app.buttons["proCard"].tap()
        let plan = app.buttons["proPlan"]
        XCTAssertTrue(plan.appears(within: 5))
        XCTAssertTrue(plan.label.hasPrefix("Yearly"))
        plan.tap()
        XCTAssertTrue(plan.label.hasPrefix("Monthly"), "tapping the card shows the other plan")
        XCTAssertTrue(app.buttons["startPro"].exists)
        XCTAssertTrue(app.buttons["restorePro"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.navigationBars["Settings"].appears(within: 3))

        XCTAssertTrue(tap(app.buttons["automaticUpdates"], until: app.buttons["Add"]))
        app.buttons["finishSetup"].tap()
        XCTAssertTrue(app.buttons["proCard"].appears(within: 3), "Done goes back to Settings")
    }
}
