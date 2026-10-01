import SwiftUI
import SwiftData

/// 하나의 목록에 담긴 할 일.
struct ListView: View {
    let list: TaskList
    var focusRequest: Int = 0

    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    private var tasks: [TodoTask] {
        allTasks.filter { !$0.isCompleted && $0.listID == list.id }
    }

    var body: some View {
        TaskListScreen(
            title: list.name,
            icon: "square.stack",
            sections: [TaskSection(id: "list", tasks: tasks)],
            emptyIcon: "square.stack",
            emptyTitle: "비어 있습니다",
            emptyMessage: "이 목록에 넣을 할 일을 적어보세요.",
            inputPlaceholder: "할 일 적기",
            focusRequest: focusRequest,
            showsDate: true,
            showsList: false,
            allowsReordering: true,
            onCreate: { parsed in
                TaskStore(context: context).create(parsed, defaultListID: list.id)
            },
            accepts: { [listID = list.id] task in !task.isCompleted && task.listID == listID }
        )
    }
}
