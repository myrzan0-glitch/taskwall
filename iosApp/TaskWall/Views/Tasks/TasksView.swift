import SwiftUI
import UniformTypeIdentifiers
import Shared

enum TaskEditorTarget: Identifiable {
    /// A new task, due on the day picked in the week strip.
    case new(CalendarDay)
    case edit(TaskItem)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let task): task.id
        }
    }
}

/// The card a tap on a task opens: Done, Edit and Delete. Holds the id so it always shows the current task.
struct TaskActionsTarget: Identifiable {
    let id: String
}

/// Today: "My tasks", a week strip, then the chosen day's tasks. The bar at the bottom
/// carries the day's quote above Wallpaper (left), a new task (middle) and Settings (right).
/// Tap a task for Done, Edit and Delete; hold it to drag it to another place.
struct TasksView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("hideCompleted") private var hideCompleted = false
    @State private var weekOffset = 0
    /// Nil means today, so the screen follows the date past midnight.
    @State private var selected: CalendarDay?
    @State private var editor: TaskEditorTarget?
    @State private var actions: TaskActionsTarget?
    @State private var editAfterActions: TaskItem?
    /// The task being dragged to a new place.
    @State private var dragging: String?
    // Each change plays its haptic.
    @State private var taps = 0
    @State private var lifts = 0
    @State private var swaps = 0
    @State private var reopened = 0
    @State private var sheet: HomeSheet?

    enum HomeSheet: String, Identifiable {
        case wallpaper, settings, setup
        var id: String { rawValue }
    }

    private var day: CalendarDay { selected ?? model.today }

    var body: some View {
        let day = self.day
        let isToday = day == model.today
        let all = model.tasks(on: day)
        let shown = hideCompleted ? all.filter { !$0.isDone } : all
        let open = shown.filter { !$0.isDone }.map(\.id)

        ScrollView {
            VStack(spacing: 0) {
                Text("My tasks")
                    .font(.system(size: 30, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                WeekStrip(
                    days: model.week(weekOffset),
                    selected: day,
                    today: model.today,
                    hasDot: { model.hasOpenTasks(on: $0) },
                    pick: { selected = $0 == model.today ? nil : $0 },
                    move: moveWeek
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                VStack(spacing: 0) {
                    if isToday {
                        LockScreenStatusRow(
                            openWallpaper: { sheet = .wallpaper },
                            setUp: { sheet = .setup }
                        )
                        DottedDivider()
                    }

                    ForEach(shown, id: \.id) { task in
                        TaskRow(task: task, today: model.today) { toggle(task) }
                            .contentShape(Rectangle())
                            .onTapGesture { actions = TaskActionsTarget(id: task.id) }
                            .accessibilityAction(named: "Edit") { editor = .edit(task) }
                            .modifier(Reorderable(task: task, open: open, dragging: $dragging, lifted: { lifts += 1 }, move: move))
                        DottedDivider()
                    }

                    if all.contains(where: \.isDone) {
                        Button(hideCompleted ? String(localized: "Show completed") : String(localized: "Hide completed")) {
                            withAnimation(.snappy) { hideCompleted.toggle() }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.muted)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule().fill(Color(hex: 0x19191B)))
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                    }

                    if all.isEmpty {
                        emptyState(day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
        .background(Color.ground.ignoresSafeArea())
        .foregroundStyle(Color.ink)
        .safeAreaBar(edge: .bottom) { bottomBar(day) }
        .sheet(item: $editor) { TaskEditor(target: $0) }
        .sheet(item: $actions, onDismiss: openEditorAfterActions) { target in
            TaskActionsSheet(taskID: target.id, toggle: toggle) { task in editAfterActions = task }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .sensoryFeedback(.selection, trigger: day.epochDay)
        .sensoryFeedback(.impact(weight: .medium), trigger: lifts)
        .sensoryFeedback(.selection, trigger: swaps)
        .sensoryFeedback(.impact(weight: .light), trigger: reopened)
        // Ticking a task off, here or from its card: the double tap of a success.
        .sensoryFeedback(.success, trigger: model.state.tasks.filter(\.isDone).count) { old, new in new > old }
        .sheet(item: $sheet) { which in
            switch which {
            case .wallpaper: WallpaperView()
            case .settings: SettingsView()
            case .setup:
                NavigationStack {
                    AutomationSetupView(finishTitle: "Done", onFinish: { sheet = nil })
                }
                .presentationBackground(Color.sheet)
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func moveWeek(_ delta: Int) {
        withAnimation(.snappy) {
            weekOffset += delta
            selected = weekOffset == 0 ? nil : model.week(weekOffset).first
        }
    }

    private func toggle(_ task: TaskItem) {
        if task.isDone { reopened += 1 }
        model.toggle(task)
    }

    /// Drag and drop: the open tasks on screen, in their new order.
    private func move(_ ids: [String]) {
        withAnimation(.snappy) { model.reorder(ids) }
        swaps += 1
    }

    private func openEditorAfterActions() {
        guard let task = editAfterActions else { return }
        editAfterActions = nil
        editor = .edit(task)
    }

    private func bottomBar(_ day: CalendarDay) -> some View {
        VStack(spacing: 16) {
            DailyQuoteView(quote: DailyQuotes.shared.quoteFor(day: model.today))
            buttons(day)
        }
    }

    private func buttons(_ day: CalendarDay) -> some View {
        GlassEffectContainer(spacing: 24) {
            HStack {
                barButton("wallpaper", label: "Wallpaper") {
                    taps += 1
                    sheet = .wallpaper
                }
                Spacer()
                Button {
                    taps += 1
                    editor = .new(day)
                } label: {
                    Image("add-01")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .frame(width: 104, height: 48)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassControl(in: Capsule())
                .accessibilityLabel("New Task")
                Spacer()
                barButton("settings-02", label: "Settings") {
                    taps += 1
                    sheet = .settings
                }
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 28)
        .padding(.top, 4)
    }

    private func barButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 22, height: 22)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassControl(in: Circle())
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func emptyState(_ day: CalendarDay) -> some View {
        let nothingAtAll = model.state.tasks.isEmpty
        VStack(spacing: 6) {
            Image("task-done-01")
                .renderingMode(.template)
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.muted)
            Text(nothingAtAll ? String(localized: "Nothing here yet") : String(localized: "Nothing on \(day.date().formatted(.dateTime.weekday(.wide)))"))
                .font(.body)
                .padding(.top, 6)
            Text(nothingAtAll ? String(localized: "Add a task and it shows up on your Lock Screen.") : String(localized: "Tasks due that day show up here."))
                .font(.footnote)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
        .padding(.horizontal, 24)
    }
}

// MARK: - Drag and drop

/// Hold an open task to lift it, then drag it over another to take that task's place.
/// Finished tasks stay where they are, after the open ones.
private struct Reorderable: ViewModifier {
    let task: TaskItem
    /// The open tasks on screen, in order.
    let open: [String]
    @Binding var dragging: String?
    let lifted: () -> Void
    let move: ([String]) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if task.isDone {
            content
        } else {
            content
                .onDrag {
                    dragging = task.id
                    lifted()
                    return NSItemProvider(object: task.id as NSString)
                }
                .onDrop(of: [.text], delegate: TaskDropDelegate(target: task.id, open: open, dragging: $dragging, move: move))
                .accessibilityAction(named: "Move up") { shift(-1) }
                .accessibilityAction(named: "Move down") { shift(1) }
        }
    }

    private func shift(_ delta: Int) {
        guard let from = open.firstIndex(of: task.id), open.indices.contains(from + delta) else { return }
        var ids = open
        ids.swapAt(from, from + delta)
        move(ids)
    }
}

private struct TaskDropDelegate: DropDelegate {
    let target: String
    let open: [String]
    @Binding var dragging: String?
    let move: ([String]) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = open.firstIndex(of: dragging), let to = open.firstIndex(of: target) else { return }
        var ids = open
        ids.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        move(ids)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

// MARK: - Daily quote

/// The day's quote, centred above the add button. It changes at midnight.
struct DailyQuoteView: View {
    let quote: Quote

    var body: some View {
        VStack(spacing: 6) {
            Text(quote.text)
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0xAEAEB2))
            Text(quote.author.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Color.muted)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 44)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(quote.text) \(quote.author)")
        .accessibilityIdentifier("dailyQuote")
    }
}

// MARK: - Week strip

/// Monday to Sunday. Tap a day to see its tasks; swipe sideways for another week.
struct WeekStrip: View {
    let days: [CalendarDay]
    let selected: CalendarDay
    let today: CalendarDay
    let hasDot: (CalendarDay) -> Bool
    let pick: (CalendarDay) -> Void
    let move: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.epochDay) { day in
                cell(day)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -40 { move(1) } else if value.translation.width > 40 { move(-1) }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Week")
        .accessibilityAction(named: "Next week") { move(1) }
        .accessibilityAction(named: "Previous week") { move(-1) }
        .accessibilityIdentifier("weekStrip")
    }

    private func cell(_ day: CalendarDay) -> some View {
        let isSelected = day == selected
        let isToday = day == today
        let date = day.date()
        return Button { pick(day) } label: {
            VStack(spacing: 3) {
                Text("\(day.day)")
                    .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.ink : Color.muted)
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(isSelected && isToday ? Color.peach : (isSelected ? Color.ink : Color.muted))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.raised : .clear)
            )
            .overlay(alignment: .top) {
                if hasDot(day) && !isSelected {
                    Circle().fill(Color.peach).frame(width: 4, height: 4).padding(.top, 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)) + (isToday ? ", today" : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Rows

struct TaskRow: View {
    let task: TaskItem
    let today: CalendarDay
    let onToggle: () -> Void
    // 20, 17 and 14 pt at the default text size; they grow with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var timeSize: CGFloat = 17
    @ScaledMetric(relativeTo: .footnote) private var overdueSize: CGFloat = 14

    private var isOverdue: Bool {
        !task.isDone && TaskQueries.shared.kindOf(task: task, today: today) == SectionKind.overdue
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                CheckCircle(done: task.isDone)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, -2)
            .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: titleSize))
                    .foregroundStyle(task.isDone ? Color.muted : Color.ink)
                    .strikethrough(task.isDone, color: Color.muted)
                if isOverdue, let due = task.dueDay {
                    Text("Overdue, \(Formatting.shared.shortDate(day: due))")
                        .font(.system(size: overdueSize))
                        .foregroundStyle(Color.flag)
                }
            }
            .padding(.leading, 6)
            .padding(.vertical, 10)

            Spacer(minLength: 8)

            if !task.isDone && task.priority.isFlagged {
                Image("flag-02")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.flag)
                    .padding(.trailing, 10)
                    .accessibilityLabel("Priority")
            }
            if !task.isDone, let minutes = task.dueMinutes {
                Text(Formatting.shared.time(minutesAfterMidnight: minutes.int32Value))
                    .font(.system(size: timeSize))
                    .monospacedDigit()
                    .foregroundStyle(Color.muted)
                    .padding(.trailing, 8)
            }
        }
        .frame(minHeight: 58)
        // Keep the check button its own element so it can be tapped on its own.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("taskRow")
    }
}

struct CheckCircle: View {
    let done: Bool

    var body: some View {
        ZStack {
            if done {
                Circle().fill(Color.ink)
                Image("tick-02")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Color.ground)
            } else {
                Circle().strokeBorder(Color.muted, lineWidth: 1.5)
            }
        }
        .frame(width: 22, height: 22)
        // A little pop as the tick lands.
        .keyframeAnimator(initialValue: 1.0, trigger: done) { circle, scale in
            circle.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(done ? 1.3 : 1.0, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
        }
    }
}

/// The first row of Today: what's on the Lock Screen, and today's progress.
struct LockScreenStatusRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let openWallpaper: () -> Void
    let setUp: () -> Void

    private enum Status {
        case notSetUp, upToDate, updatesOnClose, outOfDate
    }

    private var status: Status {
        let automation = model.automation
        if !automation.isSetUp { return .notSetUp }
        if model.isWallpaperCurrent { return .upToDate }
        return automation.updatesWhenClosed ? .updatesOnClose : .outOfDate
    }

    var body: some View {
        let status = status
        let progress = model.progress
        Button {
            switch status {
            case .notSetUp: setUp()
            case .outOfDate: openURL(ShortcutLinks.runShortcut)
            case .upToDate, .updatesOnClose: openWallpaper()
            }
        } label: {
            HStack(spacing: 12) {
                Image("square-lock-02")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.peach)
                    .frame(width: 24)
                Text(title(status))
                    .font(.body)
                    .foregroundStyle(status == .notSetUp || status == .outOfDate ? Color.ink : Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if progress.total > 0 {
                    Text("\(progress.done) of \(progress.total)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Color.muted)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier(status))
    }

    private func title(_ status: Status) -> String {
        switch status {
        case .notSetUp: "Set up automatic updates"
        case .upToDate: "Lock Screen up to date"
        case .updatesOnClose: "Updates when you close the app"
        case .outOfDate: "Update your Lock Screen"
        }
    }

    private func identifier(_ status: Status) -> String {
        switch status {
        case .notSetUp: "setUpAutomation"
        case .outOfDate: "updateLockScreen"
        case .upToDate, .updatesOnClose: "lockScreenStatus"
        }
    }
}
