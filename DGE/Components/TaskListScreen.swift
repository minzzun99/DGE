import SwiftUI
import SwiftData

/// 화면 안의 할 일 한 묶음. 제목이 없으면 머리줄 없이 할 일만 보인다.
struct TaskSection: Identifiable {
    let id: String
    var title: String? = nil
    var icon: String? = nil
    var tint: Color = DGE.Palette.secondaryText
    var tasks: [TodoTask]
    /// 머리줄 오른쪽에 붙는 묶음 전체 동작. ("모두 오늘로")
    var action: SectionAction? = nil
}

struct SectionAction {
    let title: String
    let icon: String
    let perform: () -> Void
}

extension TaskSection {
    /// 날짜별로 묶는다. `tasks`는 이미 날짜 순으로 정렬되어 있어야 한다.
    static func byDay(_ tasks: [TodoTask], day: (TodoTask) -> Date) -> [TaskSection] {
        let calendar = Calendar.current
        var result: [TaskSection] = []
        for task in tasks {
            let start = calendar.startOfDay(for: day(task))
            let id = "\(Int(start.timeIntervalSince1970))"
            if result.last?.id == id {
                result[result.count - 1].tasks.append(task)
            } else {
                result.append(TaskSection(id: id, title: start.dgeDayTitle, tasks: [task]))
            }
        }
        return result
    }
}

