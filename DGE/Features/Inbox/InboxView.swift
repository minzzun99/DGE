import SwiftUI
import SwiftData

/// 아직 언제 할지 정하지 않은 할 일이 모이는 곳.
struct InboxView: View {
    var focusRequest: Int = 0

    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    private var tasks: [TodoTask] {
        allTasks.filter(Self.includes)
    }

    static func includes(_ task: TodoTask) -> Bool {
        !task.isCompleted && task.isInbox && task.listID == nil
    }

    var body: some View {
        TaskListScreen(
            title: "수신함",
            icon: "tray",
            subtitle: "날짜를 정하지 않은 할 일",
            sections: [TaskSection(id: "inbox", tasks: tasks)],
            emptyIcon: "tray",
            emptyTitle: "받아둔 할 일이 없습니다",
            emptyMessage: "떠오르는 일을 일단 여기에 적어두세요.",
            inputPlaceholder: "할 일 적기",
            focusRequest: focusRequest,
            allowsReordering: true,
            onCreate: { parsed in
                TaskStore(context: context).create(parsed)
            },
            accepts: Self.includes
        )
    }
}
