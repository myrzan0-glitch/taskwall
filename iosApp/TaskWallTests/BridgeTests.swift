import XCTest
import SwiftUI
import Shared
@testable import TaskWall

/// Conversions between Swift and the shared Kotlin types.
final class BridgeTests: XCTestCase {

    func testCalendarDayRoundTripsThroughDate() {
        let date = Date()
        let day = CalendarDay.from(date)
        let back = Calendar.current.dateComponents([.year, .month, .day], from: day.date())
        XCTAssertEqual(Int32(back.year ?? 0), day.year)
        XCTAssertEqual(Int32(back.month ?? 0), day.month)
        XCTAssertEqual(Int32(back.day ?? 0), day.day)
        XCTAssertEqual(CalendarDay.today, CalendarDay.from(Date()))
    }

    func testMinutesAfterMidnight() {
        XCTAssertEqual(Date.at(minutesAfterMidnight: 90).minutesAfterMidnight, 90)
        XCTAssertEqual(Date.at(minutesAfterMidnight: 23 * 60 + 59).minutesAfterMidnight, 23 * 60 + 59)
        XCTAssertEqual(Date.at(minutesAfterMidnight: 0).minutesAfterMidnight, 0)
    }

    func testMillisRoundTrip() {
        let millis: Int64 = 1_700_000_000_123
        XCTAssertEqual(Date(millis: millis).millis, millis)
    }

    func testKotlinIntWrapsOptionals() {
        XCTAssertNil(kotlinInt(nil))
        XCTAssertEqual(kotlinInt(42)?.int32Value, 42)
    }

    func testTitlesForEnums() {
        XCTAssertEqual(SectionKind.overdue.title, "Overdue")
        XCTAssertEqual(SectionKind.upcoming.title, "Upcoming")
        XCTAssertEqual(Priority.high.title, "High")
        XCTAssertEqual(Priority.noPriority.title, "None")
        XCTAssertEqual(Priority.pickerOrder.count, 4)
    }

    func testLegibilityExplanationNamesTheChoice() {
        let clear = LegibilityResult(tone: .light, backdrop: .clear, whiteContrast: 12, blackContrast: 1.5, meanLuminance: 0.1)
        XCTAssertTrue(clear.explanation.contains("white text with no backdrop"))
        XCTAssertTrue(clear.explanation.contains("12.0:1"))
        let glass = LegibilityResult(tone: .dark, backdrop: .glass, whiteContrast: 2, blackContrast: 2.5, meanLuminance: 0.5)
        XCTAssertTrue(glass.explanation.contains("black text on frosted glass"))
        XCTAssertTrue(glass.explanation.contains("2.5:1"))
    }

    func testShortcutLinksAreWellFormed() {
        let run = ShortcutLinks.runShortcut
        XCTAssertEqual(run.scheme, "shortcuts")
        let items = URLComponents(url: run, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "name" }?.value, "TaskWall")
        XCTAssertEqual(items.first { $0.name == "x-success" }?.value, "taskwall://shortcut-ran")
        XCTAssertEqual(ShortcutLinks.createShortcut.absoluteString, "shortcuts://create-shortcut")
    }

    func testBundledShortcutIsNamedForRunShortcut() {
        // The file is optional; when present, its name is what run-shortcut calls.
        guard let file = ShortcutLinks.bundledFile else { return }
        XCTAssertEqual(file.deletingPathExtension().lastPathComponent, ShortcutLinks.shortcutName)
        XCTAssertGreaterThan((try? Data(contentsOf: file))?.count ?? 0, 0)
    }
}
