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

/// The story Read opens, full screen.
struct StoryTarget: Identifiable {
    let read: Read
    var id: String { read.id }
}

/// The card a tap on a task opens: Done, Edit and Delete. Holds the id so it always shows the current task.
struct TaskActionsTarget: Identifiable {
    let id: String
}

/// Today: "My tasks", a week strip, the chosen day's tasks and the day's quote, with
/// Wallpaper (left), a new task (middle) and Settings (right) in the bar at the bottom.
/// Tap a task for Done, Edit and Delete; hold it to drag it to another place.
/// Below the tasks, the first of the Reads peeks in; scroll down and they come one at a time.
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
    // Each change plays its haptic; buttons play theirs through `hapticButtonStyle`.
    @State private var lifts = 0
    @State private var swaps = 0
    @State private var reopened = 0
    @State private var sheet: HomeSheet?
    @State private var story: StoryTarget?
    @State private var todayHeight: CGFloat = 0
    @State private var snap = ReadsSnap.Anchor()
    /// Scrolled past the tasks into Reads, where the bar gives way to a button back up.
    @State private var inReads = false
    /// At the bottom of the tasks or further: from here scrolling settles story by story.
    @State private var atReads = false

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

        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let screen = proxy.size.height + insets.top + insets.bottom
            let layout = ReadsLayout(screen: screen, today: max(todayHeight, screen - ReadsLayout.peek), count: Reads.shared.all.count)

            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: ReadsLayout.gap) {
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
                                    .hapticButtonStyle(.plain)
                                    .padding(.top, 14)
                                }

                                if all.isEmpty {
                                    emptyState(day)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)

                            DailyQuoteView(quote: DailyQuotes.shared.quoteFor(day: model.today))
                                .padding(.top, 28)
                        }
                        .padding(.top, insets.top)
                        // Room for the bar, so the last task never sits under it.
                        .padding(.bottom, 96)
                        .frame(minHeight: screen - ReadsLayout.peek, alignment: .top)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { todayHeight = $0 }
                        .id(Self.top)

                        ForEach(Reads.shared.all, id: \.id) { read in
                            ReadCard(read: read) { story = StoryTarget(read: read) }
                                .frame(height: layout.card)
                                .padding(.horizontal, 6)
                                // Stories either side shrink back and dim as they leave the middle.
                                .scrollTransition(.interactive, axis: .vertical) { card, phase in
                                    card
                                        .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                        .brightness(phase.isIdentity ? 0 : -0.3)
                                }
                        }
                    }
                    .padding(.bottom, (screen - layout.card) / 2)
                    .background(QuickSettle(on: atReads).allowsHitTesting(false))
                }
                .ignoresSafeArea()
                .scrollTargetBehavior(ReadsSnap(layout: layout, anchor: snap))
                .onScrollPhaseChange { _, phase, context in
                    // Kept out of view state: a redraw as scrolling stops jolts the scroll view.
                    guard phase == .idle else { return }
                    let y = context.geometry.contentOffset.y
                    snap.y = y
                    let story = layout.stops.dropFirst().firstIndex { abs($0 - y) < 2 }.map { $0 - 1 } ?? -1
                    if story >= 0 && story != snap.story {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    snap.story = story
                }
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y >= layout.todayRest - 1 } action: { _, reached in
                    atReads = reached
                }
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > layout.todayRest + 60 } action: { _, past in
                    withAnimation(.snappy) { inReads = past }
                }
                .scrollEdgeEffectStyle(.hard, for: .top)
                .overlay(alignment: .bottom) {
                    if inReads {
                        // Low enough to sit on the next story's sliver, clear of Like and Share.
                        backToTasks(reader).padding(.bottom, 8)
                    } else {
                        buttons(day).padding(.bottom, max(insets.bottom - 10, 8))
                    }
                }
            }
        }
        .background(Color.ground.ignoresSafeArea())
        .foregroundStyle(Color.ink)
        .fullScreenCover(item: $story) { ReadArticleView(read: $0.read) }
        .sheet(item: $editor) { TaskEditor(target: $0) }
        .sheet(item: $actions, onDismiss: openEditorAfterActions) { target in
            TaskActionsSheet(taskID: target.id, toggle: toggle) { task in editAfterActions = task }
        }
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

    private static let top = "todayTop"

    /// In Reads: one round button, back up to the tasks.
    private func backToTasks(_ reader: ScrollViewProxy) -> some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.snappy) { reader.scrollTo(Self.top, anchor: .top) }
            } label: {
                Image("arrow-left-01")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .hapticButtonStyle(.plain)
            .glassControl(in: Circle())
            .accessibilityLabel("Back to my tasks")
            .accessibilityIdentifier("backToTasks")
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20)
    }

    private func buttons(_ day: CalendarDay) -> some View {
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
                .hapticButtonStyle(.plain)
                .glassControl(in: Capsule())
                .accessibilityLabel("New Task")
                Spacer()
                barButton("settings-02", label: "Settings") { sheet = .settings }
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 28)
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
        .hapticButtonStyle(.plain)
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

