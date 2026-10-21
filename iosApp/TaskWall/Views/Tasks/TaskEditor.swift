import SwiftUI
import Shared

/// The New Task / Edit Task composer: a title, notes, and three chips for
/// priority, due date and due time. Every task goes on the Lock Screen.
struct TaskEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let target: TaskEditorTarget
    @State private var draft = TaskDraft()
    @State private var pickingDate = false
    @State private var pickingTime = false
    @FocusState private var titleFocused: Bool

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // No close button, as in the design: swipe down or tap outside to close without saving.
            Text(isNew ? "New task" : "Edit task")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Capsule().fill(Color.control))
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Task title", text: $draft.title)
                    .font(.system(size: 24, weight: .medium))
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { if draft.isValid { save() } }
                    .accessibilityIdentifier("taskTitle")
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .accessibilityIdentifier("taskNotes")
            }
            .padding(.top, 16)
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                Button {
                    draft.priority = Priority.flag(!draft.priority.isFlagged)
                } label: {
                    ChipLabel(title: "Priority", icon: "flag-02", iconColor: draft.priority.isFlagged ? .flag : .muted)
                }
                .accessibilityAddTraits(draft.priority.isFlagged ? .isSelected : [])
                .accessibilityIdentifier("priorityChip")

                Button { pickingDate = true } label: {
                    ChipLabel(title: dateLabel, icon: "calendar-03")
                }
                .accessibilityLabel("Due date, \(dateLabel)")
                .accessibilityIdentifier("dateChip")

                Button { pickingTime = true } label: {
                    ChipLabel(title: timeLabel, icon: "clock-01")
                }
                .accessibilityLabel(Text(timeAccessibilityLabel))
                .accessibilityIdentifier("timeChip")
            }
            .buttonStyle(.plain)
            .padding(.top, 28)

            if draft.isValid {
                PrimaryButton(isNew ? LocalizedStringKey("Add") : LocalizedStringKey("Save")) { save() }
                    .accessibilityIdentifier("saveTask")
                    .padding(.top, 12)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .animation(.snappy, value: draft.isValid)
        .fittedSheet()
        .sheet(isPresented: $pickingDate) { DueDateSheet(draft: $draft) }
        .sheet(isPresented: $pickingTime) { DueTimeSheet(draft: $draft) }
        .onAppear {
            switch target {
            case .new(let day):
                draft.dueDate = day.date()
            case .edit(let task):
                draft = TaskDraft(task: task)
            }
            titleFocused = isNew
        }
    }

    private var dateLabel: String {
        guard let day = draft.dueDay else { return "No date" }
        return Formatting.shared.relativeDay(day: day, today: model.today)
    }

    private var timeLabel: String {
        guard draft.dueMinutes != nil else { return "Add time" }
        return Formatting.shared.time(minutesAfterMidnight: Int32(draft.time.minutesAfterMidnight))
    }

    private var timeAccessibilityLabel: String {
        draft.dueMinutes == nil ? "Add time" : "Due time, " + timeLabel
    }

    private func save() {
        switch target {
        case .new: model.add(draft)
        case .edit(let task): model.update(task, with: draft)
        }
        dismiss()
    }
}

/// The calendar that opens from the date chip.
private struct DueDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: TaskDraft

    var body: some View {
        VStack(spacing: 12) {
            DatePicker("Due date", selection: $draft.dueDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(.peach)
                .onChange(of: draft.dueDate) { _, _ in draft.hasDueDate = true }
            HStack(spacing: 8) {
                Button {
                    draft.hasDueDate = false
                    dismiss()
                } label: {
                    Text("No date").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                PrimaryButton("Done") {
                    draft.hasDueDate = true
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .fittedSheet()
    }
}

/// The time wheel that opens from the time chip.
private struct DueTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: TaskDraft

    var body: some View {
        VStack(spacing: 12) {
            Text("Due time")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.muted)
            DatePicker("Due time", selection: $draft.time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
            HStack(spacing: 8) {
                Button {
                    draft.hasTime = false
                    dismiss()
                } label: {
                    Text("No time").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                PrimaryButton("Set time") {
                    // A time needs a day; a task without one becomes due today.
                    draft.hasDueDate = true
                    draft.hasTime = true
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .fittedSheet()
    }
}

/// The long-press card: Done, Edit and Delete for one task.
struct TaskActionsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let taskID: String
    /// Called with the task when the person picks Edit; the editor opens once this closes.
    let onEdit: (TaskItem) -> Void

    var body: some View {
        Group {
            if let task = model.state.tasks.first(where: { $0.id == taskID }) {
                content(task)
            } else {
                Color.clear.frame(height: 1).onAppear { dismiss() }
            }
        }
        .fittedSheet()
    }

    private func content(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 8) {
                    Text(Formatting.shared.dueLabel(task: task, today: model.today) ?? "No date")
                    if task.priority.isFlagged {
                        Text("·").accessibilityHidden(true)
                        Label {
                            Text("Priority")
                        } icon: {
                            Image("flag-02").renderingMode(.template).resizable().frame(width: 14, height: 14)
                        }
                        .foregroundStyle(Color.flag)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color.muted)
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0xC7C7CC))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                tile(task.isDone ? "Undo" : "Done", icon: "checkmark-circle-02") {
                    model.toggle(task)
                    dismiss()
                }
                tile("Edit", icon: "pencil-edit-02") {
                    onEdit(task)
                    dismiss()
                }
                tile("Delete", icon: "delete-02", destructive: true) {
                    model.delete(task)
                    dismiss()
                }
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private func tile(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(icon).renderingMode(.template).resizable().frame(width: 22, height: 22)
                Text(title).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(destructive ? Color(hex: 0xFF7A70) : Color.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(destructive ? Color.flag.opacity(0.16) : Color.control)
            )
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
