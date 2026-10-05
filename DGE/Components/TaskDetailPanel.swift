import SwiftUI
import SwiftData

/// 할 일을 고르면 오른쪽에서 열리는 상세.
/// 제목 · 날짜 · 알림 · 반복 · 우선순위 · 목록 · 태그 · 체크리스트 · 메모를 한곳에서 고친다.
struct TaskDetailPanel: View {
    @Bindable var task: TodoTask
    let onClose: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \TaskList.order) private var lists: [TaskList]
    @Query private var allTasks: [TodoTask]
    @AppStorage(SettingsKey.defaultReminderMinutes) private var defaultReminderMinutes = 540
    @FocusState private var titleFocused: Bool

    private var store: TaskStore { TaskStore(context: context) }

    /// 다른 할 일에서 쓰는 태그. 자주 쓰는 것부터.
    private var knownTags: [String] {
        var counts: [String: Int] = [:]
        for tag in allTasks.flatMap(\.tags) { counts[tag, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.map(\.key)
    }

    var body: some View {
        DetailPanel(kind: "할 일", icon: "checklist", onClose: onClose) {
            TextField("제목", text: $task.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(DGE.Typography.panelTitle)
                .lineLimit(1...4)
                .focused($titleFocused)

            VStack(alignment: .leading, spacing: 2) {
                PropertyRow("상태", icon: "circle.dashed") { status }

                if task.isCompleted {
                    PropertyRow("완료한 날", icon: "checkmark.circle") {
                        DatePicker("", selection: completedDateBinding, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .fixedSize()
                            .help("실제로 끝낸 날로 바꿉니다")
                    }
                }

                PropertyRow("날짜", icon: "calendar") {
                    VStack(alignment: .leading, spacing: 6) {
                        if task.dueDate != nil {
                            scheduledDateControls
                        }
                        quickDateButtons
                    }
                    .padding(.vertical, task.dueDate == nil ? 0 : 2)
                }

                PropertyRow("알림", icon: "bell") { reminder }

                PropertyRow("반복", icon: "arrow.clockwise") {
                    Picker("", selection: repeatBinding) {
                        Text("안 함").tag(RepeatRule?.none)
                        Divider()
                        ForEach(RepeatRule.allCases) { rule in
                            Text(rule.title).tag(RepeatRule?.some(rule))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                PropertyRow("우선순위", icon: "chart.bar") {
                    HStack(spacing: 4) {
                        ForEach(Priority.allCases) { priority in
                            ChipButton(title: priority.title, isSelected: task.priority == priority) {
                                store.setPriority(task, priority)
                            }
                        }
                    }
                }

                PropertyRow("목록", icon: "square.stack") {
                    Picker("", selection: listBinding) {
                        Text("없음").tag(UUID?.none)
                        ForEach(lists) { list in
                            Text(list.name).tag(UUID?.some(list.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                PropertyRow("태그", icon: "number") {
                    TagEditor(task: task, knownTags: knownTags) { store.save() }
                }

                PropertyRow("만든 날", icon: "clock") {
                    Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(DGE.Palette.secondaryText)
                }
            }

            PanelDivider()

            DetailField(checklistTitle) {
                ChecklistEditor(task: task) { store.save() }
                    .padding(.horizontal, -6)
            }

            PanelDivider()

            DetailField("메모") {
                TextEditor(text: $task.notes)
                    .font(.dge(size: 12.5))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .dgeFieldBackground(padding: 6)
            }

            PanelDivider()

            DeleteButton(title: "할 일 삭제", action: onDelete)
        }
        .onAppear {
            // 캘린더에서 막 만든 할 일이면 제목부터 적게 한다.
            if task.title.isEmpty { titleFocused = true }
        }
        .onDisappear { store.save() }
    }

    private var checklistTitle: String {
        guard let progress = task.checklistProgress else { return "체크리스트" }
        return "체크리스트 \(progress.done)/\(progress.total)"
    }

    // MARK: - 상태

    private var status: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
        }
    }

    private var statusText: String {
        if task.isCompleted { return "완료" }
        if task.isOverdue { return "기한 지남" }
        if task.isScheduledToday { return "오늘" }
        return task.dueDate == nil ? "날짜 없음" : "예정"
    }

    private var statusColor: Color {
        if task.isCompleted { return DGE.Palette.accent }
        if task.isOverdue { return DGE.Palette.overdue }
        return DGE.Palette.tertiaryText
    }

    // MARK: - 날짜

    /// 자주 쓰는 날짜. 지금 날짜와 같은 칩은 눌린 모양으로 보인다.
    private var quickDateButtons: some View {
        HStack(spacing: 6) {
            ChipButton(title: "오늘", isSelected: isDue(on: .startOfToday)) {
                setDueDate(.startOfToday)
            }
            ChipButton(title: "내일", isSelected: isDue(on: .startOfTomorrow)) {
                setDueDate(.startOfTomorrow)
            }
            ChipButton(title: "다음 주", isSelected: isDue(on: .startOfNextWeek), help: "다음 주 월요일") {
                setDueDate(.startOfNextWeek)
            }
            if task.dueDate == nil {
                // 날짜를 넣으면 위에 달력 입력이 나타난다.
                ChipButton(title: "", icon: "calendar", help: "날짜 직접 고르기") {
                    setDueDate(.startOfToday)
                }
            }
        }
    }

    private var scheduledDateControls: some View {
        HStack(spacing: 6) {
            DatePicker("", selection: dueDateBinding, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()

            IconButton(icon: "xmark.circle.fill", help: "날짜 지우기") {
                setDueDate(nil)
            }
        }
    }

    private func isDue(on day: Date) -> Bool {
        guard let dueDate = task.dueDate else { return false }
        return Calendar.current.isDate(dueDate, inSameDayAs: day)
    }

    private func setDueDate(_ date: Date?) {
        withAnimation(DGE.Motion.list) {
            store.setDueDate(task, date)
        }
    }

    // MARK: - 알림

    @ViewBuilder
    private var reminder: some View {
        if task.remindAt != nil {
            HStack(spacing: 6) {
                DatePicker("", selection: remindBinding, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .fixedSize()

                IconButton(icon: "xmark.circle.fill", help: "알림 끄기") {
                    task.remindAt = nil
                    store.save()
                }
            }
        } else {
            ChipButton(title: "알림 추가", icon: "bell") { addReminder() }
        }
    }

    /// 할 일 날짜(없으면 오늘)의 기본 알림 시각. 이미 지났으면 다음 정각.
    private func addReminder() {
        let base = task.dueDate ?? Date.startOfToday
        var remind = base.at(minutes: defaultReminderMinutes)
        if remind <= Date() {
            remind = Calendar.current.nextDate(
                after: Date(), matching: DateComponents(minute: 0), matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(3600)
        }
        task.remindAt = remind
        if task.dueDate == nil { task.dueDate = Calendar.current.startOfDay(for: remind) }
        store.save()
        AppServices.shared?.notifications.requestAuthorizationIfNeeded()
    }

    // MARK: - 값 연결

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { task.dueDate ?? Date.startOfToday },
            set: { setDueDate($0) }
        )
    }

    private var completedDateBinding: Binding<Date> {
        Binding(
            get: { task.completedAt ?? Date() },
            set: { day in
                withAnimation(DGE.Motion.list) {
                    store.setCompletedDate(task, day)
                }
            }
        )
    }

    private var remindBinding: Binding<Date> {
        Binding(
            get: { task.remindAt ?? Date() },
            set: {
                task.remindAt = $0
                store.save()
            }
        )
    }

    private var repeatBinding: Binding<RepeatRule?> {
        Binding(
            get: { task.repeatRule },
            set: { rule in
                task.repeatRule = rule
                // 반복은 기준 날짜가 있어야 한다.
                if rule != nil, task.dueDate == nil { task.dueDate = Date.startOfToday }
                store.save()
            }
        )
    }

    private var listBinding: Binding<UUID?> {
        Binding(
            get: { task.listID },
            set: { store.setList(task, $0) }
        )
    }
}
