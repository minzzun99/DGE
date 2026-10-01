import SwiftUI
import EventKit

/// macOS 캘린더 앱의 일정 하나. DGE에서는 읽기만 한다.
struct ExternalEvent: Identifiable, Hashable {
    /// 반복 일정은 차례마다 다른 줄로 보이도록 시작 시각까지 붙인다.
    let id: String
    let eventIdentifier: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String
    let notes: String
    let calendarTitle: String
    let color: Color

    var timeRangeText: String {
        if isAllDay { return "하루 종일" }
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return "\(start.dgeTimeText) – \(end.dgeTimeText)"
        }
        return "\(start.dgeShortText) \(start.dgeTimeText) – \(end.dgeShortText) \(end.dgeTimeText)"
    }

    func occurs(on day: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        // 하루 종일 일정의 끝은 다음날 0시로 오므로 끝나는 순간은 빼고 본다.
        return start < dayEnd && end > dayStart || (start == end && calendar.isDate(start, inSameDayAs: day))
    }
}

/// macOS 캘린더(구글 · iCloud 등 시스템에 연결된 모든 캘린더)의 일정을 가져온다.
///
/// 설정에서 켰을 때만 권한을 묻고, 일정은 읽기만 한다.
@Observable
@MainActor
final class SystemCalendar {
    static let shared = SystemCalendar()

    private let store = EKEventStore()
    private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    /// 캘린더 앱에서 무언가 바뀔 때마다 늘어난다. 화면이 다시 불러오게 한다.
    private(set) var revision = 0

    private init() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.revision += 1 }
        }
    }

    var isAuthorized: Bool {
        status == .fullAccess
    }

    @discardableResult
    func requestAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        status = EKEventStore.authorizationStatus(for: .event)
        revision += 1
        return granted
    }

    func events(from start: Date, to end: Date) -> [ExternalEvent] {
        guard isAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            ExternalEvent(
                id: "\(event.eventIdentifier ?? UUID().uuidString)@\(Int(event.startDate.timeIntervalSince1970))",
                eventIdentifier: event.eventIdentifier ?? "",
                title: event.title?.isEmpty == false ? event.title : "제목 없음",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location ?? "",
                notes: event.notes ?? "",
                calendarTitle: event.calendar?.title ?? "",
                color: event.calendar.map { Color(cgColor: $0.cgColor) } ?? DGE.Palette.secondaryText
            )
        }
    }
}
