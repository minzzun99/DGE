import SwiftUI
import SwiftData

/// 데스크탑 한쪽에 띄워두는 작은 창.
/// 오늘 할 일만 보여주고, 바로 체크하고 바로 적을 수 있다.
struct MiniWindowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    @AppStorage("mini.alwaysOnTop") private var alwaysOnTop = true
    @State private var completing: Set<UUID> = []

    private var tasks: [TodoTask] {
        allTasks.filter { !$0.isCompleted && $0.isDueToday }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            taskList
            QuickAddField { parsed in
                withAnimation(DGE.Motion.list) {
                    _ = TaskStore(context: context).create(parsed, defaultDueDate: Date.startOfToday)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 190, minHeight: 140)
        .background(DGE.Palette.canvas)
        .background(WindowAccessor(configure: configure))
    }

    // MARK: - 머리말

    private var header: some View {
        HStack(spacing: 6) {
            Text("오늘")
                .font(.dge(size: 12.5, weight: .bold))
                .foregroundStyle(DGE.Palette.primaryText)

            if !tasks.isEmpty {
                Text("\(tasks.count)")
                    .font(DGE.Typography.count)
                    .foregroundStyle(DGE.Palette.tertiaryText)
            }

            Spacer(minLength: 0)

            pinButton
        }
        // 제목 표시줄을 숨겼으므로 닫기 버튼 자리를 비워둔다.
        .padding(.leading, 44)
        .padding(.trailing, 10)
        .padding(.top, 9)
        .padding(.bottom, 7)
    }

    private var pinButton: some View {
        IconButton(
            icon: alwaysOnTop ? "pin.fill" : "pin",
            help: alwaysOnTop ? "항상 위에 표시 끄기" : "항상 위에 표시",
            isActive: alwaysOnTop,
            width: 20,
            height: 18
        ) {
            alwaysOnTop.toggle()
        }
    }

    // MARK: - 목록

    @ViewBuilder
    private var taskList: some View {
        if tasks.isEmpty {
            VStack(spacing: 8) {
                Text("오늘은 비어 있습니다.")
                    .font(.dge(size: 12))
                    .foregroundStyle(DGE.Palette.secondaryText)
                ChipButton(title: "DGE 열기", icon: "macwindow") {
                    openWindow(id: DGEWindow.main)
                    NSApp.activate()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 16)
        } else {
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(tasks) { task in
                        CompactTaskRow(
                            task: task,
                            isChecked: isChecked(task),
                            onToggle: { toggle(task) },
                            onPostpone: {
                                withAnimation(DGE.Motion.list) {
                                    TaskStore(context: context).postponeToTomorrow(task)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - 창 설정

    private func configure(_ window: NSWindow) {
        window.level = alwaysOnTop ? .floating : .normal
        window.isMovableByWindowBackground = true
        // 전체 화면 앱 위에도 뜰 수 있게 한다.
        window.collectionBehavior = [.fullScreenAuxiliary]
        // 작은 위젯이라 최소화/확대 버튼은 쓸 일이 없다. 닫기만 남긴다.
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    // MARK: - 동작

    private func isChecked(_ task: TodoTask) -> Bool {
        task.isCompleted || completing.contains(task.id)
    }

    private func toggle(_ task: TodoTask) {
        let store = TaskStore(context: context)
        let id = task.id

        withAnimation(DGE.Motion.check) {
            _ = completing.insert(id)
        }

        Task {
            try? await Task.sleep(for: DGE.Motion.completionHold)
            withAnimation(DGE.Motion.list) {
                store.setCompleted(task, true)
            }
            completing.remove(id)
        }
    }
}
