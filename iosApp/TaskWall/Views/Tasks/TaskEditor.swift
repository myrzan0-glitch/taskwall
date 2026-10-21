import SwiftUI
import Shared

/// New Task / Edit Task sheet.
struct TaskEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let target: TaskEditorTarget
    @State private var draft = TaskDraft()
    @State private var original = TaskDraft()
    @State private var confirmDiscard = false
    @FocusState private var titleFocused: Bool

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private var hasChanges: Bool {
        draft.title != original.title || draft.notes != original.notes || draft.priority != original.priority
            || draft.dueDay != original.dueDay || draft.dueMinutes != original.dueMinutes
            || draft.showOnWallpaper != original.showOnWallpaper
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                        .font(.body.weight(.semibold))
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .accessibilityIdentifier("taskTitle")
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("taskNotes")
                }

                Section("Priority") {
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(Priority.pickerOrder, id: \.self) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Toggle("Due Date", isOn: $draft.hasDueDate.animation())
                    if draft.hasDueDate {
                        DatePicker("Date", selection: $draft.dueDate, displayedComponents: .date)
                        Toggle("Time", isOn: $draft.hasTime.animation())
                        if draft.hasTime {
                            DatePicker("Time", selection: $draft.time, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                Section {
                    Toggle("Show on Lock Screen", isOn: $draft.showOnWallpaper)
                } footer: {
                    Text("Your Lock Screen updates the next time the TaskWall shortcut runs.")
                }

                if case .edit(let task) = target {
                    Section {
                        Button("Delete Task", role: .destructive) {
                            model.delete(task)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        if hasChanges { confirmDiscard = true } else { dismiss() }
                    }
                    .accessibilityIdentifier("closeEditor")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { save() }
                        .disabled(!draft.isValid)
                        .accessibilityLabel("Save")
                        .accessibilityIdentifier("saveTask")
                }
            }
            .confirmationDialog("Discard this task?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
        // Styles set at the app root don't reach sheets, so the editor's switches
        // fell back to the system one: a white knob on the white dark-mode tint.
        .toggleStyle(BrandSwitchStyle())
        .presentationDetents([.large])
        .interactiveDismissDisabled(hasChanges)
        .onAppear {
            if case .edit(let task) = target {
                draft = TaskDraft(task: task)
            }
            original = draft
            titleFocused = isNew
        }
    }

    private func save() {
        switch target {
        case .new: model.add(draft)
        case .edit(let task): model.update(task, with: draft)
        }
        dismiss()
    }
}
