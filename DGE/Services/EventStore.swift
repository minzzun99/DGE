import Foundation
import SwiftData

/// 일정에 대한 쓰기 동작을 모아둔다.
@MainActor
struct EventStore {
    let context: ModelContext

    /// 날짜를 누르면 그날 오전 9시부터 기본 길이(설정)만큼의 일정을 만든다.
    @discardableResult
    func create(on day: Date, title: String = "") -> CalendarEvent {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        return create(at: start, title: title)
    }

    /// 시간 격자에서 누른 시각에 일정을 만든다.
    @discardableResult
    func create(at start: Date, title: String = "") -> CalendarEvent {
        let minutes = UserDefaults.standard.integer(forKey: SettingsKey.defaultEventMinutes)
        let end = Calendar.current.date(byAdding: .minute, value: max(15, minutes), to: start) ?? start

        let event = CalendarEvent(title: title, startDate: start, endDate: end)
        context.insert(event)
        save()
        return event
    }

    /// 시간 격자에서 끌어 놓은 곳으로 옮긴다. 길이는 그대로.
    func move(_ event: CalendarEvent, toStart start: Date) {
        let duration = event.duration
        event.startDate = start
        event.endDate = start.addingTimeInterval(duration)
        event.isAllDay = false
        save()
    }

    /// 하루 종일로 바꾸거나 되돌린다. 되돌릴 때는 그날 오전 9시로 둔다.
    func setAllDay(_ event: CalendarEvent, _ isAllDay: Bool) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: event.startDate)
        event.isAllDay = isAllDay
        if isAllDay {
            event.startDate = day
            event.endDate = day
        } else {
            let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
            event.startDate = start
            event.endDate = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
        }
        save()
    }

    /// 지우기 전에 내용을 남겨 둔다. "실행 취소"로 되살릴 때 쓴다.
    func deleteKeepingSnapshot(_ event: CalendarEvent) -> EventSnapshot {
        let snapshot = EventSnapshot(event)
        delete(event)
        return snapshot
    }

    func restore(_ snapshot: EventSnapshot) {
        context.insert(snapshot.makeEvent())
        save()
    }

    /// 시각은 그대로 두고 날짜만 옮긴다. 여러 날에 걸친 일정은 길이를 유지한다.
    func move(_ event: CalendarEvent, to day: Date) {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: event.startDate)
        let to = calendar.startOfDay(for: day)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        guard days != 0 else { return }

        event.startDate = calendar.date(byAdding: .day, value: days, to: event.startDate) ?? event.startDate
        event.endDate = calendar.date(byAdding: .day, value: days, to: event.endDate) ?? event.endDate
        save()
    }

    func delete(_ event: CalendarEvent) {
        context.delete(event)
        save()
    }

    /// 시작 시간이 종료 시간을 넘어가면 종료를 따라 옮긴다.
    func normalize(_ event: CalendarEvent) {
        if !event.isAllDay, event.endDate < event.startDate {
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate) ?? event.startDate
        }
        save()
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[DGE] 일정 저장 실패: \(error)")
        }
    }
}
