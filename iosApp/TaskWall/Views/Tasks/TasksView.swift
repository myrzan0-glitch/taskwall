import SwiftUI
import Shared

enum TaskEditorTarget: Identifiable {
    case new
    case edit(TaskItem)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let task): task.id
        }
    }
}

struct TasksView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: TaskFilter = .all
    @State private var editor: TaskEditorTarget?

    var body: some View {
        let sections = model.sections(filter)
        NavigationStack {
            List {
                Section {
                    LockScreenStatusCard()
                } header: {
                    // A section header, like the ones in Settings.
                    Text("Today · \(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
                }

                Section {
                    Picker("Show", selection: $filter) {
                        Text("All").tag(TaskFilter.all)
                        Text("Today").tag(TaskFilter.today)
                        Text("Upcoming").tag(TaskFilter.upcoming)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    // In a white card, like the other segmented controls.
                }

                // In the list, under the filter: an overlay centred on the whole
                // screen ran into the filter whenever the card above was tall.
                if sections.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                    }
                }

                ForEach(sections, id: \.kind) { section in
                    Section {
                        ForEach(section.tasks, id: \.id) { task in
                            TaskRow(task: task, today: model.today) { model.toggle(task) }
                                .contentShape(Rectangle())
                                .onTapGesture { editor = .edit(task) }
                                .listRowInsets(TaskRow.insets)
                                .swipeActions {
                                    Button(role: .destructive) { model.delete(task) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    // The app-wide tint is white in dark mode, which hid the icon.
                                    .tint(.red)
                                }
                        }
                    } header: {
                        HStack {
                            Text(section.kind.title)
                                .foregroundStyle(section.kind == SectionKind.overdue ? Color.red : Color.primary)
                            Spacer()
                            Text("\(section.tasks.count)")
                        }
                    }
                }
            }
            .listSectionSpacing(.compact)
            .contentBelowLargeTitle()
            .navigationTitle("Tasks")
            // Large title on the same row as the toolbar buttons, as in Wallet.
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                // Adjacent items share one glass capsule.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        SearchView()
                    } label: {
                        Image("search-01")
                    }
                    .accessibilityLabel("Search")
                    Menu {
                        Button("Clear Completed", systemImage: "checkmark.circle.badge.xmark") {
                            model.clearCompleted()
                        }
                    } label: {
                        Image("more-horizontal")
                    }
                    .accessibilityLabel("More")
                }
            }
            .sheet(item: $editor) { target in
                TaskEditor(target: target)
            }
        }
    }
}

private extension TasksView {
    /// Says why the list is empty: no tasks at all, or none for this filter.
    @ViewBuilder var emptyState: some View {
        if model.state.tasks.isEmpty {
            ContentUnavailableView {
                Label("Nothing here yet", image: "task-done-01")
            } description: {
                Text("Add a task and it shows up on your Lock Screen.")
            } actions: {
                Button("New Task") { editor = .new }
                    .prominentButton()
            }
        } else if filter == TaskFilter.upcoming {
            ContentUnavailableView {
                Label("Nothing upcoming", image: "calendar-03")
            } description: {
                Text("Tasks due after today show up here.")
            }
        } else {
            ContentUnavailableView {
                Label("Nothing for today", image: "task-done-01")
            } description: {
                Text("Your other tasks are under Upcoming.")
            }
        }
    }
}

struct TaskRow: View {
    /// The check button's 44 pt hit area brings the circle back to the usual 16 pt margin.
    static let insets = EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 16)

    let task: TaskItem
    let today: CalendarDay
    let onToggle: () -> Void

    private var isOverdue: Bool {
        TaskQueries.shared.kindOf(task: task, today: today) == SectionKind.overdue
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                CheckCircle(done: task.isDone)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                if let label = Formatting.shared.dueLabel(task: task, today: today) {
                    Text(label)
                        .font(.footnote)
                        .foregroundStyle(isOverdue && !task.isDone ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                }
            }
            Spacer(minLength: 8)
            PriorityBadge(priority: task.priority)
        }
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
                Circle().fill(.primary)
                Image("tick-02")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 15, height: 15)
                    .foregroundStyle(Color(.systemBackground))
            } else {
                Circle().strokeBorder(.secondary, lineWidth: 1.5)
            }
        }
        .frame(width: 24, height: 24)
    }
}

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        switch priority {
        case .high:
            badge.foregroundStyle(Color(.systemBackground)).background(Capsule().fill(.primary))
        case .medium:
            badge.foregroundStyle(.primary).background(Capsule().fill(.quaternary))
        case .low:
            badge.foregroundStyle(.secondary).overlay(Capsule().strokeBorder(.tertiary, lineWidth: 1))
        default:
            EmptyView()
        }
    }

    private var badge: some View {
        Text(priority.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
    }
}

/// Top of the Tasks list: what's on the Lock Screen and whether it updates itself.
struct LockScreenStatusCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showSetup = false
    @State private var showGuide = false

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
        let progress = model.progress
        let status = status
        HStack(spacing: 14) {
            LockScreenPreview(width: 46)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(status)).font(.headline)
                    Text(subtitle(status)).font(.footnote).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    ProgressView(value: progress.fraction)
                        .tint(.primary)
                    Text("\(progress.done)/\(progress.total)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                switch status {
                case .notSetUp:
                    Button("Set Up Automatic Updates") { showSetup = true }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .accessibilityIdentifier("setUpAutomation")
                case .outOfDate:
                    HStack(spacing: 8) {
                        Button("Update Now") { openURL(ShortcutLinks.runShortcut) }
                            .prominentButton()
                            .accessibilityIdentifier("updateLockScreen")
                        if !model.automation.automationAdded {
                            Button("Update When I Close") { showGuide = true }
                                .buttonStyle(.glass)
                        }
                    }
                    .controlSize(.small)
                case .upToDate, .updatesOnClose:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showSetup) {
            NavigationStack {
                AutomationSetupView(onFinish: { showSetup = false })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close) { showSetup = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showGuide) {
            AutomationGuideView {
                model.setAutomation(model.automation.withAutomationAdded(added: true))
            }
        }
    }

    private func title(_ status: Status) -> String {
        switch status {
        case .notSetUp: "Automatic updates are off"
        case .upToDate: "Lock Screen is up to date"
        case .updatesOnClose: "Updates when you close TaskWall"
        case .outOfDate: "Lock Screen is out of date"
        }
    }

    private func subtitle(_ status: Status) -> String {
        let time = Date.at(minutesAfterMidnight: Int(model.automation.morningMinutes))
            .formatted(date: .omitted, time: .shortened)
        switch status {
        case .notSetUp: return "Set it up once and your wallpaper keeps itself current."
        case .upToDate:
            return model.automation.updatesWhenClosed
                ? "Updates when you close TaskWall and at \(time)."
                : "Updates itself at \(time)."
        case .updatesOnClose: return "Your latest changes show up as soon as you leave."
        case .outOfDate: return "Your latest changes aren't on it yet."
        }
    }
}
