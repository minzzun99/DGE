import SwiftUI
import SwiftData

/// 내일부터 날짜를 정해둔 할 일. 날짜별로 묶어 앞으로의 흐름을 본다.
struct UpcomingView: View {
    var focusRequest: Int = 0

    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    /// 날짜가 빠른 순, 같은 날이면 사용자가 정한 순서.
    private var tasks: [TodoTask] {
        allTasks
            .filter(Self.includes)
            .sorted { ($0.dueDate ?? .distantFuture, $0.order) < ($1.dueDate ?? .distantFuture, $1.order) }
    }

    static func includes(_ task: TodoTask) -> Bool {
        !task.isCompleted && task.isUpcoming
    }

    var body: some View {
        TaskListScreen(
            title: "예정",
            icon: "calendar.badge.clock",
            subtitle: "내일부터 날짜를 정해둔 할 일",
            sections: TaskSection.byDay(tasks) { $0.dueDate ?? .distantFuture },
            emptyIcon: "calendar.badge.clock",
            emptyTitle: "앞으로 정해둔 할 일이 없습니다",
            emptyMessage: "할 일을 내일로 미루거나 날짜를 정하면 여기에 모입니다.",
            inputPlaceholder: "내일 할 일 추가",
            focusRequest: focusRequest,
            allowsReordering: true,
            onCreate: { parsed in
                TaskStore(context: context).create(parsed, defaultDueDate: Date.startOfTomorrow)
            },
            accepts: Self.includes
        )
    }
}
