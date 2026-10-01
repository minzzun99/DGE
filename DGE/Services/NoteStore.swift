import Foundation
import SwiftData

/// 메모에 대한 쓰기 동작. 데일리 스크럼 메모를 할 일 기록으로 채우는 일도 여기서 한다.
@MainActor
struct NoteStore {
    let context: ModelContext

    // MARK: - 만들기

    @discardableResult
    func create(title: String = "", body: String = "") -> Note {
        let note = Note(title: title, body: body)
        context.insert(note)
        save()
        return note
    }

    /// 그날 데일리 스크럼 메모. 이미 있으면 그것을, 없으면 할 일 기록으로 채워 새로 만든다.
    ///
    /// 아침에 그날 것을 쓸 수도 있고, 퇴근 전에 다음 근무일 것을 미리 준비할 수도 있다.
    /// - Parameter listID: 이 목록의 할 일만 넣는다. nil이면 전부.
    func scrum(for day: Date, listID: UUID?) -> (note: Note, isNew: Bool) {
        let day = Calendar.current.startOfDay(for: day)
        if let existing = existingScrum(for: day) {
            return (existing, false)
        }
        let note = Note(title: Self.scrumTitle(for: day), body: scrumBody(for: day, listID: listID), scrumDay: day)
        context.insert(note)
        save()
        return (note, true)
    }

    func existingScrum(for day: Date) -> Note? {
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        return notes.first { $0.scrumDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false }
    }

    /// 스크럼 날짜를 옮긴다. 제목이 자동으로 붙인 그대로면 새 날짜에 맞춰 바꿔 준다.
    /// 내용은 그대로 두므로, 새 날짜로 모으려면 `refill`을 부른다.
    func setScrumDay(_ note: Note, _ day: Date) {
        let day = Calendar.current.startOfDay(for: day)
        if let old = note.scrumDay, note.title == Self.scrumTitle(for: old) {
            note.title = Self.scrumTitle(for: day)
        }
        note.scrumDay = day
        note.updatedAt = Date()
        save()
    }

    /// 스크럼 메모를 지금 할 일 기록으로 다시 채운다.
    func refill(_ note: Note, listID: UUID?) {
        let day = note.scrumDay ?? Date.startOfToday
        note.body = scrumBody(for: day, listID: listID)
        note.updatedAt = Date()
        save()
    }

    nonisolated static func scrumTitle(for day: Date) -> String {
        "데일리 스크럼 · \(day.formatted(.dateTime.month(.wide).day().weekday(.abbreviated)))"
    }

    /// 어제 한 일 · 오늘 할 일 · 오늘 일정 · 막힌 점.
    ///
    /// "어제"는 지난 근무일이다. 월요일이면 금요일부터 주말까지 끝낸 것을 모은다.
    func scrumBody(for day: Date, listID: UUID?) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: day)
        let previous = Self.previousWorkday(before: today, calendar: calendar)
        let tasks = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        let inScope: (TodoTask) -> Bool = { listID == nil || $0.listID == listID }

        let done = tasks
            .filter { task in
                guard inScope(task), task.isCompleted, let completedAt = task.completedAt else { return false }
                return completedAt >= previous && completedAt < today
            }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }

        let planned = tasks
            .filter { task in
                guard inScope(task), !task.isCompleted, let dueDate = task.dueDate else { return false }
                return calendar.startOfDay(for: dueDate) <= today
            }
            // 밀린 것 먼저, 그다음 우선순위, 같으면 사용자가 정한 순서.
            .sorted { lhs, rhs in
                let lhsOverdue = (lhs.dueDate ?? today) < today
                let rhsOverdue = (rhs.dueDate ?? today) < today
                if lhsOverdue != rhsOverdue { return lhsOverdue }
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.order < rhs.order
            }

        let meetings = events
            .compactMap { event in event.occurrence(on: today).map { (event, $0) } }
            .sorted { lhs, rhs in
                if lhs.0.isAllDay != rhs.0.isAllDay { return lhs.0.isAllDay }
                return lhs.1.start < rhs.1.start
            }

        let yesterdayTitle = calendar.isDate(previous, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today) ?? today)
            ? "어제 한 일"
            : "\(previous.formatted(.dateTime.weekday(.wide))) 이후 한 일"

        var sections: [String] = []
        sections.append(section(yesterdayTitle, done.map(\.displayTitle)))
        sections.append(section("오늘 할 일", planned.map { task in
            let overdue = (task.dueDate.map { calendar.startOfDay(for: $0) } ?? today) < today
            return task.displayTitle + (overdue ? " (밀림)" : "")
        }))
        if !meetings.isEmpty {
            sections.append(section("오늘 일정", meetings.map { event, interval in
                event.isAllDay ? "하루 종일 \(event.displayTitle)" : "\(interval.start.dgeTimeText) \(event.displayTitle)"
            }))
        }
        sections.append(section("막힌 점 · 도움이 필요한 것", []))
        return sections.joined(separator: "\n\n")
    }

    private func section(_ title: String, _ items: [String]) -> String {
        let lines = items.isEmpty ? ["- "] : items.map { "- \($0)" }
        return ([title] + lines).joined(separator: "\n")
    }

    /// 주말을 건너뛴 바로 다음 근무일. (금요일이면 월요일)
    nonisolated static func nextWorkday(after day: Date, calendar: Calendar = .current) -> Date {
        var date = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        while calendar.isDateInWeekend(date) {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return calendar.startOfDay(for: date)
    }

    /// 주말을 건너뛴 바로 전 근무일.
    nonisolated static func previousWorkday(before day: Date, calendar: Calendar = .current) -> Date {
        var date = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        while calendar.isDateInWeekend(date) {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return calendar.startOfDay(for: date)
    }

    // MARK: - 줄을 할 일로

    /// 메모의 줄들을 할 일로 만든다. 글머리표는 떼고, 빈 줄과 제목 줄은 건너뛴다.
    func makeTasks(from lines: [String], smartInput: Bool, listNames: [String]) -> [TodoTask] {
        let store = TaskStore(context: context)
        return lines
            .map(Self.stripBullet)
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parsed = smartInput ? QuickAddParser.parse(line, listNames: listNames) : ParsedTask(title: line)
                return store.create(parsed)
            }
    }

    /// "- ", "• ", "[ ] ", "1. " 같은 글머리를 뗀다.
    nonisolated static func stripBullet(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        for prefix in ["- [ ] ", "- [x] ", "[ ] ", "[x] ", "- ", "• ", "* ", "· "] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
            break
        }
        if let match = text.prefixMatch(of: #/\d{1,2}[.)] /#) {
            text.removeSubrange(match.range)
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 고정 · 지우기

    func togglePin(_ note: Note) {
        note.isPinned.toggle()
        save()
    }

    func delete(_ note: Note) -> NoteSnapshot {
        let snapshot = NoteSnapshot(note)
        context.delete(note)
        save()
        return snapshot
    }

    func restore(_ snapshot: NoteSnapshot) {
        context.insert(snapshot.makeNote())
        save()
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[DGE] 메모 저장 실패: \(error)")
        }
    }
}
