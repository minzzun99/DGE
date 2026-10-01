import Foundation

/// 캘린더 칸에 들어가는 한 줄. 일정이거나, 할 일이거나, macOS 캘린더의 일정이다.
enum CalendarItem: Identifiable {
    case event(CalendarEvent)
    case task(TodoTask)
    case external(ExternalEvent)

    /// "event:UUID" / "task:UUID". 끌어 옮길 때 주고받는 값으로도 쓴다.
    var id: String {
        switch self {
        case .event(let event): "event:\(event.id.uuidString)"
        case .task(let task): "task:\(task.id.uuidString)"
        case .external(let event): "external:\(event.id)"
        }
    }

    /// 끌어서 놓은 값이 무엇을 가리키는지. (macOS 캘린더 일정은 옮길 수 없다)
    enum Reference {
        case event(UUID)
        case task(UUID)
    }

    static func reference(from payload: String) -> Reference? {
        let parts = payload.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let id = UUID(uuidString: String(parts[1])) else { return nil }
        switch parts[0] {
        case "event": return .event(id)
        case "task": return .task(id)
        default: return nil
        }
    }
}

/// 캘린더에서 고른 것. 오른쪽 패널이 이걸 보고 모양을 정한다.
enum CalendarSelection {
    case event(CalendarEvent)
    case task(TodoTask)
    case external(ExternalEvent)
}
