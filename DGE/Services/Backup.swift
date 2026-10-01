import Foundation
import SwiftData

/// 모델을 그대로 옮겨 담는 값. 백업 파일과 "실행 취소"가 같이 쓴다.
struct TaskSnapshot: Codable {
    var id: UUID
    var title: String
    var notes: String
    var createdAt: Date
    var dueDate: Date?
    var completedAt: Date?
    var isCompleted: Bool
    var listID: UUID?
    var order: Int
    var priority: Int?
    var tags: [String]?
    var checklist: [ChecklistItem]?
    var repeatRule: String?
    var remindAt: Date?

    init(_ task: TodoTask) {
        id = task.id
        title = task.title
        notes = task.notes
        createdAt = task.createdAt
        dueDate = task.dueDate
        completedAt = task.completedAt
        isCompleted = task.isCompleted
        listID = task.listID
        order = task.order
        priority = task.priorityRaw
        tags = task.tags
        checklist = task.checklist
        repeatRule = task.repeatRuleRaw
        remindAt = task.remindAt
    }

    func makeTask() -> TodoTask {
        let task = TodoTask(title: title, notes: notes, dueDate: dueDate, listID: listID, order: order, createdAt: createdAt)
        task.id = id
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.priorityRaw = priority ?? 0
        task.tags = tags ?? []
        task.checklist = checklist ?? []
        task.repeatRuleRaw = repeatRule
        task.remindAt = remindAt
        return task
    }
}

struct ListSnapshot: Codable {
    var id: UUID
    var name: String
    var order: Int

    init(_ list: TaskList) {
        id = list.id
        name = list.name
        order = list.order
    }

    func makeList() -> TaskList {
        let list = TaskList(name: name, order: order)
        list.id = id
        return list
    }
}

struct EventSnapshot: Codable {
    var id: UUID
    var title: String
    var notes: String
    var startDate: Date
    var endDate: Date
    var location: String
    var createdAt: Date
    var isAllDay: Bool?
    var repeatRule: String?
    var alertMinutes: Int?

    init(_ event: CalendarEvent) {
        id = event.id
        title = event.title
        notes = event.notes
        startDate = event.startDate
        endDate = event.endDate
        location = event.location
        createdAt = event.createdAt
        isAllDay = event.isAllDay
        repeatRule = event.repeatRuleRaw
        alertMinutes = event.alertMinutes
    }

    func makeEvent() -> CalendarEvent {
        let event = CalendarEvent(title: title, notes: notes, startDate: startDate, endDate: endDate, location: location)
        event.id = id
        event.createdAt = createdAt
        event.isAllDay = isAllDay ?? false
        event.repeatRuleRaw = repeatRule
        event.alertMinutes = alertMinutes
        return event
    }
}

struct NoteSnapshot: Codable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var scrumDay: Date?

    init(_ note: Note) {
        id = note.id
        title = note.title
        body = note.body
        createdAt = note.createdAt
        updatedAt = note.updatedAt
        isPinned = note.isPinned
        scrumDay = note.scrumDay
    }

    func makeNote() -> Note {
        let note = Note(title: title, body: body, scrumDay: scrumDay)
        note.id = id
        note.createdAt = createdAt
        note.updatedAt = updatedAt
        note.isPinned = isPinned
        return note
    }
}

/// 내보내기 파일 한 개의 내용.
struct BackupFile: Codable {
    var app = "DGE"
    var version = 1
    var exportedAt = Date()
    var lists: [ListSnapshot]
    var tasks: [TaskSnapshot]
    var events: [EventSnapshot]
    /// 메모가 생기기 전의 백업 파일에는 없다.
    var notes: [NoteSnapshot]?
}

/// 백업 파일을 만들고, 받아서 합친다.
@MainActor
struct BackupService {
    let context: ModelContext

    func export() throws -> Data {
        let file = BackupFile(
            lists: try context.fetch(FetchDescriptor<TaskList>()).map(ListSnapshot.init),
            tasks: try context.fetch(FetchDescriptor<TodoTask>()).map(TaskSnapshot.init),
            events: try context.fetch(FetchDescriptor<CalendarEvent>()).map(EventSnapshot.init),
            notes: try context.fetch(FetchDescriptor<Note>()).map(NoteSnapshot.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    /// 이미 있는 것(같은 id)은 건드리지 않고, 없는 것만 더한다. 더한 개수를 돌려준다.
    func merge(_ data: Data) throws -> (lists: Int, tasks: Int, events: Int, notes: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)

        let listIDs = Set(try context.fetch(FetchDescriptor<TaskList>()).map(\.id))
        let taskIDs = Set(try context.fetch(FetchDescriptor<TodoTask>()).map(\.id))
        let eventIDs = Set(try context.fetch(FetchDescriptor<CalendarEvent>()).map(\.id))
        let noteIDs = Set(try context.fetch(FetchDescriptor<Note>()).map(\.id))

        let newLists = file.lists.filter { !listIDs.contains($0.id) }
        let newTasks = file.tasks.filter { !taskIDs.contains($0.id) }
        let newEvents = file.events.filter { !eventIDs.contains($0.id) }
        let newNotes = (file.notes ?? []).filter { !noteIDs.contains($0.id) }

        newLists.forEach { context.insert($0.makeList()) }
        newTasks.forEach { context.insert($0.makeTask()) }
        newEvents.forEach { context.insert($0.makeEvent()) }
        newNotes.forEach { context.insert($0.makeNote()) }
        try context.save()
        return (newLists.count, newTasks.count, newEvents.count, newNotes.count)
    }
}
