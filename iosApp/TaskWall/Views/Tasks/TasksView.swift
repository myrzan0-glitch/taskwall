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
                }

                Section {
                    Picker("Show", selection: $filter) {
                        Text("All").tag(TaskFilter.all)
                        Text("Today").tag(TaskFilter.today)
                        Text("Upcoming").tag(TaskFilter.upcoming)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                ForEach(sections, id: \.kind) { section in
                    Section {
                        ForEach(section.tasks, id: \.id) { task in
                            TaskRow(task: task, today: model.today) { model.toggle(task) }
                                .contentShape(Rectangle())
                                .onTapGesture { editor = .edit(task) }
                                .swipeActions {
                                    Button(role: .destructive) { model.delete(task) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text(section.kind.title)
                                .foregroundStyle(section.kind == .overdue ? Color.red : Color.primary)
                            Spacer()
                            Text("\(section.tasks.count)")
                        }
                    }
                }
            }
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing here yet", image: "task-done-01")
                    } description: {
                        Text("Add a task and it shows up on your Lock Screen.")
                    } actions: {
                        Button("New Task") { editor = .new }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .navigationTitle("Today")
            .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear Completed", systemImage: "checkmark.circle.badge.xmark") {
                            model.clearCompleted()
                        }
                    } label: {
                        Image("more-horizontal")
                    }
                    .accessibilityLabel("More")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = .new } label: {
                        Image("add-01")
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityLabel("New Task")
                }
            }
            .sheet(item: $editor) { target in
                TaskEditor(target: target)
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    let today: CalendarDay
    let onToggle: () -> Void

    private var isOverdue: Bool {
        TaskQueries.shared.kindOf(task: task, today: today) == .overdue
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
        .padding(.leading, -12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(task.isDone ? .isSelected : [])
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
    @State private var showSetup = false

    var body: some View {
        let progress = model.progress
        HStack(spacing: 14) {
            LockScreenPreview(width: 46)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    ProgressView(value: progress.fraction)
                        .tint(.primary)
                    Text("\(progress.done)/\(progress.total)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                if !model.automation.isSetUp {
                    Button("Set Up Automatic Updates") { showSetup = true }
                        .buttonStyle(.glass)
                        .controlSize(.small)
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
    }

    private var title: String {
        model.automation.isSetUp ? "Lock Screen is up to date" : "Automatic updates are off"
    }

    private var subtitle: String {
        let time = Date.at(minutesAfterMidnight: Int(model.automation.morningMinutes))
            .formatted(date: .omitted, time: .shortened)
        if model.automation.isSetUp {
            let closing = model.automation.updateWhenAppCloses ? " and when you close TaskWall" : ""
            return "Updates itself at \(time)\(closing)"
        }
        return "Set it up once and your wallpaper keeps itself current."
    }
}
