import XCTest

/// Adding, editing, completing and deleting tasks in the composer.
final class TaskEditingUITests: UITestCase {

    func testAddEditCompleteAndDeleteATask() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(app.staticTexts["Nothing here yet"].appears(within: 10))

        let title = app.textFields["taskTitle"]
        XCTAssertTrue(tap(app.buttons["New Task"], until: title))
        XCTAssertFalse(app.buttons["saveTask"].exists, "no title, nothing to add")
        title.tap()
        title.typeText("Buy milk")
        XCTAssertTrue(app.buttons["saveTask"].appears(within: 3))
        app.buttons["saveTask"].tap()
        XCTAssertTrue(task(app, "Buy milk").appears(within: 3))
        XCTAssertFalse(app.staticTexts["Nothing here yet"].exists)

        app.buttons["Mark done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Mark not done"].appears(within: 3))

        // A tap opens Done, Edit and Delete.
        XCTAssertTrue(tap(task(app, "Buy milk"), until: app.buttons["Edit"]))
        app.buttons["Edit"].tap()
        XCTAssertTrue(title.appears(within: 3))
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "milk".count) + "oat milk")
        app.buttons["saveTask"].tap()
        XCTAssertTrue(task(app, "Buy oat milk").appears(within: 3))

        XCTAssertTrue(tap(task(app, "Buy oat milk"), until: app.buttons["Delete"]))
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Nothing here yet"].appears(within: 3))
    }

    func testClosingTheComposerSavesNothing() {
        let app = launch("-skipOnboarding")
        let title = app.textFields["taskTitle"]
        XCTAssertTrue(tap(app.buttons["New Task"], until: title))
        title.tap()
        title.typeText("Half typed")
        closeComposer(app)
        XCTAssertTrue(app.staticTexts["Nothing here yet"].appears(within: 3))
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
        XCTAssertTrue(task(app, "Pay the bill").appears(within: 3))
        XCTAssertTrue(rows(app).images["Priority"].firstMatch.exists)
    }
}
