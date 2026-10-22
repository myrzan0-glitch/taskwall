import XCTest

/// Onboarding: adding first tasks, picking a look, skipping and going back.
final class OnboardingUITests: UITestCase {

    func testOnboardingAddsAFirstTaskAndFinishes() {
        let app = launch()
        let field = app.textFields["Add a task"]
        XCTAssertTrue(tap(app.buttons["Get started"], until: field))
        field.tap()
        field.typeText("Feed the cat\n")
        XCTAssertTrue(app.staticTexts["Feed the cat"].appears(within: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["Signal theme"].appears(within: 3))
        app.buttons["Signal theme"].tap()
        XCTAssertTrue(app.buttons["Signal theme"].isSelected)
        app.buttons["Continue"].tap()

        let finish = app.buttons["finishSetup"]
        XCTAssertTrue(finish.appears(within: 3))
        XCTAssertTrue(app.buttons["Add"].exists, "the first setup step is open")
        finish.tap()

        XCTAssertTrue(app.buttons["New Task"].appears(within: 5))
        XCTAssertTrue(task(app, "Feed the cat").exists)
    }

    func testOnboardingCanBeSkippedAndGoneBack() {
        let app = launch()
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.buttons["Skip"].appears(within: 3))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["Signal theme"].appears(within: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.textFields["Add a task"].appears(within: 3))
    }
}
