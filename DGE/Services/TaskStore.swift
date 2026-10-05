import Foundation
import SwiftData

/// 할 일에 대한 모든 쓰기 동작을 한곳에 모아둔다.
/// 뷰는 "무엇을 한다"만 말하고, "어떻게 저장하는지"는 여기서만 안다.
@MainActor
struct TaskStore {
    let context: ModelContext

    // MARK: - 생성

    @discardableResult
    func create(title: String, dueDate: Date? = nil, listID: UUID? = nil) -> TodoTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let task = TodoTask(
            title: trimmed,
            dueDate: dueDate,
            listID: listID,
            order: nextOrder()
        )
        context.insert(task)
        save()
        return task
    }

    /// 입력창에서 읽어낸 할 일을 만든다. 입력에서 말하지 않은 것은 화면의 기본값을 따른다.
    /// (예: '오늘' 화면에서 "보고서"라고만 적으면 오늘, "내일 보고서"라고 적으면 내일)
    @discardableResult
    func create(_ parsed: ParsedTask, defaultDueDate: Date? = nil, defaultListID: UUID? = nil) -> TodoTask? {
        let listID = parsed.listName.flatMap(listID(named:)) ?? defaultListID
        guard let task = create(title: parsed.title, dueDate: parsed.dueDate ?? defaultDueDate, listID: listID) else {
            return nil
        }
        task.tags = parsed.tags
        task.priority = parsed.priority
        task.repeatRule = parsed.repeatRule
        task.remindAt = parsed.remindAt
        save()
        return task
    }

    /// 캘린더에서 날짜를 먼저 고르고 만드는 할 일. 제목은 상세 패널에서 바로 적는다.
    func createDraft(on day: Date) -> TodoTask {
        let task = TodoTask(
            title: "",
            dueDate: Calendar.current.startOfDay(for: day),
            order: nextOrder()
        )
        context.insert(task)
        save()
        return task
    }

    // MARK: - 완료

    func setCompleted(_ task: TodoTask, _ completed: Bool) {
        let wasCompleted = task.isCompleted
        task.isCompleted = completed
        task.completedAt = completed ? Date() : nil
        if completed, !wasCompleted, let rule = task.repeatRule {
            scheduleNext(after: task, rule: rule)
        }
        save()
    }

    /// 끝낸 날을 바꾼다. 체크를 늦게 눌러 '오늘'로 남은 기록을 실제로 한 날로 돌려놓을 때 쓴다.
    /// 시각은 원래 체크한 시각을 유지하고, 앞으로의 시각이 되면 지금으로 맞춘다.
    func setCompletedDate(_ task: TodoTask, _ day: Date) {
        guard task.isCompleted else { return }
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: task.completedAt ?? Date())
        let date = calendar.date(
            bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: time.second ?? 0,
            of: calendar.startOfDay(for: day)
        ) ?? day
        task.completedAt = min(date, Date())
        save()
    }

    /// 반복하는 할 일을 끝내면 다음 차례를 새로 만든다.
    /// 끝낸 것은 기록으로 남기고, 반복은 새 할 일이 이어받는다.
    private func scheduleNext(after task: TodoTask, rule: RepeatRule) {
        let calendar = Calendar.current
        let today = Date.startOfToday
        let base = task.dueDate.map { calendar.startOfDay(for: $0) } ?? today

        // 밀린 반복을 끝냈을 때 지난 날짜로 또 만들지 않도록, 오늘 이후가 될 때까지 넘긴다.
        var next = rule.next(after: base, calendar: calendar)
        while next <= today {
            next = rule.next(after: next, calendar: calendar)
        }

        let copy = TodoTask(
            title: task.title,
            notes: task.notes,
            dueDate: next,
            listID: task.listID,
            order: task.order
        )
        copy.priority = task.priority
        copy.tags = task.tags
        copy.checklist = task.checklist.map { ChecklistItem(title: $0.title) }
        copy.repeatRule = rule
        if let remindAt = task.remindAt {
            // 알림은 같은 시각, 새 날짜로.
            let time = calendar.dateComponents([.hour, .minute], from: remindAt)
            copy.remindAt = calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: next)
        }
        task.repeatRule = nil
        context.insert(copy)
    }

    // MARK: - 날짜

    /// 날짜를 바꾼다. 시각은 버리고 그날의 시작으로 맞춘다. nil이면 날짜를 지운다.
    /// 알림이 걸려 있으면 같은 시각을 유지한 채 새 날짜로 옮긴다.
    func setDueDate(_ task: TodoTask, _ date: Date?) {
        let calendar = Calendar.current
        let newDate = date.map { calendar.startOfDay(for: $0) }
        if let remindAt = task.remindAt, let newDate, let oldDate = task.dueDate,
           !calendar.isDate(oldDate, inSameDayAs: newDate) {
            let time = calendar.dateComponents([.hour, .minute], from: remindAt)
            task.remindAt = calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: newDate)
        }
        task.dueDate = newDate
        save()
    }

    /// 수신함이나 목록에 있던 할 일, 기한이 지난 할 일을 오늘로 가져온다.
    func moveToToday(_ task: TodoTask) {
        setDueDate(task, Date.startOfToday)
    }

    /// 여러 개를 한 번에 오늘로. (기한 지남 → 모두 오늘로)
    func moveToToday(_ tasks: [TodoTask]) {
        tasks.forEach { setDueDate($0, Date.startOfToday) }
    }

    func postponeToTomorrow(_ task: TodoTask) {
        setDueDate(task, Date.startOfTomorrow)
    }

    func postponeToNextWeek(_ task: TodoTask) {
        setDueDate(task, Date.startOfNextWeek)
    }

    // MARK: - 속성

    func setPriority(_ task: TodoTask, _ priority: Priority) {
        task.priority = priority
        save()
    }

    func setList(_ task: TodoTask, _ listID: UUID?) {
        task.listID = listID
        save()
    }

    func addTag(_ task: TodoTask, _ tag: String) {
        let name = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard !name.isEmpty, !task.tags.contains(name) else { return }
        task.tags.append(name)
        save()
    }

    func removeTag(_ task: TodoTask, _ tag: String) {
        task.tags.removeAll { $0 == tag }
        save()
    }

    // MARK: - 지우기

    func delete(_ task: TodoTask) {
        context.delete(task)
        save()
    }

    /// 지우기 전에 내용을 남겨 둔다. "실행 취소"로 되살릴 때 쓴다.
    @discardableResult
    func delete(_ tasks: [TodoTask]) -> [TaskSnapshot] {
        let snapshots = tasks.map(TaskSnapshot.init)
        tasks.forEach { context.delete($0) }
        save()
        return snapshots
    }

    func restore(_ snapshots: [TaskSnapshot]) {
        snapshots.forEach { context.insert($0.makeTask()) }
        save()
    }

    /// 끝낸 지 `days`일이 지난 할 일을 지운다. 지운 개수를 돌려준다.
    @discardableResult
    func deleteCompleted(olderThan days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date.startOfToday) ?? Date.startOfToday
        let all = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
        let old = all.filter { task in
            guard task.isCompleted else { return false }
            return (task.completedAt ?? task.createdAt) < cutoff
        }
        old.forEach { context.delete($0) }
        save()
        return old.count
    }

    // MARK: - 순서

    /// 화면에 보이는 할 일들의 순서를 바꾼다.
    ///
    /// 보이는 할 일들이 쓰고 있던 순서 번호를 그대로 다시 나눠 갖는다.
    /// 그래서 이 화면에 안 보이는 할 일들의 자리는 건드리지 않는다.
    func reorder(_ visible: [TodoTask], from source: IndexSet, to destination: Int) {
        var moved = visible
        moved.move(fromOffsets: source, toOffset: destination)

        let slots = visible.map(\.order).sorted()
        for (index, task) in moved.enumerated() where index < slots.count {
            task.order = slots[index]
        }
        save()
    }

    /// 새 할 일은 목록 맨 아래에 붙인다.
    private func nextOrder() -> Int {
        var descriptor = FetchDescriptor<TodoTask>(
            sortBy: [SortDescriptor(\.order, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let last = (try? context.fetch(descriptor))?.first
        return (last?.order ?? 0) + 1
    }

    private func listID(named name: String) -> UUID? {
        let lists = (try? context.fetch(FetchDescriptor<TaskList>())) ?? []
        return lists.first { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }?.id
    }

    // MARK: - 저장

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[DGE] 저장 실패: \(error)")
        }
    }
}

