import XCTest

/// What Today shows: other days, completed tasks, and the same tasks after a relaunch.
final class TaskListUITests: UITestCase {

    func testWeekStripShowsAnotherDay() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Buy milk").appears(within: 10))
        XCTAssertTrue(task(app, "Renew passport").exists, "yesterday's open task stays on Today")
        XCTAssertFalse(task(app, "Dentist").exists, "tomorrow's task is not on Today")

        // Pick another day of this week: tomorrow, or yesterday on a Sunday.
        let calendar = Calendar(identifier: .gregorian)
        let isSunday = calendar.component(.weekday, from: Date()) == 1
        let other = calendar.date(byAdding: .day, value: isSunday ? -1 : 1, to: Date())!
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label(other))).firstMatch
        XCTAssertTrue(day.appears(within: 3))
        day.tap()
        XCTAssertTrue(task(app, isSunday ? "Renew passport" : "Dentist").appears(within: 3))
        XCTAssertFalse(task(app, "Buy milk").exists)
        XCTAssertTrue(day.isSelected)
    }

    func testMyTasksAndTheDailyQuote() {
        let app = launch("-skipOnboarding")
        XCTAssertTrue(app.staticTexts["My tasks"].appears(within: 10))
        let quote = app.descendants(matching: .any)["dailyQuote"]
        XCTAssertTrue(quote.exists, "the day's quote sits under the tasks, above the bar")
        XCTAssertLessThan(quote.frame.maxY, app.buttons["New Task"].frame.minY)
    }

    func testReadsComeOneAtATimeUnderTheTasks() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Buy milk").appears(within: 10))
        app.swipeUp()
        let back = app.buttons["backToTasks"]
        XCTAssertTrue(back.appears(within: 3), "in Reads the bar gives way to a button back up")
        let read = app.buttons["readStory"].firstMatch
        XCTAssertTrue(read.isHittable, "the first story settles in view")

        read.tap()
        let close = app.buttons["closeStory"]
        XCTAssertTrue(close.appears(within: 3))
        close.tap()
        XCTAssertTrue(close.vanishes(within: 3))

        back.tap()
        XCTAssertTrue(app.buttons["New Task"].appears(within: 3))
    }

    func testHideCompleted() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Pay rent").appears(within: 10))
        app.buttons["Hide completed"].tap()
        XCTAssertTrue(task(app, "Pay rent").vanishes(within: 2))
        XCTAssertTrue(task(app, "Buy milk").exists)
        app.buttons["Show completed"].tap()
        XCTAssertTrue(task(app, "Pay rent").appears(within: 3))
    }

    func testDataSurvivesARelaunch() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(task(app, "Buy milk").appears(within: 10))
        app.terminate()

        let again = XCUIApplication()
        again.launchArguments = ["-uiTesting"]
        again.launch()
        XCTAssertTrue(again.staticTexts["Buy milk"].appears(within: 10))
        XCTAssertTrue(again.buttons["New Task"].exists, "onboarding doesn't come back")
    }
}
