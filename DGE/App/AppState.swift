import SwiftUI

/// 창 하나가 공유하는 작은 상태.
/// 지금 보고 있는 화면, "새 할 일 입력창으로 가라"는 신호, 검색창, 잠깐 뜨는 안내.
@Observable
@MainActor
final class AppState {
    var selection: SidebarItem

    /// 값이 바뀌는 것 자체가 신호다. 입력창은 이 값의 변화를 보고 포커스를 가져간다.
    private(set) var newTaskRequest: Int = 0
    /// 메모 화면에 맡긴 일. 메모 화면이 받아서 처리하고 비운다.
    /// (화면이 바뀌는 중에 보내도 사라지지 않도록 신호 대신 값으로 둔다)
    var noteRequest: NoteRequest?

    /// ⌘K 검색 · 명령 창.
    var isPaletteOpen = false

    /// 다른 곳(검색, 알림)에서 "이 할 일을 열어 줘"라고 한 것. 그 할 일이 있는 화면이 받아서 연다.
    var revealTaskID: UUID?
    var revealEventID: UUID?
    var revealNoteID: UUID?

    /// 아래쪽에 잠깐 뜨는 안내. ("삭제했습니다 · 실행 취소")
    private(set) var toast: Toast?
    private var toastDismissal: Task<Void, Never>?

    /// 날짜가 바뀔 때마다 늘어난다. 화면이 "오늘"을 다시 계산하게 한다.
    var dayToken = 0

    init() {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.startScreen) ?? ""
        selection = StartScreen(rawValue: raw)?.item ?? .today
    }

    /// ⌘N. 입력창이 없는 화면이면 오늘로 옮긴 뒤 포커스를 준다.
    func requestNewTask() {
        switch selection {
        case .calendar, .completed:
            selection = .today
            // 화면이 먼저 바뀌어야 새 입력창이 신호를 받는다.
            Task { newTaskRequest += 1 }
        case .today, .upcoming, .list, .tag:
            newTaskRequest += 1
        case .notes:
            noteRequest = .new
        }
    }

    /// 메모 화면으로 가서 새 메모를 만든다.
    func requestNewNote() {
        selection = .notes
        noteRequest = .new
    }

    /// 메모 화면으로 가서 그날 데일리 스크럼 메모를 연다. (없으면 할 일 기록으로 채워 만든다)
    func requestScrum(for day: Date = Date.startOfToday) {
        selection = .notes
        noteRequest = .scrum(day)
    }

    // MARK: - 보여주기

    func reveal(_ task: TodoTask) {
        selection = Self.screen(for: task)
        revealTaskID = task.id
    }

    func reveal(_ event: CalendarEvent) {
        selection = .calendar
        revealEventID = event.id
    }

    func reveal(_ note: Note) {
        selection = .notes
        revealNoteID = note.id
    }

    /// 할 일이 가장 자연스럽게 보이는 화면.
    static func screen(for task: TodoTask) -> SidebarItem {
        if task.isCompleted { return .completed }
        if task.isDueToday { return .today }
        if task.isUpcoming { return .upcoming }
        return .list(task.listID ?? TaskList.defaultID)
    }

    // MARK: - 안내

    func showToast(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        toast = Toast(message: message, actionTitle: actionTitle, action: action)
        toastDismissal?.cancel()
        toastDismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(DGE.Motion.list) { self?.toast = nil }
        }
    }

    func dismissToast() {
        toastDismissal?.cancel()
        toast = nil
    }
}

enum NoteRequest: Equatable {
    case new
    /// 그날 스크럼 메모.
    case scrum(Date)
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// 목록에서 고른 할 일들에 대한 동작. 메뉴 막대 명령(⌘T, ⌘↩ …)이 이걸 부른다.
/// 목록에 포커스가 있을 때만 값이 있어서, 글을 쓰는 중에 ⌘⌫를 눌러도 할 일이 지워지지 않는다.
struct TaskCommands {
    let count: Int
    let toggleComplete: () -> Void
    let moveToToday: () -> Void
    let postpone: () -> Void
    let postponeToNextWeek: () -> Void
    let setPriority: (Priority) -> Void
    let showInfo: () -> Void
    let delete: () -> Void
}

extension FocusedValues {
    @Entry var taskCommands: TaskCommands?
}
