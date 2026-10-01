import SwiftUI
import SwiftData

/// 태그 하나가 붙은 할 일. 목록과 상관없이 주제로 모아 본다.
struct TagView: View {
    let tag: String
    var focusRequest: Int = 0

    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    private var tasks: [TodoTask] {
        allTasks.filter { !$0.isCompleted && $0.tags.contains(tag) }
    }

    /// 날짜가 있는 것은 날짜 순으로 위에, 없는 것은 아래에.
    private var sections: [TaskSection] {
        let dated = tasks.filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture, $0.order) < ($1.dueDate ?? .distantFuture, $1.order) }
        let undated = tasks.filter { $0.dueDate == nil }
        return [
            TaskSection(id: "dated", title: "날짜 있음", icon: "calendar", tasks: dated),
            TaskSection(id: "undated", title: "날짜 없음", icon: "tray", tasks: undated),
        ]
        .filter { !$0.tasks.isEmpty }
    }

    var body: some View {
        TaskListScreen(
            title: "#\(tag)",
            icon: "number",
            subtitle: "이 태그가 붙은 할 일",
            sections: sections,
            emptyIcon: "number",
            emptyTitle: "이 태그가 붙은 할 일이 없습니다",
            emptyMessage: "할 일에 #\(tag)라고 적으면 여기에 모입니다.",
            inputPlaceholder: "#\(tag) 할 일 추가",
            focusRequest: focusRequest,
            showsDate: true,
            onCreate: { parsed in
                var parsed = parsed
                if !parsed.tags.contains(tag) { parsed.tags.append(tag) }
                return TaskStore(context: context).create(parsed)
            },
            accepts: { !$0.isCompleted && $0.tags.contains(tag) }
        )
    }
}
