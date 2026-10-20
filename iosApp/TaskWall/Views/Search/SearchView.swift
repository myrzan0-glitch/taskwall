import SwiftUI
import Shared

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var editor: TaskEditorTarget?
    @FocusState private var searching: Bool

    /// Pushed from the Tasks toolbar, so it lives in that navigation stack.
    var body: some View {
        let results = model.search(query)
        List(results, id: \.id) { task in
            TaskRow(task: task, today: model.today) { model.toggle(task) }
                .contentShape(Rectangle())
                .onTapGesture { editor = .edit(task) }
                .listRowInsets(TaskRow.insets)
        }
        .overlay {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView(
                    "Search Tasks",
                    image: "search-01",
                    description: Text("Find any task by its title or notes.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search tasks")
        .searchFocused($searching)
        .onAppear { searching = true }
        .sheet(item: $editor) { TaskEditor(target: $0) }
    }
}
