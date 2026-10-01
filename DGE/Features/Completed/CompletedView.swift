import SwiftUI
import SwiftData

/// 끝낸 할 일의 기록. 끝낸 날짜별로 묶고, 체크를 다시 누르면 되돌아간다.
struct CompletedView: View {
    @Query(sort: \TodoTask.completedAt, order: .reverse) private var allTasks: [TodoTask]

    private var tasks: [TodoTask] {
        allTasks.filter { $0.isCompleted }
    }

    /// 이미 끝낸 날짜 순으로 정렬되어 있으므로 그대로 날짜별로 묶는다.
    private var sections: [TaskSection] {
        TaskSection.byDay(tasks) { $0.completedAt ?? $0.createdAt }
    }

    /// "이번 주 12개 · 오늘 3개"
    private var subtitle: String? {
        let calendar = Calendar.dge
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date.startOfToday
        let thisWeek = tasks.filter { ($0.completedAt ?? .distantPast) >= weekStart }.count
        let today = tasks.filter { $0.completedAt.map(Calendar.current.isDateInToday) ?? false }.count
        guard thisWeek > 0 else { return nil }
        return "이번 주 \(thisWeek)개 · 오늘 \(today)개 끝냄"
    }

    var body: some View {
        TaskListScreen(
            title: "완료",
            icon: "checkmark.circle",
            subtitle: subtitle,
            sections: sections,
            emptyIcon: "checkmark.circle",
            emptyTitle: "아직 끝낸 할 일이 없습니다",
            emptyMessage: "체크한 할 일이 날짜별로 여기에 쌓입니다."
        )
    }
}
