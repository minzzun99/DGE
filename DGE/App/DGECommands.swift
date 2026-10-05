import SwiftUI

/// 키보드만으로 움직일 수 있게 하는 메뉴 명령.
struct DGECommands: Commands {
    let appState: AppState

    @Environment(\.openWindow) private var openWindow
    /// 목록에서 고른 할 일들. 목록에 포커스가 있을 때만 있다.
    @FocusedValue(\.taskCommands) private var taskCommands

    var body: some Commands {
        // ⌘N은 기본값이 "새 창"이므로 "새 할 일"로 바꾼다.
        CommandGroup(replacing: .newItem) {
            Button("새 할 일") {
                appState.requestNewTask()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("빠른 입력 창") {
                AppServices.shared?.quickEntry.show()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("새 메모") { appState.requestNewNote() }
            Button("오늘 데일리 스크럼 메모") { appState.requestScrum() }
            Button("다음 근무일 데일리 스크럼 메모") {
                appState.requestScrum(for: NoteStore.nextWorkday(after: Date.startOfToday))
            }
        }

        CommandMenu("이동") {
            Button("할 일 목록") { appState.selection = .list(TaskList.defaultID) }
                .keyboardShortcut("1", modifiers: .command)
            Button("오늘") { appState.selection = .today }
                .keyboardShortcut("2", modifiers: .command)
            Button("예정") { appState.selection = .upcoming }
                .keyboardShortcut("3", modifiers: .command)
            Button("캘린더") { appState.selection = .calendar }
                .keyboardShortcut("4", modifiers: .command)
            Button("완료") { appState.selection = .completed }
                .keyboardShortcut("5", modifiers: .command)
            Button("메모") { appState.selection = .notes }
                .keyboardShortcut("6", modifiers: .command)
            Divider()
            Button("검색 · 명령…") { appState.isPaletteOpen = true }
                .keyboardShortcut("k", modifiers: .command)
            Button("찾기…") { appState.isPaletteOpen = true }
                .keyboardShortcut("f", modifiers: .command)
        }

        CommandMenu("할 일") {
            Group {
                Button(completeTitle) { taskCommands?.toggleComplete() }
                    .keyboardShortcut(.return, modifiers: .command)
                Divider()
                Button("오늘로") { taskCommands?.moveToToday() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("내일로 미루기") { taskCommands?.postpone() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("다음 주로 미루기") { taskCommands?.postponeToNextWeek() }
                    .keyboardShortcut("t", modifiers: [.command, .option])
                Divider()
                Menu("우선순위") {
                    Button("높음") { taskCommands?.setPriority(.high) }
                        .keyboardShortcut("3", modifiers: .control)
                    Button("보통") { taskCommands?.setPriority(.medium) }
                        .keyboardShortcut("2", modifiers: .control)
                    Button("낮음") { taskCommands?.setPriority(.low) }
                        .keyboardShortcut("1", modifiers: .control)
                    Button("없음") { taskCommands?.setPriority(.none) }
                        .keyboardShortcut("0", modifiers: .control)
                }
                Button("상세 정보") { taskCommands?.showInfo() }
                    .keyboardShortcut("i", modifiers: .command)
                Divider()
                Button(deleteTitle) { taskCommands?.delete() }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
            // 목록에서 고른 할 일이 없으면 모두 끈다.
            .disabled(taskCommands == nil)
        }

        CommandGroup(after: .windowArrangement) {
            Button("미니 창") {
                openWindow(id: DGEWindow.mini)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }

    private var completeTitle: String {
        guard let count = taskCommands?.count, count > 1 else { return "완료 / 완료 취소" }
        return "\(count)개 완료 / 완료 취소"
    }

    private var deleteTitle: String {
        guard let count = taskCommands?.count, count > 1 else { return "삭제" }
        return "\(count)개 삭제"
    }
}
