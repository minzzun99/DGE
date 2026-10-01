import SwiftUI
import AppKit
import Carbon.HIToolbox

/// 설정 값의 이름. `@AppStorage`와 서비스가 모두 여기 이름을 쓴다.
enum SettingsKey {
    static let appearance = "general.appearance"
    static let theme = "appearance.theme"
    static let textSize = "appearance.textSize"
    static let startScreen = "general.startScreen"
    static let dockBadge = "general.dockBadge"
    static let smartInput = "tasks.smartInput"

    static let showMenuBarItem = "menubar.show"
    static let menuBarCount = "menubar.showCount"

    static let dailySummary = "notifications.dailySummary"
    /// 자정부터 몇 분인지. (540 = 오전 9시)
    static let dailySummaryMinutes = "notifications.dailySummaryMinutes"
    static let defaultReminderMinutes = "notifications.defaultReminderMinutes"

    static let weekStart = "calendar.weekStart"
    static let calendarShowsTasks = "calendar.showsTasks"
    static let calendarMode = "calendar.mode"
    static let defaultEventMinutes = "calendar.defaultEventMinutes"
    static let showSystemCalendars = "calendar.showSystemCalendars"

    static let quickEntryShortcut = "shortcuts.quickEntry"

    /// 데일리 스크럼 메모에 넣을 할 일의 목록 id. 빈 문자열이면 모든 할 일.
    static let scrumListID = "notes.scrumListID"
}

/// 한 번에 등록해 두는 기본값. 앱을 켤 때 `UserDefaults`에 넣는다.
enum SettingsDefaults {
    static func register() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.appearance: AppearanceSetting.system.rawValue,
            SettingsKey.theme: ThemeSetting.standard.rawValue,
            SettingsKey.textSize: TextSizeSetting.standard.rawValue,
            SettingsKey.startScreen: StartScreen.today.rawValue,
            SettingsKey.dockBadge: true,
            SettingsKey.smartInput: true,
            SettingsKey.showMenuBarItem: true,
            SettingsKey.menuBarCount: true,
            SettingsKey.dailySummary: false,
            SettingsKey.dailySummaryMinutes: 540,
            SettingsKey.defaultReminderMinutes: 540,
            SettingsKey.weekStart: WeekStart.system.rawValue,
            SettingsKey.calendarShowsTasks: true,
            SettingsKey.calendarMode: CalendarMode.month.rawValue,
            SettingsKey.defaultEventMinutes: 60,
            SettingsKey.showSystemCalendars: false,
            SettingsKey.quickEntryShortcut: QuickEntryShortcut.controlOptionSpace.rawValue,
        ])
    }
}

// MARK: - 선택지

enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "시스템 설정 따르기"
        case .light: "라이트"
        case .dark: "다크"
        }
    }

    /// 좁은 자리(분할 선택기)에 쓰는 짧은 이름.
    var shortTitle: String {
        switch self {
        case .system: "시스템"
        case .light: "라이트"
        case .dark: "다크"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum StartScreen: String, CaseIterable, Identifiable {
    case today, inbox, upcoming, calendar, notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "오늘"
        case .inbox: "수신함"
        case .upcoming: "예정"
        case .calendar: "캘린더"
        case .notes: "메모"
        }
    }

    var item: SidebarItem {
        switch self {
        case .today: .today
        case .inbox: .inbox
        case .upcoming: .upcoming
        case .calendar: .calendar
        case .notes: .notes
        }
    }
}

enum WeekStart: Int, CaseIterable, Identifiable {
    case system = 0
    case sunday = 1
    case monday = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: "시스템 설정 따르기"
        case .sunday: "일요일"
        case .monday: "월요일"
        }
    }
}

enum CalendarMode: String, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "일"
        case .week: "주"
        case .month: "월"
        }
    }
}

/// 어디서든 빠른 입력 창을 여는 전역 단축키. 자주 쓰는 조합 몇 개 중에서 고른다.
enum QuickEntryShortcut: String, CaseIterable, Identifiable {
    case off
    case controlOptionSpace
    case shiftOptionSpace
    case controlOptionN
    case optionCommandN

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "사용 안 함"
        case .controlOptionSpace: "⌃⌥Space"
        case .shiftOptionSpace: "⇧⌥Space"
        case .controlOptionN: "⌃⌥N"
        case .optionCommandN: "⌥⌘N"
        }
    }

    var keyCode: UInt32? {
        switch self {
        case .off: nil
        case .controlOptionSpace, .shiftOptionSpace: UInt32(kVK_Space)
        case .controlOptionN, .optionCommandN: UInt32(kVK_ANSI_N)
        }
    }

    /// Carbon 수정 키 마스크.
    var modifiers: UInt32 {
        switch self {
        case .off: 0
        case .controlOptionSpace, .controlOptionN: UInt32(controlKey | optionKey)
        case .shiftOptionSpace: UInt32(shiftKey | optionKey)
        case .optionCommandN: UInt32(optionKey | cmdKey)
        }
    }
}

extension Calendar {
    /// 설정의 '주 시작 요일'을 반영한 달력. 달력 격자를 그릴 때만 쓴다.
    static var dge: Calendar {
        var calendar = Calendar.current
        let raw = UserDefaults.standard.integer(forKey: SettingsKey.weekStart)
        if let start = WeekStart(rawValue: raw), start != .system {
            calendar.firstWeekday = start.rawValue
        }
        return calendar
    }
}

extension Date {
    /// 자정부터 `minutes`분 뒤. (설정에 저장한 "시각"을 날짜에 붙일 때)
    func at(minutes: Int, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: self)
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }
}
