import XCTest
import Shared
@testable import TaskWall

/// The app's view of the store, exercised the way the screens use it.
@MainActor
final class AppModelTests: XCTestCase {

    private func makeModel() -> AppModel {
        AppModel(store: TaskWallStore(file: InMemoryTextFileStore(text: nil)))
    }

    func testAddingATaskFromTheEditor() throws {
        let model = makeModel()
        var draft = TaskDraft()
        draft.title = "  Buy milk "
        draft.notes = "Oat"
        draft.priority = Priority.high
        draft.hasDueDate = true
        draft.hasTime = true
        draft.time = Date.at(minutesAfterMidnight: 17 * 60)
        model.add(draft)

        let task = try XCTUnwrap(model.state.tasks.first)
        XCTAssertEqual(task.title, "Buy milk")
        XCTAssertEqual(task.notes, "Oat")
        XCTAssertEqual(task.priority, Priority.high)
        XCTAssertEqual(task.dueDay, CalendarDay.today)
        XCTAssertEqual(task.dueMinutes?.int32Value, 17 * 60)
        XCTAssertEqual(model.progress.total, 1)
        XCTAssertEqual(model.sections(.today).first?.title, "Today")
    }

    func testBlankQuickTaskIsIgnored() {
        let model = makeModel()
        model.addQuickTask("   ")
        model.addQuickTask("\n")
        XCTAssertTrue(model.state.tasks.isEmpty)
        model.addQuickTask(" Water plants ")
        XCTAssertEqual(model.state.tasks.map(\.title), ["Water plants"])
    }

    func testTogglingMarksDoneToday() throws {
        let model = makeModel()
        model.addQuickTask("Call mum")
        let task = try XCTUnwrap(model.state.tasks.first)
        model.toggle(task)
        let done = try XCTUnwrap(model.state.tasks.first)
        XCTAssertTrue(done.isDone)
        XCTAssertEqual(done.completedOn, CalendarDay.today)
        XCTAssertEqual(model.progress.done, 1)
        model.toggle(done)
        XCTAssertFalse(try XCTUnwrap(model.state.tasks.first).isDone)
    }

    func testEditingKeepsTheSameTask() throws {
        let model = makeModel()
        model.addQuickTask("Dentist")
        let task = try XCTUnwrap(model.state.tasks.first)
        var draft = TaskDraft(task: task)
        XCTAssertFalse(draft.hasDueDate)
        draft.title = "Dentist at 9"
        draft.hasDueDate = true
        draft.hasTime = true
        draft.time = Date.at(minutesAfterMidnight: 9 * 60)
        model.update(task, with: draft)

        let edited = try XCTUnwrap(model.state.tasks.first)
        XCTAssertEqual(edited.id, task.id)
        XCTAssertEqual(edited.title, "Dentist at 9")
        XCTAssertEqual(edited.dueMinutes?.int32Value, 9 * 60)
        XCTAssertEqual(model.state.tasks.count, 1)
    }

    func testDeleteAndClearCompleted() throws {
        let model = makeModel()
        model.addQuickTask("A")
        model.addQuickTask("B")
        model.addQuickTask("C")
        let a = try XCTUnwrap(model.state.tasks.first { $0.title == "A" })
        let b = try XCTUnwrap(model.state.tasks.first { $0.title == "B" })
        model.delete(a)
        XCTAssertEqual(model.state.tasks.map(\.title), ["B", "C"])
        model.toggle(b)
        model.clearCompleted()
        XCTAssertEqual(model.state.tasks.map(\.title), ["C"])
    }

    func testSearchReadsTitleAndNotes() {
        let model = makeModel()
        var draft = TaskDraft()
        draft.title = "Buy milk"
        draft.notes = "and eggs"
        model.add(draft)
        model.addQuickTask("Call mum")
        XCTAssertEqual(model.search("EGGS").map(\.title), ["Buy milk"])
        XCTAssertEqual(model.search("m").count, 2)
        XCTAssertTrue(model.search("  ").isEmpty)
    }

