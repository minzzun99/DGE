import Foundation
import SwiftData
import UserNotifications

/// 할 일 알림 · 일정 알림 · 아침 요약을 예약한다.
///
/// 하나씩 더하고 빼지 않고, 바뀔 때마다 전부 다시 맞춘다.
/// 데이터가 크지 않아서 이쪽이 틀릴 일이 적다.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let container: ModelContainer

    /// 알림을 눌렀을 때. (할 일 / 일정 id)
    var onOpenTask: ((UUID) -> Void)?
    var onOpenEvent: ((UUID) -> Void)?

    private enum Category {
        static let task = "dge.task"
        static let event = "dge.event"
    }

    private enum Action {
        static let complete = "dge.complete"
        static let snooze = "dge.snooze"
    }

    /// 우리가 예약한 알림의 id 앞부분. 다시 맞출 때 이것만 지운다.
    private static let prefixes = ["task.", "event.", "summary."]

    init(container: ModelContainer) {
        self.container = container
        super.init()
    }

    func configure() {
        center.delegate = self
        let complete = UNNotificationAction(identifier: Action.complete, title: "완료")
        let snooze = UNNotificationAction(identifier: Action.snooze, title: "10분 뒤 다시")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.task, actions: [complete, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.event, actions: [], intentIdentifiers: []),
        ])
    }

    // MARK: - 권한

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 처음 알림을 켤 때 한 번 묻는다. 이미 정해졌으면 조용히 넘어간다.
    func requestAuthorizationIfNeeded() {
        Task {
            guard await authorizationStatus() == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            await reschedule()
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await reschedule()
        return granted
    }

    /// 설정 화면의 "시험 알림".
    func sendTest() {
        let content = UNMutableNotificationContent()
        content.title = "DGE"
        content.body = "알림이 이렇게 옵니다."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: "test.\(UUID())", content: content, trigger: trigger))
    }

    // MARK: - 예약

    func reschedule() async {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let context = container.mainContext
        let tasks = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        let now = Date()

        var requests: [(date: Date, request: UNNotificationRequest)] = []

        for task in tasks where !task.isCompleted {
            guard let remindAt = task.remindAt, remindAt > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = task.displayTitle
            content.body = taskBody(task)
            content.sound = .default
            content.categoryIdentifier = Category.task
            content.userInfo = ["taskID": task.id.uuidString]
            requests.append((remindAt, request("task.\(task.id.uuidString)", content, at: remindAt)))
        }

        for event in events {
            guard let alert = event.alert else { continue }
            for start in event.upcomingStarts(from: now, within: 14) {
                let fire = start.addingTimeInterval(-Double(alert.rawValue) * 60)
                guard fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = event.displayTitle
                content.body = alert == .atStart
                    ? "지금 시작합니다 · \(event.timeRangeText)"
                    : "\(alert.title) · \(start.dgeTimeText) 시작" + (event.location.isEmpty ? "" : " · \(event.location)")
                content.sound = .default
                content.categoryIdentifier = Category.event
                content.userInfo = ["eventID": event.id.uuidString]
                let id = "event.\(event.id.uuidString).\(Int(start.timeIntervalSince1970))"
                requests.append((fire, request(id, content, at: fire)))
            }
        }

        requests.append(contentsOf: summaryRequests(tasks: tasks, now: now))

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { id in Self.prefixes.contains { id.hasPrefix($0) } }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        // 시스템이 쌓아둘 수 있는 수에 한계가 있어서 가까운 것부터 넣는다.
        for item in requests.sorted(by: { $0.date < $1.date }).prefix(60) {
            try? await center.add(item.request)
        }
    }

    /// 앞으로 일주일 치 아침 요약. 그날 할 일 수를 미리 세어 둔다.
    private func summaryRequests(tasks: [TodoTask], now: Date) -> [(date: Date, request: UNNotificationRequest)] {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: SettingsKey.dailySummary) else { return [] }
        let minutes = defaults.integer(forKey: SettingsKey.dailySummaryMinutes)
        let calendar = Calendar.current
        var result: [(Date, UNNotificationRequest)] = []

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date.startOfToday) else { continue }
            let fire = day.at(minutes: minutes)
            guard fire > now else { continue }

            let due = tasks.filter { task in
                guard !task.isCompleted, let dueDate = task.dueDate else { return false }
                // 첫날은 밀린 일까지 센다.
                return offset == 0
                    ? calendar.startOfDay(for: dueDate) <= day
                    : calendar.isDate(dueDate, inSameDayAs: day)
            }

            let content = UNMutableNotificationContent()
            content.title = "오늘 할 일 \(due.count)개"
            content.body = due.isEmpty
                ? "오늘은 정해 둔 할 일이 없습니다."
                : due.prefix(3).map(\.displayTitle).joined(separator: ", ") + (due.count > 3 ? " 외 \(due.count - 3)개" : "")
            content.sound = .default
            result.append((fire, request("summary.\(offset)", content, at: fire)))
        }
        return result
    }

    private func taskBody(_ task: TodoTask) -> String {
        var parts: [String] = []
        if let dueDate = task.dueDate { parts.append(dueDate.dgeDayTitle) }
        if let firstLine = task.notes.split(separator: "\n").first { parts.append(String(firstLine)) }
        return parts.isEmpty ? "할 일" : parts.joined(separator: " · ")
    }

    private func request(_ id: String, _ content: UNNotificationContent, at date: Date) -> UNNotificationRequest {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    // MARK: - 알림에서 온 동작

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // 앱을 보고 있을 때도 배너를 띄운다.
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let taskID = (info["taskID"] as? String).flatMap(UUID.init(uuidString:))
        let eventID = (info["eventID"] as? String).flatMap(UUID.init(uuidString:))
        let action = response.actionIdentifier
        await handle(action: action, taskID: taskID, eventID: eventID)
    }

    private func handle(action: String, taskID: UUID?, eventID: UUID?) async {
        if let taskID {
            let context = container.mainContext
            let tasks = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
            guard let task = tasks.first(where: { $0.id == taskID }) else { return }
            switch action {
            case Action.complete:
                TaskStore(context: context).setCompleted(task, true)
            case Action.snooze:
                task.remindAt = Date().addingTimeInterval(10 * 60)
                TaskStore(context: context).save()
            default:
                onOpenTask?(taskID)
            }
        } else if let eventID, action == UNNotificationDefaultActionIdentifier {
            onOpenEvent?(eventID)
        }
    }
}
