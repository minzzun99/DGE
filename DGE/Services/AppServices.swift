import SwiftUI
import SwiftData
import AppKit
import ServiceManagement

/// 창과 상관없이 앱이 켜져 있는 동안 돌아가는 것들.
/// 알림 예약, Dock 배지, 전역 단축키, 모양(라이트/다크), 날짜가 바뀌는 순간.
@MainActor
final class AppServices {
    /// 앱에 하나. 뷰에서 알림 권한을 물을 때처럼 가끔 찾아 쓴다.
    static var shared: AppServices?

    let container: ModelContainer
    let appState: AppState
    let notifications: NotificationService
    let quickEntry: QuickEntryController

    /// 메인 창을 여는 동작. 창이 닫혀 있어도 알림에서 열 수 있게 뷰에서 받아 둔다.
    var openWindow: OpenWindowAction?

    private var observers: [NSObjectProtocol] = []
    private var refreshTask: Task<Void, Never>?
    private var lastShortcut: QuickEntryShortcut?
    private var lastAppearance: AppearanceSetting?

    init(container: ModelContainer, appState: AppState) {
        self.container = container
        self.appState = appState
        self.notifications = NotificationService(container: container)
        self.quickEntry = QuickEntryController(container: container)
    }

    func start() {
        applySettings()

        notifications.configure()
        notifications.onOpenTask = { [weak self] id in self?.openTask(id) }
        notifications.onOpenEvent = { [weak self] id in self?.openEvent(id) }

        GlobalHotKey.shared.onPress = { [weak self] in self?.quickEntry.toggle() }

        let center = NotificationCenter.default
        // 어디서 저장하든(메인 창, 메뉴 막대, 알림 버튼) 여기서 한 번에 따라간다.
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleRefresh() }
        })
        observers.append(center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.appState.dayToken += 1
                self?.scheduleRefresh()
            }
        })
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.applySettings()
                self?.scheduleRefresh()
            }
        })

        scheduleRefresh()
    }

    // MARK: - 따라가기

    /// 저장이 여러 번 몰려도 한 번만 다시 계산한다.
    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.updateDockBadge()
            await self.notifications.reschedule()
        }
    }

    private func updateDockBadge() {
        guard UserDefaults.standard.bool(forKey: SettingsKey.dockBadge) else {
            NSApp.dockTile.badgeLabel = nil
            return
        }
        let tasks = (try? container.mainContext.fetch(FetchDescriptor<TodoTask>())) ?? []
        let count = tasks.filter { !$0.isCompleted && $0.isDueToday }.count
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    /// 바뀐 설정만 다시 적용한다. (UserDefaults 알림은 아무 키가 바뀌어도 오므로)
    private func applySettings() {
        let defaults = UserDefaults.standard

        let appearance = AppearanceSetting(rawValue: defaults.string(forKey: SettingsKey.appearance) ?? "") ?? .system
        if appearance != lastAppearance {
            lastAppearance = appearance
            NSApp.appearance = appearance.nsAppearance
        }

        let shortcut = QuickEntryShortcut(rawValue: defaults.string(forKey: SettingsKey.quickEntryShortcut) ?? "") ?? .off
        if shortcut != lastShortcut {
            lastShortcut = shortcut
            GlobalHotKey.shared.register(shortcut)
        }
    }

    // MARK: - 열기

    func showMainWindow() {
        openWindow?(id: DGEWindow.main)
        NSApp.activate()
    }

    private func openTask(_ id: UUID) {
        let tasks = (try? container.mainContext.fetch(FetchDescriptor<TodoTask>())) ?? []
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        showMainWindow()
        appState.reveal(task)
    }

    private func openEvent(_ id: UUID) {
        let events = (try? container.mainContext.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        guard let event = events.first(where: { $0.id == id }) else { return }
        showMainWindow()
        appState.reveal(event)
    }
}

/// 로그인할 때 자동으로 켜기. 시스템 설정의 '로그인 항목'과 같은 곳을 바꾼다.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// 앱이 다 뜬 뒤에 서비스를 시작하고, Dock 아이콘을 눌렀을 때 메인 창을 다시 연다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppServices.shared?.start()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainActor.assumeIsolated {
                AppServices.shared?.showMainWindow()
            }
        }
        return true
    }
}