    func testDraftRoundTripsThroughATask() throws {
        var draft = TaskDraft()
        draft.title = "Gym"
        draft.hasDueDate = true
        draft.dueDate = Date()
        draft.hasTime = true
        draft.time = Date.at(minutesAfterMidnight: 6 * 60 + 30)
        draft.showOnWallpaper = false

        let model = makeModel()
        model.add(draft)
        let task = try XCTUnwrap(model.state.tasks.first)
        let back = TaskDraft(task: task)
        XCTAssertEqual(back.title, "Gym")
        XCTAssertTrue(back.hasDueDate)
        XCTAssertTrue(back.hasTime)
        XCTAssertEqual(back.time.minutesAfterMidnight, 6 * 60 + 30)
        XCTAssertFalse(back.showOnWallpaper)
        XCTAssertEqual(back.dueDay, CalendarDay.today)
    }

    func testDraftWithoutADateHasNoTime() {
        var draft = TaskDraft()
        draft.hasDueDate = false
        draft.hasTime = true
        XCTAssertNil(draft.dueDay)
        XCTAssertNil(draft.dueMinutes)
        XCTAssertFalse(draft.isValid)
        draft.title = "x"
        XCTAssertTrue(draft.isValid)
    }

    func testStyleChangesShowUpInTheModel() {
        let model = makeModel()
        XCTAssertEqual(model.style.theme, WallpaperTheme.ink)
        model.setStyle(model.style.withTheme(theme: WallpaperTheme.paper).withLayout(layout: WallpaperLayout.table))
        XCTAssertEqual(model.style.theme, WallpaperTheme.paper)
        XCTAssertEqual(model.style.layout, WallpaperLayout.table)
        XCTAssertEqual(model.appearance().tone, TextTone.dark)
        XCTAssertFalse(model.appearance().isPhoto)
        XCTAssertNil(model.photo)
    }

    func testWallpaperContentFollowsTheLayout() {
        let model = makeModel()
        for i in 0..<9 { model.addQuickTask("Task \(i)") }
        XCTAssertEqual(model.wallpaperContent().lines.count, 6)
        let table = model.style.withLayout(layout: WallpaperLayout.table).withShowProgress(show: false)
        XCTAssertEqual(model.wallpaperContent(for: table).lines.count, 8)
    }

    func testAutomationAndTaskSettings() {
        let model = makeModel()
        XCTAssertFalse(model.automation.isSetUp)
        XCTAssertNil(model.lastUpdate)
        model.setAutomation(model.automation.withMorningMinutes(minutes: 8 * 60).withShortcutAdded(added: true))
        XCTAssertEqual(model.automation.morningMinutes, 8 * 60)
        XCTAssertTrue(model.automation.shortcutAdded)
        model.setClearCompletedEachMorning(false)
        XCTAssertFalse(model.settings.clearCompletedEachMorning)
        XCTAssertFalse(model.settings.onboardingComplete)
        model.completeOnboarding()
        XCTAssertTrue(model.settings.onboardingComplete)
    }

    func testFinishingATaskMakesTheLockScreenOutOfDateUntilTheShortcutRuns() throws {
        let file = InMemoryTextFileStore(text: nil)
        let model = AppModel(store: TaskWallStore(file: file))
        model.addQuickTask("Buy milk")
        let shortcut = TaskWallStore(file: file)
        shortcut.recordWallpaperUpdate(nowMillis: Date().millis, today: CalendarDay.today)
        model.becameActive()
        XCTAssertTrue(model.isWallpaperCurrent)

        model.toggle(try XCTUnwrap(model.state.tasks.first))
        XCTAssertFalse(model.isWallpaperCurrent)

        // Leaving the app, then the close automation running the shortcut.
        model.appClosed()
        TaskWallStore(file: file).recordWallpaperUpdate(nowMillis: Date().millis, today: CalendarDay.today)
        model.becameActive()
        XCTAssertTrue(model.isWallpaperCurrent)
        XCTAssertTrue(model.automation.updatesWhenClosed)
    }

    func testShortcutUrlReloadsTheStore() throws {
        let file = InMemoryTextFileStore(text: nil)
        let model = AppModel(store: TaskWallStore(file: file))
        let shortcut = TaskWallStore(file: file)
        shortcut.recordWallpaperUpdate(nowMillis: 1_700_000_000_000, today: CalendarDay.today)
        XCTAssertNil(model.lastUpdate)
        model.handle(try XCTUnwrap(URL(string: "taskwall://shortcut-ran")))
        XCTAssertEqual(model.lastUpdate, Date(millis: 1_700_000_000_000))
        model.handle(try XCTUnwrap(URL(string: "https://example.com")))
    }
}
