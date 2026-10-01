import SwiftUI
import SwiftData

/// ⌘K 검색 · 명령 창. 할 일 · 일정 · 화면 · 동작을 한곳에서 찾아 Enter로 바로 간다.
/// 찾는 게 없으면 적은 그대로 새 할 일을 만들 수 있다.
struct CommandPalette: View {
    let onClose: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Query(sort: \TodoTask.order) private var tasks: [TodoTask]
    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]
    @Query(sort: \TaskList.order) private var lists: [TaskList]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @AppStorage(SettingsKey.smartInput) private var smartInput = true

    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var isFocused: Bool

    private struct Entry: Identifiable {
        let id: String
        let icon: String
        let title: String
        var detail: String? = nil
        var isDone = false
        var keys: String? = nil
        let perform: () -> Void
    }

    private struct Group: Identifiable {
        let id: String
        let title: String
        let entries: [Entry]
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            Rectangle().fill(DGE.Palette.hairline).frame(height: 1)

            results
        }
        .frame(width: 620)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DGE.Palette.canvas)
                .shadow(color: .black.opacity(0.2), radius: 28, y: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DGE.Palette.border, lineWidth: 1)
        )
        .onAppear { isFocused = true }
        .onChange(of: query) { _, _ in highlighted = 0 }
    }

    // MARK: - 입력

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.dge(size: 14, weight: .medium))
                .foregroundStyle(DGE.Palette.tertiaryText)

            TextField("할 일 · 일정 · 화면 검색, 또는 새 할 일 적기", text: $query)
                .textFieldStyle(.plain)
                .font(.dge(size: 15))
                .focused($isFocused)
                .onSubmit(performHighlighted)
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }
                .onExitCommand(perform: onClose)

            KeyHint("esc")
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    // MARK: - 결과

    private var results: some View {
        let groups = self.groups
        let flat = groups.flatMap(\.entries)

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if flat.isEmpty {
                        Text("찾는 것이 없습니다.")
                            .font(.dge(size: 12.5))
                            .foregroundStyle(DGE.Palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    ForEach(groups) { group in
                        Text(group.title)
                            .font(.dge(size: 11, weight: .semibold))
                            .foregroundStyle(DGE.Palette.tertiaryText)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 2)

                        ForEach(group.entries) { entry in
                            let index = flat.firstIndex { $0.id == entry.id } ?? 0
                            row(entry, isHighlighted: index == highlighted)
                                .id(entry.id)
                                .onTapGesture { run(entry) }
                                .onHover { if $0 { highlighted = index } }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: highlighted) { _, index in
                guard flat.indices.contains(index) else { return }
                proxy.scrollTo(flat[index].id)
            }
        }
    }

    private func row(_ entry: Entry, isHighlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.icon)
                .font(.dge(size: 12, weight: .medium))
                .foregroundStyle(isHighlighted ? DGE.Palette.primaryText : DGE.Palette.secondaryText)
                .frame(width: 18)

            Text(entry.title)
                .font(.dge(size: 13))
                .foregroundStyle(entry.isDone ? DGE.Palette.secondaryText : DGE.Palette.primaryText)
                .strikethrough(entry.isDone, color: DGE.Palette.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let detail = entry.detail {
                Text(detail)
                    .font(.dge(size: 11.5))
                    .foregroundStyle(DGE.Palette.tertiaryText)
                    .lineLimit(1)
            }
            if let keys = entry.keys {
                KeyHint(keys)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.row, style: .continuous)
                .fill(isHighlighted ? DGE.Palette.selected : Color.clear)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }

    // MARK: - 무엇을 보여줄지

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var groups: [Group] {
        var groups: [Group] = []
        let q = trimmedQuery

        var createGroup: Group?
        if !q.isEmpty {
            let parsed = smartInput ? QuickAddParser.parse(q, listNames: lists.map(\.name)) : ParsedTask(title: q)
            var detail = parsed.dueDate?.dgeDayTitle ?? "수신함"
            if !parsed.tags.isEmpty { detail += " · " + parsed.tags.map { "#\($0)" }.joined(separator: " ") }
            createGroup = Group(id: "create", title: "새로 만들기", entries: [
                Entry(id: "create", icon: "plus", title: "‘\(parsed.title)’ 할 일 만들기", detail: detail) {
                    if let task = TaskStore(context: context).create(parsed) {
                        appState.showToast("‘\(task.displayTitle)’을(를) 만들었습니다", actionTitle: "보기") {
                            appState.reveal(task)
                        }
                    }
                },
            ])

            let matchedTasks = tasks
                .filter { $0.matches(q) }
                .sorted { !$0.isCompleted && $1.isCompleted }
                .prefix(8)
            if !matchedTasks.isEmpty {
                groups.append(Group(id: "tasks", title: "할 일", entries: matchedTasks.map { task in
                    Entry(
                        id: "task-\(task.id)",
                        icon: task.isCompleted ? "checkmark.circle.fill" : "circle",
                        title: task.displayTitle,
                        detail: taskDetail(task),
                        isDone: task.isCompleted
                    ) { appState.reveal(task) }
                }))
            }

            let matchedNotes = notes.filter { $0.matches(q) }.prefix(5)
            if !matchedNotes.isEmpty {
                groups.append(Group(id: "notes", title: "메모", entries: matchedNotes.map { note in
                    Entry(
                        id: "note-\(note.id)",
                        icon: note.isScrum ? "person.3" : "note.text",
                        title: note.displayTitle,
                        detail: note.updatedAt.dgeShortText
                    ) { appState.reveal(note) }
                }))
            }

            let matchedEvents = events.filter { $0.matches(q) }.prefix(5)
            if !matchedEvents.isEmpty {
                groups.append(Group(id: "events", title: "일정", entries: matchedEvents.map { event in
                    Entry(
                        id: "event-\(event.id)",
                        icon: "calendar",
                        title: event.displayTitle,
                        detail: "\(event.startDate.dgeShortText) \(event.isAllDay ? "하루 종일" : event.startDate.dgeTimeText)"
                    ) { appState.reveal(event) }
                }))
            }
        }

        let navigation = navigationEntries.filter { q.isEmpty || $0.title.localizedCaseInsensitiveContains(q) }
        if !navigation.isEmpty {
            groups.append(Group(id: "go", title: "이동", entries: navigation))
        }

        let actions = actionEntries.filter { q.isEmpty || $0.title.localizedCaseInsensitiveContains(q) }
        if !actions.isEmpty {
            groups.append(Group(id: "actions", title: "동작", entries: actions))
        }

        // 찾은 게 있으면 Enter는 그걸 연다. 만들기는 맨 뒤라, 아무것도 없을 때만 첫 줄이 된다.
        if let createGroup {
            groups.append(createGroup)
        }
        return groups
    }

    private var navigationEntries: [Entry] {
        var entries = [
            Entry(id: "go-inbox", icon: "tray", title: "수신함", keys: "⌘1") { appState.selection = .inbox },
            Entry(id: "go-today", icon: "sun.max", title: "오늘", keys: "⌘2") { appState.selection = .today },
            Entry(id: "go-upcoming", icon: "calendar.badge.clock", title: "예정", keys: "⌘3") { appState.selection = .upcoming },
            Entry(id: "go-calendar", icon: "calendar", title: "캘린더", keys: "⌘4") { appState.selection = .calendar },
            Entry(id: "go-completed", icon: "checkmark.circle", title: "완료", keys: "⌘5") { appState.selection = .completed },
            Entry(id: "go-notes", icon: "note.text", title: "메모", keys: "⌘6") { appState.selection = .notes },
        ]
        entries += lists.map { list in
            Entry(id: "go-list-\(list.id)", icon: "square.stack", title: list.name, detail: "목록") {
                appState.selection = .list(list.id)
            }
        }
        let tags = Set(tasks.filter { !$0.isCompleted }.flatMap(\.tags)).sorted()
        entries += tags.map { tag in
            Entry(id: "go-tag-\(tag)", icon: "number", title: tag, detail: "태그") { appState.selection = .tag(tag) }
        }
        return entries
    }

    private var actionEntries: [Entry] {
        [
            Entry(id: "act-new", icon: "square.and.pencil", title: "새 할 일", keys: "⌘N") { appState.requestNewTask() },
            Entry(id: "act-note", icon: "note.text.badge.plus", title: "새 메모") { appState.requestNewNote() },
            Entry(id: "act-scrum", icon: "person.3", title: "오늘 데일리 스크럼 메모") { appState.requestScrum() },
            Entry(id: "act-scrum-next", icon: "moon.stars", title: "다음 근무일 데일리 스크럼 준비") {
                appState.requestScrum(for: NoteStore.nextWorkday(after: Date.startOfToday))
            },
            Entry(id: "act-event", icon: "calendar.badge.plus", title: "오늘 일정 추가") {
                let event = EventStore(context: context).create(on: Date())
                appState.reveal(event)
            },
            Entry(id: "act-quick", icon: "text.cursor", title: "빠른 입력 창", keys: "⇧⌘N") {
                AppServices.shared?.quickEntry.show()
            },
            Entry(id: "act-mini", icon: "rectangle.on.rectangle", title: "미니 창", keys: "⇧⌘M") {
                openWindow(id: DGEWindow.mini)
            },
            Entry(id: "act-settings", icon: "gearshape", title: "설정", keys: "⌘,") { openSettings() },
        ]
    }

    private func taskDetail(_ task: TodoTask) -> String {
        var parts: [String] = []
        if let dueDate = task.dueDate { parts.append(dueDate.dgeShortText) }
        if let listID = task.listID, let list = lists.first(where: { $0.id == listID }) { parts.append(list.name) }
        parts += task.tags.prefix(2).map { "#\($0)" }
        return parts.joined(separator: " · ")
    }

    // MARK: - 동작

    private func move(_ delta: Int) {
        let count = groups.flatMap(\.entries).count
        guard count > 0 else { return }
        highlighted = (highlighted + delta + count) % count
    }

    private func performHighlighted() {
        let flat = groups.flatMap(\.entries)
        guard flat.indices.contains(highlighted) else { return }
        run(flat[highlighted])
    }

    private func run(_ entry: Entry) {
        onClose()
        // 창이 닫힌 뒤에 움직여야 포커스가 제자리로 간다.
        Task { entry.perform() }
    }
}
