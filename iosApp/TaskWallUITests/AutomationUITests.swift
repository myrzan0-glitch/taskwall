import XCTest

/// Setting up automatic updates from Today, step by step.
final class AutomationUITests: UITestCase {

    func testAutomationSetupOpensFromToday() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(tap(app.buttons["setUpAutomation"], until: app.buttons["Add"]))
        XCTAssertTrue(app.buttons["Add"].isEnabled)
        XCTAssertFalse(app.buttons["Set up"].exists, "steps go in order")

        // Add opens the install sheet; nothing is marked done until the person confirms.
        app.buttons["Add"].tap()
        let added = app.buttons["shortcutAdded"]
        XCTAssertTrue(added.appears(within: 3))
        XCTAssertTrue(app.buttons["openShortcutsEditor"].exists || app.buttons["shareShortcut"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.buttons["Add"].appears(within: 3), "closing without adding keeps step 1 open")

        app.buttons["Add"].tap()
        XCTAssertTrue(added.appears(within: 3))
        added.tap()
        XCTAssertTrue(app.buttons["Set up"].appears(within: 3), "step 2 is next")
        XCTAssertFalse(app.buttons["Add"].exists)

        // Step 2 walks through the automation and is done once confirmed.
        XCTAssertTrue(tap(app.buttons["Set up"], until: app.buttons["automationAdded"]))
        XCTAssertTrue(app.staticTexts["When you close Wallist"].exists)
        app.buttons["automationAdded"].tap()
        XCTAssertTrue(app.buttons["Test"].appears(within: 3), "step 3 is next")

        app.buttons["finishSetup"].tap()
        XCTAssertTrue(app.buttons["Test"].vanishes(within: 2))
        XCTAssertTrue(app.buttons["New Task"].exists)
    }
}
