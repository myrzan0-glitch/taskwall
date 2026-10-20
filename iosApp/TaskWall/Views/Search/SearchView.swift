import SwiftUI
import Shared

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var editor: TaskEditorTarget?

    var body: some View {
        let results = model.search(query)
        NavigationStack {
            List(results, id: \.id) { task in
                TaskRow(task: task, today: model.today) { model.toggle(task) }
                    .contentShape(Rectangle())
                    .onTapGesture { editor = .edit(task) }
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
            .searchable(text: $query, prompt: "Search tasks")
            .sheet(item: $editor) { TaskEditor(target: $0) }
        }
    }
}
