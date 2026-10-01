import SwiftUI
import SwiftData

/// 메뉴바 아이콘을 누르면 열리는 작은 창.
/// 메인 창을 열지 않고도 오늘 할 일을 보고, 끝내고, 새로 적을 수 있다.
struct MenuBarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    @State private var completing: Set<UUID> = []

    private var tasks: [TodoTask] {
        allTasks.filter { !$0.isCompleted && $0.isDueToday }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            taskList
            Divider()

            QuickAddField { parsed in
                withAnimation(DGE.Motion.list) {
                    _ = TaskStore(context: context).create(parsed, defaultDueDate: Date.startOfToday)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)

            footer
        }
        // 글자를 키우면 창도 같이 넓혀, 아래쪽 버튼이 두 줄로 꺾이지 않게 한다.
        .frame(width: (286 * max(1, AppearanceStore.shared.textScale)).rounded())
    }

    // MARK: - 머리말

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("오늘")
                .font(.dge(size: 13.5, weight: .semibold))
                .foregroundStyle(DGE.Palette.primaryText)

            if !tasks.isEmpty {
                Text("\(tasks.count)")
                    .font(DGE.Typography.count)
                    .foregroundStyle(DGE.Palette.tertiaryText)
            }

            Spacer(minLength: 0)

            Text(Date().dgeHeaderText)
                .font(.dge(size: 11))
                .foregroundStyle(DGE.Palette.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - 목록

    @ViewBuilder
    private var taskList: some View {
        if tasks.isEmpty {
            Text("오늘은 비어 있습니다.")
                .font(.dge(size: 12))
                .foregroundStyle(DGE.Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 320)
        }
    }

    // MARK: - 아래쪽

    private var footer: some View {
        HStack(spacing: 14) {
            linkButton("미니 창", icon: "rectangle.on.rectangle") {
                openWindow(id: DGEWindow.mini)
                NSApp.activate()
            }
            linkButton("DGE 열기", icon: "macwindow") {
                openWindow(id: DGEWindow.main)
                NSApp.activate()
            }
            linkButton("빠른 입력", icon: "text.cursor") {
                AppServices.shared?.quickEntry.show()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 11)
    }

    private func linkButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.dge(size: 10, weight: .medium))
                Text(title)
                    .font(.dge(size: 11.5))
                    .lineLimit(1)
            }
            .foregroundStyle(DGE.Palette.secondaryText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
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

/// 메뉴 막대 아이콘. 설정에 따라 오늘 남은 개수를 옆에 붙인다.
struct MenuBarLabel: View {
    @Query private var tasks: [TodoTask]
    @AppStorage(SettingsKey.menuBarCount) private var showsCount = true
    @Environment(\.openWindow) private var openWindow

    private var count: Int {
        tasks.filter { !$0.isCompleted && $0.isDueToday }.count
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle")
            if showsCount, count > 0 {
                Text("\(count)")
                    .monospacedDigit()
            }
        }
        // 메뉴 막대 아이콘은 늘 떠 있으므로, 창이 없을 때 메인 창을 여는 동작을 여기서도 받아 둔다.
        .onAppear { AppServices.shared?.openWindow = openWindow }
    }
}
