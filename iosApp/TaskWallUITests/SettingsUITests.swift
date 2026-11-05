import XCTest

/// Settings and Wallist Pro.
final class SettingsUITests: UITestCase {

    func testSettingsAndPro() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(tap(app.buttons["Settings"], until: app.navigationBars["Settings"]))
        XCTAssertFalse(app.buttons["tipJar"].exists, "the tip jar is gone")

        app.buttons["proCard"].tap()
        let lifetime = app.buttons["plan-lifetime"]
        XCTAssertTrue(lifetime.appears(within: 5))
        XCTAssertTrue(lifetime.isSelected, "Lifetime is chosen first")
        XCTAssertFalse(app.buttons["plan-yearly"].exists, "there's no yearly plan")
        app.buttons["plan-monthly"].tap()
        XCTAssertTrue(app.buttons["plan-monthly"].isSelected)
        XCTAssertFalse(lifetime.isSelected)
        XCTAssertFalse(app.buttons["notNow"].exists, "the sheet is pulled down instead")
        XCTAssertTrue(app.buttons["startPro"].exists)
        XCTAssertTrue(app.buttons["restorePro"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.navigationBars["Settings"].appears(within: 3))

        XCTAssertTrue(tap(app.buttons["automaticUpdates"], until: app.buttons["Add"]))
        app.buttons["finishSetup"].tap()
        XCTAssertTrue(app.buttons["proCard"].appears(within: 3), "Done goes back to Settings")
    }
}
