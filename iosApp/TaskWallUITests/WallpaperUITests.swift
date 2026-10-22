import XCTest

/// The Wallpaper sheet: themes and layout.
final class WallpaperUITests: UITestCase {

    func testWallpaperThemesAndLayout() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))

        app.buttons["Signal theme"].tap()
        XCTAssertTrue(app.buttons["Signal theme"].isSelected)
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

    func testProFontIsPreviewedUntilUnlocked() {
        let app = launch("-skipOnboarding", "-seed")
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))
        XCTAssertTrue(app.buttons["font-classic"].isSelected)

        // Without Pro, a Pro font only changes the preview and offers Pro.
        app.buttons["font-matrix"].tap()
        XCTAssertTrue(app.buttons["unlockPro"].appears(within: 3))
        XCTAssertFalse(app.buttons["updateNow"].exists)

        app.buttons["unlockPro"].tap()
        XCTAssertTrue(app.buttons["startPro"].appears(within: 5), "the paywall opens")
        XCTAssertTrue(app.buttons["restorePro"].exists)
        pullDownSheet(app)
        XCTAssertTrue(app.buttons["unlockPro"].appears(within: 3), "closing the paywall keeps the preview")

        // Going back to Classic needs nothing.
        app.buttons["font-classic"].tap()
        XCTAssertTrue(app.buttons["updateNow"].appears(within: 3))
        XCTAssertFalse(app.buttons["unlockPro"].exists)
    }

    func testProFontIsKeptWithPro() {
        let app = launch("-skipOnboarding", "-seed", "-pro")
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))

        app.buttons["font-orbit"].tap()
        XCTAssertTrue(app.buttons["font-orbit"].isSelected)
        XCTAssertTrue(app.buttons["updateNow"].exists)
        XCTAssertFalse(app.buttons["unlockPro"].exists)

        // Saved, not just previewed: it's still chosen after the sheet closes and reopens.
        pullDownSheet(app)
        XCTAssertTrue(tap(app.buttons["Wallpaper"], until: app.navigationBars["Wallpaper"]))
        XCTAssertTrue(app.buttons["font-orbit"].isSelected)
    }
}
