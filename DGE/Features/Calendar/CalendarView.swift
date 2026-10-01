import SwiftUI
import SwiftData

/// 캘린더 화면. 격자는 `CalendarBoard`가 그리고, 여기서는 상세 패널만 얹는다.
/// 일정 · 할 일 · macOS 캘린더 일정 중 무엇을 골랐는지에 따라 패널 모양이 바뀐다.
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var events: [CalendarEvent]
    @State private var anchor = Date()
    @State private var selection: CalendarSelection?

    var body: some View {
        CalendarBoard(
            anchor: $anchor,
            onSelectEvent: { selection = .event($0) },
            onSelectTask: { selection = .task($0) },
            onSelectExternal: { selection = .external($0) }
        )
        .navigationTitle("캘린더")
        .onAppear(perform: handleReveal)
        .onChange(of: appState.revealEventID) { _, _ in handleReveal() }
        .inspector(isPresented: inspectorBinding) {
            Group {
                switch selection {
                case .event(let event):
                    EventDetailPanel(
                        event: event,
                        onClose: { selection = nil },
                        onDelete: { delete(event) }
                    )
                    .id(event.id)
                case .task(let task):
                    TaskDetailPanel(
                        task: task,
                        onClose: { selection = nil },
                        onDelete: { delete(task) }
                    )
                    .id(task.id)
                case .external(let event):
                    ExternalEventPanel(event: event, onClose: { selection = nil })
                        .id(event.id)
                case nil:
                    Color.clear
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 330, max: 440)
        }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { selection != nil },
            set: { if !$0 { selection = nil } }
        )
    }

    /// 검색이나 알림에서 "이 일정을 열어 줘"라고 했을 때. 그 날짜로 옮겨 연다.
    private func handleReveal() {
        guard let id = appState.revealEventID, let event = events.first(where: { $0.id == id }) else { return }
        appState.revealEventID = nil
        anchor = event.startDate
        selection = .event(event)
    }

    private func delete(_ event: CalendarEvent) {
        selection = nil
        let store = EventStore(context: context)
        let snapshot = store.deleteKeepingSnapshot(event)
        appState.showToast("‘\(snapshot.title.isEmpty ? "제목 없음" : snapshot.title)’ 일정을 삭제했습니다", actionTitle: "실행 취소") {
            store.restore(snapshot)
        }
    }

    private func delete(_ task: TodoTask) {
        selection = nil
        let store = TaskStore(context: context)
        let snapshots = store.delete([task])
        appState.showToast("‘\(task.displayTitle)’을(를) 삭제했습니다", actionTitle: "실행 취소") {
            store.restore(snapshots)
        }
    }
}

/// macOS 캘린더 일정의 상세. 읽기만 하고, 고치려면 캘린더 앱으로 보낸다.
private struct ExternalEventPanel: View {
    let event: ExternalEvent
    let onClose: () -> Void

    var body: some View {
        DetailPanel(kind: event.calendarTitle.isEmpty ? "캘린더" : event.calendarTitle, icon: "calendar", onClose: onClose) {
            Text(event.title)
                .font(DGE.Typography.panelTitle)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 2) {
                PropertyRow("시간", icon: "clock") {
                    Text(event.isAllDay ? "\(event.start.dgeHeaderText) · 하루 종일" : "\(event.start.dgeShortText) \(event.timeRangeText)")
                }
                if !event.location.isEmpty {
                    PropertyRow("위치", icon: "mappin") {
                        Text(event.location).textSelection(.enabled)
                    }
                }
                PropertyRow("캘린더", icon: "circle.fill") {
                    HStack(spacing: 6) {
                        Circle().fill(event.color).frame(width: 8, height: 8)
                        Text(event.calendarTitle)
                    }
                }
            }

            if !event.notes.isEmpty {
                PanelDivider()
                DetailField("설명") {
                    Text(event.notes)
                        .font(.dge(size: 12.5))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            PanelDivider()

            ChipButton(title: "캘린더 앱에서 열기", icon: "arrow.up.forward.app") {
                if let url = URL(string: "ical://ekevent/\(event.eventIdentifier)?method=show&options=more") {
                    NSWorkspace.shared.open(url)
                }
            }

            Text("macOS 캘린더의 일정은 여기서 읽기만 합니다.")
                .font(.dge(size: 11.5))
                .foregroundStyle(DGE.Palette.tertiaryText)
        }
    }
}
