import Foundation
import SwiftData

/// DGE의 핵심 모델.
/// Swift Concurrency의 `Task`와 이름이 충돌하므로 `TodoTask`로 둔다.
///
/// 모든 저장 프로퍼티에 기본값을 두어, 이후 필드를 추가해도
/// SwiftData의 가벼운 마이그레이션으로 넘어갈 수 있게 한다.
@Model
final class TodoTask {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    /// 언제 할지 정한 날짜. `nil`이면 Inbox에 머문다.
    var dueDate: Date?
    var completedAt: Date?
    var isCompleted: Bool = false

    /// 소속 리스트. `nil`이면 어떤 리스트에도 속하지 않는다.
    var listID: UUID?

    /// 사용자가 정한 순서. 작을수록 위에 온다.
    var order: Int = 0

    /// `Priority.rawValue`
    var priorityRaw: Int = 0
    var tags: [String] = []
    /// `[ChecklistItem]`을 JSON으로 담아둔다. 모델을 따로 두지 않아 마이그레이션이 단순하다.
    var checklistData: Data?
    /// `RepeatRule.rawValue`. nil이면 반복하지 않는다.
    var repeatRuleRaw: String?
    /// 알림을 줄 시각. nil이면 알리지 않는다.
    var remindAt: Date?
    /// 붙인 사진의 파일 이름. 사진 자체는 `AttachmentStore` 폴더에 일반 파일로 둔다.
    var attachments: [String] = []

    init(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        listID: UUID? = nil,
        order: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.completedAt = nil
        self.isCompleted = false
        self.listID = listID
        self.order = order
    }
}

// MARK: - 저장값을 다루기 쉬운 모양으로

extension TodoTask {
    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var repeatRule: RepeatRule? {
        get { repeatRuleRaw.flatMap(RepeatRule.init(rawValue:)) }
        set { repeatRuleRaw = newValue?.rawValue }
    }

    var checklist: [ChecklistItem] {
        get {
            guard let checklistData else { return [] }
            return (try? JSONDecoder().decode([ChecklistItem].self, from: checklistData)) ?? []
        }
        set {
            checklistData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }

    /// (끝낸 수, 전체 수). 체크리스트가 없으면 nil.
    var checklistProgress: (done: Int, total: Int)? {
        let items = checklist
        guard !items.isEmpty else { return nil }
        return (items.filter(\.isDone).count, items.count)
    }
}

// MARK: - 어느 화면에 속하는지

extension TodoTask {
    /// 날짜가 오늘이거나 지난 할 일. 지난 일도 Today에서 놓치지 않게 함께 보여준다.
    var isDueToday: Bool {
        guard let dueDate else { return false }
        return Calendar.current.startOfDay(for: dueDate) <= Date.startOfToday
    }

    /// 아직 언제 할지 정하지 않은 할 일.
    var isInbox: Bool {
        dueDate == nil
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return Calendar.current.startOfDay(for: dueDate) < Date.startOfToday
    }

    /// 날짜가 정확히 오늘. (`isDueToday`와 달리 지난 일은 빠진다)
    var isScheduledToday: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isScheduledTomorrow: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }

    /// 오늘 이후로 날짜를 정해둔 할 일. '예정'에 모인다.
    var isUpcoming: Bool {
        guard let dueDate else { return false }
        return Calendar.current.startOfDay(for: dueDate) > Date.startOfToday
    }

    /// 목록 · 캘린더에 보여줄 이름. 방금 만들어 제목이 비어 있어도 줄이 사라지지 않게 한다.
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "제목 없음" : title
    }

    /// 검색어가 제목 · 메모 · 태그 · 체크리스트 어디에든 있는지.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        let needle = query.hasPrefix("#") ? String(query.dropFirst()) : query
        return title.localizedCaseInsensitiveContains(needle)
            || notes.localizedCaseInsensitiveContains(needle)
            || tags.contains { $0.localizedCaseInsensitiveContains(needle) }
            || checklist.contains { $0.title.localizedCaseInsensitiveContains(needle) }
    }
}