/// 머리말 + 입력창 + 묶음별 할 일 목록. 할 일을 다루는 모든 화면이 이 뼈대를 공유한다.
struct TaskListScreen: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    let sections: [TaskSection]
    let emptyIcon: String
    let emptyTitle: String
    var emptyMessage: String? = nil
    /// nil이면 입력창을 숨긴다. (완료처럼 적을 필요가 없는 화면)
    var inputPlaceholder: String? = nil
    var focusRequest: Int = 0
    var showsDate: Bool = false
    /// 할 일마다 속한 목록을 보여줄지. 목록 화면 안에서는 끈다.
    var showsList: Bool = true
    /// 끌어서 순서를 바꿀 수 있는 화면인지. (완료처럼 순서가 정해진 화면은 끈다)
    var allowsReordering: Bool = false
    /// 머리말 오른쪽에 보여줄 진행도. (끝낸 수, 전체 수)
    var progress: (done: Int, total: Int)? = nil
    /// 입력창에 적은 것으로 할 일을 만든다. 화면마다 기본 날짜 · 목록이 다르다.
    var onCreate: ((ParsedTask) -> TodoTask?)? = nil
    /// 이 화면에 들어오는 할 일인지. 방금 만든 할 일이 다른 화면으로 갔으면 알려주는 데 쓴다.
    var accepts: ((TodoTask) -> Bool)? = nil

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \TaskList.order) private var lists: [TaskList]
    /// 상세 패널은 이 화면 밖으로 나간 할 일도 계속 보여줘야 하므로 전체에서 찾는다.
    @Query private var storedTasks: [TodoTask]
    /// 완료를 누른 직후, 목록에서 사라지기 전까지 체크된 것처럼 보여줄 할 일.
    @State private var completing: Set<UUID> = []
    /// 목록에서 선택된 줄들. ⌘ / ⇧ 클릭으로 여러 개를 고를 수 있다.
    @State private var selection: Set<UUID> = []
    /// 상세 패널에 열어둔 할 일.
    /// 선택과 따로 둔다. 날짜를 바꿔 할 일이 이 화면에서 빠져도 패널은 닫히지 않게.
    @State private var inspectedTaskID: UUID?
    @State private var contentWidth: CGFloat = 0

    private var allTasks: [TodoTask] {
        sections.flatMap(\.tasks)
    }

    private var inspectedTask: TodoTask? {
        guard let inspectedTaskID else { return nil }
        return storedTasks.first { $0.id == inspectedTaskID }
    }

    /// 창이 넓으면 본문을 가운데로 모으고, 좁으면 기본 여백만 둔다.
    private var gutter: CGFloat {
        max(DGE.Spacing.screenHorizontal, (contentWidth - DGE.Size.contentMaxWidth) / 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(icon: icon, title: title, count: allTasks.count, subtitle: subtitle) {
                if let progress {
                    ProgressSummary(done: progress.done, total: progress.total)
                }
            }
            .padding(.horizontal, gutter)
            .padding(.top, DGE.Spacing.screenTop)
            .padding(.bottom, DGE.Spacing.headerBottom)

            if let inputPlaceholder, onCreate != nil {
                TaskInput(
                    placeholder: inputPlaceholder,
                    focusRequest: focusRequest,
                    onSubmit: create
                )
                .padding(.horizontal, gutter)
                .padding(.bottom, 10)
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        .navigationTitle(title)
        .onChange(of: selection) { _, newValue in
            // 하나만 골랐을 때 패널이 따라간다. 선택이 풀리는 건 패널을 닫을 이유가 아니다.
            if newValue.count == 1, let id = newValue.first { inspectedTaskID = id }
        }
        .onAppear(perform: handleReveal)
        .onChange(of: appState.revealTaskID) { _, _ in handleReveal() }
        .inspector(isPresented: inspectorBinding) {
            Group {
                if let inspectedTask {
                    TaskDetailPanel(
                        task: inspectedTask,
                        onClose: closeInspector,
                        onDelete: { delete([inspectedTask]) }
                    )
                    .id(inspectedTask.id)
                } else {
                    Color.clear
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 330, max: 440)
        }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { inspectedTask != nil },
            set: { if !$0 { closeInspector() } }
        )
    }

    // MARK: - 목록

    @ViewBuilder
    private var content: some View {
        if allTasks.isEmpty {
            EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage)
        } else {
            ScrollViewReader { proxy in
                List(selection: $selection) {
                    ForEach(sections) { section in
                        Section {
                            // 머리줄도 한 줄로 넣는다. 시스템 섹션 머리말은 위에 들러붙고 선이 생긴다.
                            if let sectionTitle = section.title {
                                SectionHeaderRow(
                                    title: sectionTitle,
                                    icon: section.icon,
                                    tint: section.tint,
                                    count: section.tasks.count,
                                    action: section.action
                                )
                                .selectionDisabled()
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(rowInsets)
                            }
                            rows(in: section)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 1)
                .contextMenu(forSelectionType: UUID.self) { ids in
                    menu(for: tasks(ids))
                } primaryAction: { ids in
                    if let id = ids.first { inspect(id) }
                }
                .onExitCommand(perform: closeInspector)
                .focusedValue(\.taskCommands, commands)
                .onChange(of: inspectedTaskID) { _, id in
                    guard let id, allTasks.contains(where: { $0.id == id }) else { return }
                    withAnimation(DGE.Motion.list) { proxy.scrollTo(id) }
                }
            }
        }
    }

    /// 묶음 하나의 할 일들. 순서 바꾸기는 묶음 안에서만 한다.
    private func rows(in section: TaskSection) -> some View {
        ForEach(section.tasks) { task in
            TaskRow(
                task: task,
                isChecked: isChecked(task),
                showsDate: showsDate,
                listName: showsList ? listName(for: task) : nil,
                onToggle: { toggle([task]) },
                onMoveToToday: { reschedule([task]) { $0.moveToToday($1) } },
                onPostpone: { reschedule([task]) { $0.postponeToTomorrow($1) } },
                onDelete: { delete([task]) }
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(rowInsets)
            .id(task.id)
        }
        .onMove(perform: moveHandler(for: section.tasks))
    }

    private var rowInsets: EdgeInsets {
        let side = gutter - DGE.Spacing.rowHorizontal
        return EdgeInsets(top: 0, leading: side, bottom: 0, trailing: side)
    }

    private func listName(for task: TodoTask) -> String? {
        guard let listID = task.listID else { return nil }
        return lists.first { $0.id == listID }?.name
    }

    private func tasks(_ ids: Set<UUID>) -> [TodoTask] {
        allTasks.filter { ids.contains($0.id) }
    }

    // MARK: - 우클릭 메뉴

    @ViewBuilder
    private func menu(for targets: [TodoTask]) -> some View {
        if !targets.isEmpty {
            let single = targets.count == 1 ? targets.first : nil
            let allCompleted = targets.allSatisfy(\.isCompleted)

            if let single {
                Button(single.id == inspectedTaskID ? "상세 닫기" : "상세 열기") { toggleInspector(single) }
                Divider()
            }

            Button(allCompleted ? "완료 취소" : "완료") { toggle(targets) }

            if !allCompleted {
                Divider()
                Button("오늘로") { reschedule(targets) { $0.moveToToday($1) } }
                Button("내일로 미루기") { reschedule(targets) { $0.postponeToTomorrow($1) } }
                Button("다음 주 월요일로") { reschedule(targets) { $0.postponeToNextWeek($1) } }
                Button("날짜 지우기") { reschedule(targets) { $0.setDueDate($1, nil) } }
            }

            Divider()

            Menu("우선순위") {
                ForEach(Priority.allCases.reversed()) { priority in
                    Button(priority.title) { setPriority(targets, priority) }
                }
            }

            Menu("목록으로 이동") {
                Button("목록 없음") { setList(targets, nil) }
                if !lists.isEmpty { Divider() }
                ForEach(lists) { list in
                    Button(list.name) { setList(targets, list.id) }
                }
            }

            Divider()
            Button(targets.count > 1 ? "\(targets.count)개 삭제" : "삭제", role: .destructive) { delete(targets) }
        }
    }

    /// 메뉴 막대 명령(⌘T, ⌘↩ …)이 부를 동작. 고른 것이 없으면 nil이라 명령이 꺼진다.
    private var commands: TaskCommands? {
        let targets = tasks(selection)
        guard !targets.isEmpty else { return nil }
        return TaskCommands(
            count: targets.count,
            toggleComplete: { toggle(targets) },
            moveToToday: { reschedule(targets) { $0.moveToToday($1) } },
            postpone: { reschedule(targets) { $0.postponeToTomorrow($1) } },
            postponeToNextWeek: { reschedule(targets) { $0.postponeToNextWeek($1) } },
            setPriority: { setPriority(targets, $0) },
            showInfo: { if let first = targets.first { toggleInspector(first) } },
            delete: { delete(targets) }
        )
    }

    // MARK: - 상세 패널

    private func inspect(_ id: UUID) {
        selection = [id]
        inspectedTaskID = id
    }

    private func toggleInspector(_ task: TodoTask) {
        if inspectedTaskID == task.id {
            closeInspector()
        } else {
            inspect(task.id)
        }
    }

    private func closeInspector() {
        inspectedTaskID = nil
        selection = []
    }

    /// 검색이나 알림에서 "이 할 일을 열어 줘"라고 했을 때.
    private func handleReveal() {
        guard let id = appState.revealTaskID, allTasks.contains(where: { $0.id == id }) else { return }
        appState.revealTaskID = nil
        inspect(id)
    }

    // MARK: - 동작

    private func create(_ parsed: ParsedTask) {
        guard let task = onCreate?(parsed) else { return }
        // 적은 말 때문에 다른 화면으로 간 할 일이면 어디로 갔는지 알려준다.
        if let accepts, !accepts(task) {
            let destination = AppState.screen(for: task)
            appState.showToast("‘\(task.displayTitle)’ → \(destinationName(destination, task: task))", actionTitle: "보기") {
                appState.reveal(task)
            }
        }
    }

    private func destinationName(_ item: SidebarItem, task: TodoTask) -> String {
        switch item {
        case .today: "오늘"
        case .upcoming: task.dueDate?.dgeDayTitle ?? "예정"
        case .inbox: "수신함"
        case .completed: "완료"
        case .calendar: "캘린더"
        case .list(let id): lists.first { $0.id == id }?.name ?? "목록"
        case .tag(let tag): "#\(tag)"
        case .notes: "메모"
        }
    }

    private func isChecked(_ task: TodoTask) -> Bool {
        task.isCompleted || completing.contains(task.id)
    }

    /// 하나라도 안 끝난 게 있으면 모두 끝내고, 전부 끝난 것이면 모두 되돌린다.
    private func toggle(_ targets: [TodoTask]) {
        let store = TaskStore(context: context)

        if targets.allSatisfy(\.isCompleted) {
            withAnimation(DGE.Motion.list) {
                targets.forEach { store.setCompleted($0, false) }
            }
            return
        }

        // 완료 표시를 잠깐 보여준 다음 목록에서 빼준다.
        let open = targets.filter { !$0.isCompleted }
        withAnimation(DGE.Motion.check) {
            open.forEach { completing.insert($0.id) }
        }

        Task {
            try? await Task.sleep(for: DGE.Motion.completionHold)
            withAnimation(DGE.Motion.list) {
                open.forEach { store.setCompleted($0, true) }
            }
            open.forEach { completing.remove($0.id) }
        }
    }

    /// 날짜를 바꾸는 동작. 이 화면에서 빠지는 할 일이면 부드럽게 사라지게 한다.
    private func reschedule(_ targets: [TodoTask], _ change: (TaskStore, TodoTask) -> Void) {
        let store = TaskStore(context: context)
        withAnimation(DGE.Motion.list) {
            targets.forEach { change(store, $0) }
        }
    }

    private func setPriority(_ targets: [TodoTask], _ priority: Priority) {
        let store = TaskStore(context: context)
        targets.forEach { store.setPriority($0, priority) }
    }

    private func setList(_ targets: [TodoTask], _ listID: UUID?) {
        let store = TaskStore(context: context)
        withAnimation(DGE.Motion.list) {
            targets.forEach { store.setList($0, listID) }
        }
    }

    /// 묶음마다 따로 순서를 바꾼다. 묶음을 넘나드는 이동은 받지 않는다.
    private func moveHandler(for tasks: [TodoTask]) -> ((IndexSet, Int) -> Void)? {
        guard allowsReordering else { return nil }
        return { source, destination in
            withAnimation(DGE.Motion.list) {
                TaskStore(context: context).reorder(tasks, from: source, to: destination)
            }
        }
    }

    /// 지우고 나서 잠깐 "실행 취소"를 띄운다.
    private func delete(_ targets: [TodoTask]) {
        guard !targets.isEmpty else { return }
        if let inspectedTaskID, targets.contains(where: { $0.id == inspectedTaskID }) {
            closeInspector()
        }
        selection.subtract(targets.map(\.id))

        let store = TaskStore(context: context)
        let message = targets.count == 1
            ? "‘\(targets[0].displayTitle)’을(를) 삭제했습니다"
            : "할 일 \(targets.count)개를 삭제했습니다"
        var snapshots: [TaskSnapshot] = []
        withAnimation(DGE.Motion.list) {
            snapshots = store.delete(targets)
        }
        appState.showToast(message, actionTitle: "실행 취소") {
            withAnimation(DGE.Motion.list) { store.restore(snapshots) }
        }
    }
}

/// 묶음 제목 줄. "기한 지남 2"처럼 이름과 개수, 필요하면 오른쪽에 묶음 전체 동작.
private struct SectionHeaderRow: View {
    let title: String
    let icon: String?
    let tint: Color
    let count: Int
    let action: SectionAction?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.dge(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(DGE.Typography.sectionTitle)
                .foregroundStyle(DGE.Palette.primaryText)
            Text("\(count)")
                .font(DGE.Typography.count)
                .foregroundStyle(DGE.Palette.tertiaryText)

            Spacer(minLength: 0)

            if let action {
                ChipButton(title: action.title, icon: action.icon, action: action.perform)
            }
        }
        .padding(.horizontal, DGE.Spacing.rowHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}
