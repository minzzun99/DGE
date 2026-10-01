import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \TaskList.order) private var lists: [TaskList]

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            Sidebar(
                selection: $state.selection,
                onNewTask: { appState.requestNewTask() },
                onSearch: { appState.isPaletteOpen = true }
            )
            .navigationSplitViewColumnWidth(min: 210, ideal: 236, max: 300)
        } detail: {
            detail
                // 자정이 지나면 '오늘'을 다시 계산하도록 화면을 새로 만든다.
                .id(appState.dayToken)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DGE.Palette.canvas)
        }
        // 제목은 본문 머리말이 보여주므로 툴바에서는 뺀다. (창 메뉴에는 그대로 남는다)
        .toolbar(removing: .title)
        .overlay { palette }
        .overlay(alignment: .bottom) { toast }
        .animation(DGE.Motion.list, value: appState.isPaletteOpen)
        .animation(DGE.Motion.list, value: appState.toast)
        .task { prepareDefaultLists() }
        .onAppear { AppServices.shared?.openWindow = openWindow }
    }

    @ViewBuilder
    private var detail: some View {
        switch appState.selection {
        case .inbox:
            InboxView(focusRequest: appState.newTaskRequest)
        case .today:
            TodayView(focusRequest: appState.newTaskRequest)
        case .upcoming:
            UpcomingView(focusRequest: appState.newTaskRequest)
        case .calendar:
            CalendarView()
        case .completed:
            CompletedView()
        case .notes:
            NotesView()
        case .list(let id):
            if let list = lists.first(where: { $0.id == id }) {
                ListView(list: list, focusRequest: appState.newTaskRequest)
                    // 목록끼리 옮겨 다닐 때 열어둔 상세 패널이 따라오지 않게 한다.
                    .id(list.id)
            } else {
                TodayView(focusRequest: appState.newTaskRequest)
            }
        case .tag(let tag):
            TagView(tag: tag, focusRequest: appState.newTaskRequest)
                .id(tag)
        }
    }

    // MARK: - 떠 있는 것들

    @ViewBuilder
    private var palette: some View {
        if appState.isPaletteOpen {
            ZStack(alignment: .top) {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture { appState.isPaletteOpen = false }

                CommandPalette(onClose: { appState.isPaletteOpen = false })
                    .padding(.top, 80)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let toast = appState.toast {
            ToastView(toast: toast, onDismiss: { appState.dismissToast() })
                .padding(.bottom, 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// 첫 실행이면 기본 목록을 넣어주고,
    /// 영어로 만들어 두었던 초기 목록은 한 번만 한국어로 바꿔준다.
    private func prepareDefaultLists() {
        if lists.isEmpty {
            for (index, name) in TaskList.defaultNames.enumerated() {
                context.insert(TaskList(name: name, order: index))
            }
        } else {
            for list in lists {
                if let korean = TaskList.renamedFromEnglish[list.name] {
                    list.name = korean
                }
            }
        }
        TaskStore(context: context).save()
    }
}
