import SwiftUI
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

/// The long-press card for one task. Holds the id so it always shows the current task.
struct TaskActionsTarget: Identifiable {
    let id: String
}

/// Today: a week strip, then the chosen day's tasks. The bar at the bottom opens
/// Wallpaper (left), a new task (middle) and Settings (right).
struct TasksView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("hideCompleted") private var hideCompleted = false
    @State private var weekOffset = 0
    /// Nil means today, so the screen follows the date past midnight.
    @State private var selected: CalendarDay?
    @State private var editor: TaskEditorTarget?
    @State private var actions: TaskActionsTarget?
    @State private var editAfterActions: TaskItem?
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

        ScrollView {
            VStack(spacing: 0) {
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
                        TaskRow(task: task, today: model.today) { model.toggle(task) }
                            .contentShape(Rectangle())
                            .onTapGesture { editor = .edit(task) }
                            .onLongPressGesture { actions = TaskActionsTarget(id: task.id) }
                            .accessibilityAction(named: "More actions") { actions = TaskActionsTarget(id: task.id) }
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
            TaskActionsSheet(taskID: target.id) { task in editAfterActions = task }
        }
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

    private func openEditorAfterActions() {
        guard let task = editAfterActions else { return }
        editAfterActions = nil
        editor = .edit(task)
    }

    private func bottomBar(_ day: CalendarDay) -> some View {
        GlassEffectContainer(spacing: 24) {
            HStack {
                barButton("wallpaper", label: "Wallpaper") { sheet = .wallpaper }
                Spacer()
                Button { editor = .new(day) } label: {
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
                barButton("settings-02", label: "Settings") { sheet = .settings }
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
                    .font(.body)
                    .foregroundStyle(task.isDone ? Color.muted : Color.ink)
                    .strikethrough(task.isDone, color: Color.muted)
                if isOverdue, let due = task.dueDay {
                    Text("Overdue, \(Formatting.shared.shortDate(day: due))")
                        .font(.footnote)
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
                    .font(.subheadline)
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
