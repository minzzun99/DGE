import Foundation
import SwiftData

/// 일정 하나. 제목 · 설명 · 시간 · 위치, 그리고 반복과 알림.
///
/// 할 일(`TodoTask`)과 일부러 분리했다.
/// 할 일은 "끝내는 것"이고 일정은 "그 시간에 있는 것"이라 다루는 방식이 다르다.
@Model
final class CalendarEvent {
    var id: UUID = UUID()
    var title: String = ""
    /// 설명
    var notes: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var location: String = ""
    var createdAt: Date = Date()

    var isAllDay: Bool = false
    /// `RepeatRule.rawValue`. nil이면 반복하지 않는다.
    var repeatRuleRaw: String?
    /// 시작 몇 분 전에 알릴지. nil이면 알리지 않는다. (`EventAlert.rawValue`)
    var alertMinutes: Int?

    init(
        title: String = "",
        notes: String = "",
        startDate: Date,
        endDate: Date,
        location: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.createdAt = Date()
    }
}

extension CalendarEvent {
    var repeatRule: RepeatRule? {
        get { repeatRuleRaw.flatMap(RepeatRule.init(rawValue:)) }
        set { repeatRuleRaw = newValue?.rawValue }
    }

    var alert: EventAlert? {
        get { alertMinutes.flatMap(EventAlert.init(rawValue:)) }
        set { alertMinutes = newValue?.rawValue }
    }

    /// 캘린더 칸에 들어가는 이름. 비어 있어도 칩이 사라지지 않게 한다.
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "제목 없음" : title
    }

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    /// "오후 2:30 – 오후 3:30", 하루 종일이면 "하루 종일"
    var timeRangeText: String {
        if isAllDay { return "하루 종일" }
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return "\(startDate.dgeTimeText) – \(endDate.dgeTimeText)"
        }
        return "\(startDate.dgeShortText) \(startDate.dgeTimeText) – \(endDate.dgeShortText) \(endDate.dgeTimeText)"
    }

    func occurs(on day: Date) -> Bool {
        occurrence(on: day) != nil
    }

    /// 그날에 걸리는 실제 시간. 반복 일정이면 그날 차례의 시간을 계산해 준다.
    func occurrence(on day: Date) -> DateInterval? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

        guard let repeatRule else {
            // 여러 날에 걸친 일정도 해당하는 모든 날에 보이게 한다.
            guard startDate < dayEnd && endDate >= dayStart else { return nil }
            return DateInterval(start: startDate, end: max(startDate, endDate))
        }

        // 반복 일정은 시작하는 날짜 기준으로만 본다. (여러 날짜에 걸친 반복은 첫날에만 보인다)
        guard repeatRule.matches(dayStart, startingFrom: startDate, calendar: calendar) else { return nil }
        let time = calendar.dateComponents([.hour, .minute, .second], from: startDate)
        let start = calendar.date(
            bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: dayStart
        ) ?? dayStart
        return DateInterval(start: start, duration: duration)
    }

    /// 지금 이후 가장 가까운 차례들의 시작 시각. (알림 예약용)
    func upcomingStarts(from now: Date, within days: Int) -> [Date] {
        let calendar = Calendar.current
        guard repeatRule != nil else {
            return startDate > now ? [startDate] : []
        }
        var result: [Date] = []
        var day = calendar.startOfDay(for: max(now, startDate))
        for _ in 0..<days {
            if let interval = occurrence(on: day), interval.start > now {
                result.append(interval.start)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return result
    }

    /// 검색어가 제목 · 위치 · 설명 어디에든 있는지.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(query)
            || location.localizedCaseInsensitiveContains(query)
            || notes.localizedCaseInsensitiveContains(query)
    }
}
