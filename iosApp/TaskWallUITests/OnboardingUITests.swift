import XCTest

/// Onboarding: what to keep in view, first tasks, a look, the reveal, Pro once, skipping and going back.
final class OnboardingUITests: UITestCase {

    func testOnboardingAddsAFirstTaskAndFinishes() {
        let app = launch()
        let work = app.buttons["Work & study"]
        XCTAssertTrue(tap(app.buttons["Get started"], until: work))
        work.tap()
        XCTAssertTrue(work.isSelected)
        app.buttons["Continue"].tap()

        let field = app.textFields["Add a task"]
        XCTAssertTrue(field.appears(within: 3))
        XCTAssertTrue(app.buttons["Add Reply to emails"].exists, "the ideas follow what was picked")
        field.tap()
        field.typeText("Feed the cat\n")
        XCTAssertTrue(app.staticTexts["Feed the cat"].appears(within: 3))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["Signal theme"].appears(within: 3))
        app.buttons["Signal theme"].tap()
        XCTAssertTrue(app.buttons["Signal theme"].isSelected)
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["reveal"].appears(within: 3), "the Lock Screen is shown whole")
        app.buttons["Looks great"].tap()

        let notNow = app.buttons["notNow"]
        XCTAssertTrue(notNow.appears(within: 3), "Pro is offered once")
        XCTAssertEqual(app.staticTexts["proOffer"].label, "Make it yours with Pro")
        XCTAssertTrue(app.buttons["plan-yearly"].isSelected)
        notNow.tap()

        let finish = app.buttons["finishSetup"]
        XCTAssertTrue(finish.appears(within: 3))
        XCTAssertTrue(app.buttons["Add"].exists, "the first setup step is open")
        finish.tap()

        XCTAssertTrue(app.buttons["New Task"].appears(within: 5))
        XCTAssertTrue(task(app, "Feed the cat").exists)
    }

    func testOnboardingCanBeSkippedAndGoneBack() {
        let app = launch()
        XCTAssertTrue(tap(app.buttons["Get started"], until: app.buttons["Work & study"]))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.textFields["Add a task"].appears(within: 3))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["Signal theme"].appears(within: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.textFields["Add a task"].appears(within: 3))
    }

    func testATriedProFontHeadsTheOfferAndIsDroppedOnNotNow() {
        let app = launch()
        XCTAssertTrue(tap(app.buttons["Get started"], until: app.buttons["Work & study"]))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.textFields["Add a task"].appears(within: 3))
        app.buttons["Skip"].tap()

        let grace = app.buttons["font-grace"]
        XCTAssertTrue(grace.appears(within: 3))
        grace.tap()
        XCTAssertTrue(grace.isSelected, "a Pro font can be tried")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Looks great"].appears(within: 3))
        app.buttons["Looks great"].tap()

        XCTAssertTrue(app.buttons["notNow"].appears(within: 3))
        XCTAssertEqual(app.staticTexts["proOffer"].label, "Keep Grace with Pro")
        app.buttons["plan-lifetime"].tap()
        XCTAssertTrue(app.buttons["plan-lifetime"].isSelected)
        XCTAssertEqual(app.buttons["startPro"].label, "Buy Lifetime")
        app.buttons["notNow"].tap()

        XCTAssertTrue(app.buttons["finishSetup"].appears(within: 3))
        app.buttons["finishSetup"].tap()
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))
        XCTAssertTrue(app.buttons["font-classic"].isSelected, "without Pro, the tried font isn't kept")
    }

    func testWithProTheOfferIsSkippedAndTheFontKept() {
        let app = launch("-pro")
        XCTAssertTrue(tap(app.buttons["Get started"], until: app.buttons["Work & study"]))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.textFields["Add a task"].appears(within: 3))
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.buttons["font-grace"].appears(within: 3))
        app.buttons["font-grace"].tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Looks great"].appears(within: 3))
        app.buttons["Looks great"].tap()

        XCTAssertTrue(app.buttons["finishSetup"].appears(within: 3), "no offer with Pro")
        XCTAssertFalse(app.buttons["notNow"].exists)
        app.buttons["finishSetup"].tap()
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))
        XCTAssertTrue(app.buttons["font-grace"].isSelected)
    }
}
