import XCTest

/// The Wallpaper sheet: themes and layout.
final class WallpaperUITests: UITestCase {

    func testWallpaperThemesAndLayout() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))

        app.buttons["Sage theme"].tap()
        XCTAssertTrue(app.buttons["Sage theme"].isSelected)
        XCTAssertFalse(app.buttons["Ink theme"].isSelected)

        // The menu's button is named after its current value, so find it by identifier or by "List".
        let layout = app.buttons.matching(NSPredicate(format: "identifier == 'layoutPicker' OR label == 'List'")).firstMatch
        XCTAssertTrue(layout.appears(within: 5))
        layout.tap()
        XCTAssertTrue(app.buttons["Table"].appears(within: 3))
        app.buttons["Table"].tap()
        let table = NSPredicate(format: "label CONTAINS 'Table' OR value CONTAINS 'Table'")
        XCTAssertTrue(app.buttons.matching(table).firstMatch.appears(within: 3))

        XCTAssertTrue(app.buttons["usePhoto"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.buttons["New Task"].appears(within: 3))
    }
}
