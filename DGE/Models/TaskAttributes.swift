import Foundation

/// 할 일의 우선순위. 저장은 숫자(`rawValue`)로 한다.
enum Priority: Int, CaseIterable, Identifiable, Codable, Comparable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "없음"
        case .low: "낮음"
        case .medium: "보통"
        case .high: "높음"
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 반복 규칙. 할 일과 일정이 같이 쓴다. 저장은 문자열(`rawValue`)로 한다.
enum RepeatRule: String, CaseIterable, Identifiable, Codable {
    case daily
    case weekdays
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "매일"
        case .weekdays: "평일마다"
        case .weekly: "매주"
        case .biweekly: "격주"
        case .monthly: "매월"
        case .yearly: "매년"
        }
    }

    /// `date` 다음 차례. 시각은 그대로 둔다.
    func next(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekdays:
            var next = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            while calendar.isDateInWeekend(next) {
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }
            return next
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }

    /// `start`에서 시작한 반복이 `day`에 걸리는지. 날짜 단위로만 본다.
    func matches(_ day: Date, startingFrom start: Date, calendar: Calendar = .current) -> Bool {
        let first = calendar.startOfDay(for: start)
        let target = calendar.startOfDay(for: day)
        guard target >= first else { return false }

        switch self {
        case .daily:
            return true
        case .weekdays:
            return !calendar.isDateInWeekend(target)
        case .weekly:
            return calendar.component(.weekday, from: target) == calendar.component(.weekday, from: first)
        case .biweekly:
            let days = calendar.dateComponents([.day], from: first, to: target).day ?? 0
            return days % 14 == 0
        case .monthly:
            return calendar.component(.day, from: target) == calendar.component(.day, from: first)
        case .yearly:
            return calendar.component(.day, from: target) == calendar.component(.day, from: first)
                && calendar.component(.month, from: target) == calendar.component(.month, from: first)
        }
    }
}

/// 할 일 안의 작은 단계. 할 일 하나에 딸린 목록이라 따로 모델을 두지 않고 함께 저장한다.
struct ChecklistItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
}

/// 일정 알림을 언제 줄지. 시작 몇 분 전인지로 저장한다.
enum EventAlert: Int, CaseIterable, Identifiable {
    case atStart = 0
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30
    case hour = 60
    case day = 1440

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .atStart: "시작할 때"
        case .five: "5분 전"
        case .ten: "10분 전"
        case .fifteen: "15분 전"
        case .thirty: "30분 전"
        case .hour: "1시간 전"
        case .day: "하루 전"
        }
    }
}