/// 목록을 만들고, 이름을 바꾸고, 지운다.
@MainActor
struct ListStore {
    let context: ModelContext

    func create(name: String = "새 목록") -> TaskList {
        let lists = (try? context.fetch(FetchDescriptor<TaskList>())) ?? []
        let list = TaskList(name: uniqueName(name, among: lists.map(\.name)), order: (lists.map(\.order).max() ?? -1) + 1)
        context.insert(list)
        save()
        return list
    }

    func rename(_ list: TaskList, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        list.name = trimmed
        save()
    }

    /// 목록을 지워도 할 일은 남긴다. 목록에서만 빠져 수신함이나 날짜 화면으로 돌아간다.
    func delete(_ list: TaskList) {
        let tasks = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
        for task in tasks where task.listID == list.id {
            task.listID = nil
        }
        context.delete(list)
        save()
    }

    func reorder(_ lists: [TaskList], from source: IndexSet, to destination: Int) {
        var moved = lists
        moved.move(fromOffsets: source, toOffset: destination)
        for (index, list) in moved.enumerated() {
            list.order = index
        }
        save()
    }

    private func uniqueName(_ base: String, among names: [String]) -> String {
        guard names.contains(base) else { return base }
        var number = 2
        while names.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[DGE] 목록 저장 실패: \(error)")
        }
    }
}
