import SwiftUI
import SwiftData

/// DGE에서 가장 중심이 되는 화면.
/// 오늘 날짜로 정해둔 할 일과, 기한이 지난 할 일을 나눠서 보여준다.
struct TodayView: View {
    var focusRequest: Int = 0

    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    private var tasks: [TodoTask] {
        allTasks.filter(Self.includes)
    }

    static func includes(_ task: TodoTask) -> Bool {
        !task.isCompleted && task.isDueToday
    }

    /// 지난 일이 있을 때만 묶음을 나눈다. 없으면 제목 없이 한 덩어리.
    private var sections: [TaskSection] {
        let overdue = tasks.filter(\.isOverdue)
        let today = tasks.filter { !$0.isOverdue }
        guard !overdue.isEmpty else {
            return [TaskSection(id: "today", tasks: today)]
        }
        let moveAll = SectionAction(title: "모두 오늘로", icon: "sun.max") {
            withAnimation(DGE.Motion.list) {
                TaskStore(context: context).moveToToday(overdue)
            }
        }
        return [
            TaskSection(id: "overdue", title: "기한 지남", icon: "exclamationmark.circle",
                        tint: DGE.Palette.overdue, tasks: overdue, action: moveAll),
            TaskSection(id: "today", title: "오늘", icon: "sun.max", tasks: today),
        ]
        .filter { !$0.tasks.isEmpty }
    }

    /// 오늘 끝낸 일과 아직 남은 일.
    private var progress: (done: Int, total: Int)? {
        let done = allTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }.count
        let total = done + tasks.count
        return total > 0 ? (done, total) : nil
    }

    var body: some View {
        TaskListScreen(
            title: "오늘",
            icon: "sun.max",
            subtitle: Date().dgeHeaderText,
            sections: sections,
            emptyIcon: "sun.max",
            emptyTitle: "오늘은 비어 있습니다",
            emptyMessage: "위 입력창에 적거나 ⌘N으로 바로 시작하세요.",
            inputPlaceholder: "오늘 할 일 추가",
            focusRequest: focusRequest,
            allowsReordering: true,
            progress: progress,
            onCreate: { parsed in
                TaskStore(context: context).create(parsed, defaultDueDate: Date.startOfToday)
            },
            accepts: Self.includes
        )
    }
}