// MARK: - Reads

/// Where Today's pieces sit in the scroll: the tasks, then one card per story.
struct ReadsLayout {
    /// How much of the first story shows under a short list of tasks.
    static let peek: CGFloat = 130
    static let gap: CGFloat = 10

    let screen: CGFloat
    /// Height of the tasks part, at least `screen - peek`.
    let today: CGFloat
    let count: Int

    /// A story nearly fills the screen; the ones either side show a sliver.
    var card: CGFloat { (screen * 0.845).rounded() }

    /// The furthest the tasks scroll on their own: the first story peeking in at the bottom.
    var todayRest: CGFloat { max(0, today - (screen - Self.peek)) }

    /// The scroll offset that centres story `i`.
    func centred(_ i: Int) -> CGFloat {
        today + Self.gap + CGFloat(i) * (card + Self.gap) - (screen - card) / 2
    }

    /// Where scrolling can come to rest below the tasks, top to bottom.
    var stops: [CGFloat] { [todayRest] + (0..<count).map(centred) }
}

/// The tasks scroll freely; below them, scrolling settles one story at a time, centred.
struct ReadsSnap: ScrollTargetBehavior {
    /// Where scrolling last came to rest, so a flick moves one story, not several.
    final class Anchor {
        var y: CGFloat = 0
        /// The story centred there, or -1 among the tasks.
        var story = -1
    }

    let layout: ReadsLayout
    let anchor: Anchor

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let y = target.rect.minY
        let stops = layout.stops
        guard y > layout.todayRest, let start = stops.indices.min(by: { abs(stops[$0] - anchor.y) < abs(stops[$1] - anchor.y) }) else { return }
        let nearest = stops.indices.min { abs(stops[$0] - y) < abs(stops[$1] - y) } ?? start
        target.rect.origin.y = stops[min(max(nearest, start - 1), start + 1)]
    }
}

/// Stories settle the way pages do: a quick snap into place rather than a long glide.
/// SwiftUI has no setting for this, so it reaches the scroll view it sits in; the
/// tasks above keep the normal, longer glide.
private struct QuickSettle: UIViewRepresentable {
    let on: Bool

    func makeUIView(context: Context) -> Finder {
        let view = Finder()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: Finder, context: Context) {
        view.fast = on
    }

    final class Finder: UIView {
        var fast = false { didSet { apply() } }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            scrollView?.decelerationRate = fast ? .fast : .normal
        }

        /// The scroll view this sits inside.
        private var scrollView: UIScrollView? {
            var parent = superview
            while let view = parent {
                if let scroll = view as? UIScrollView { return scroll }
                parent = view.superview
            }
            return nil
        }
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
    @State private var width: CGFloat = 340

    @ViewBuilder
    func body(content: Content) -> some View {
        if task.isDone {
            content
        } else {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onDrag {
                    dragging = task.id
                    lifted()
                    return NSItemProvider(object: task.id as NSString)
                } preview: {
                    // The row itself on a card, full size, rather than the system's shrunken snapshot.
                    content
                        .padding(.horizontal, 12)
                        .frame(width: width + 24)
                        .background(Color.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .environment(\.colorScheme, .dark)
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

/// The day's quote, centred under the tasks. It changes at midnight.
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
        .hapticButtonStyle(.plain)
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
