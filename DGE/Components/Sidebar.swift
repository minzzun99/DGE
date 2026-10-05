import SwiftUI
import SwiftData

/// 왼쪽 사이드바. 위에는 앱 이름 · 새 할 일 · 검색, 가운데는 화면 · 목록 · 태그, 아래는 설정과 미니 창.
/// 아이콘은 회색 한 가지로 두고, 선택은 시스템이 그리는 회색 판에 맡긴다.
struct Sidebar: View {
    @Binding var selection: SidebarItem
    let onNewTask: () -> Void
    let onSearch: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Query private var tasks: [TodoTask]
    @Query(sort: \TaskList.order) private var lists: [TaskList]

    /// 이름을 고치는 중인 목록.
    @State private var renamingListID: UUID?
    @State private var renameDraft = ""
    @FocusState private var renameFocused: Bool
    @State private var listPendingDeletion: TaskList?

    var body: some View {
        List(selection: $selection) {
            Section {
                item(.today, title: "오늘", icon: "sun.max", count: todayCount)
                item(.upcoming, title: "예정", icon: "calendar.badge.clock", count: upcomingCount)
                item(.calendar, title: "캘린더", icon: "calendar")
                item(.completed, title: "완료", icon: "checkmark.circle")
                item(.notes, title: "메모", icon: "note.text")
            }

            Section {
                ForEach(lists) { list in
                    listRow(list)
                }
                .onMove { source, destination in
                    ListStore(context: context).reorder(lists, from: source, to: destination)
                }
            } header: {
                HStack {
                    Text("목록")
                    Spacer(minLength: 0)
                    Button(action: createList) {
                        Image(systemName: "plus")
                            .font(.dge(size: 10.5, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DGE.Palette.secondaryText)
                    .help("새 목록")
                }
            }

            if !tagCounts.isEmpty {
                Section("태그") {
                    ForEach(tagCounts, id: \.tag) { entry in
                        Label(entry.tag, systemImage: "number")
                            .badge(entry.count)
                            .tag(SidebarItem.tag(entry.tag))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .listItemTint(.monochrome)
        .background(AppearanceStore.shared.theme.sidebarTint)
        .safeAreaInset(edge: .top, spacing: 4) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .confirmationDialog(
            "‘\(listPendingDeletion?.name ?? "")’ 목록을 지울까요?",
            isPresented: Binding(get: { listPendingDeletion != nil }, set: { if !$0 { listPendingDeletion = nil } })
        ) {
            Button("목록 지우기", role: .destructive) {
                if let list = listPendingDeletion { deleteList(list) }
                listPendingDeletion = nil
            }
        } message: {
            Text("안에 있는 할 일 \(listPendingDeletion.map(openCount(in:)) ?? 0)개는 지우지 않습니다. 날짜가 없는 할 일은 ‘할 일’ 목록으로 옮깁니다.")
        }
    }

    // MARK: - 위

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)
                Text("DGE")
                    .font(.dge(size: 13, weight: .semibold))
                    .foregroundStyle(DGE.Palette.primaryText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 2)

            SidebarWideButton(title: "새 할 일", icon: "square.and.pencil", keys: "⌘N", isProminent: true, action: onNewTask)
            SidebarWideButton(title: "검색", icon: "magnifyingglass", keys: "⌘K", action: onSearch)
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    // MARK: - 아래

    private var footer: some View {
        HStack(spacing: 4) {
            FooterButton(title: "설정", icon: "gearshape") {
                openSettings()
            }

            Spacer(minLength: 0)

            IconButton(icon: "rectangle.on.rectangle", help: "미니 창 (⇧⌘M)", width: 26, height: 24) {
                openWindow(id: DGEWindow.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    // MARK: - 항목

    private func item(
        _ value: SidebarItem,
        title: String,
        icon: String,
        count: Int = 0
    ) -> some View {
        Label(title, systemImage: icon)
            .badge(count)
            .tag(value)
    }

    @ViewBuilder
    private func listRow(_ list: TaskList) -> some View {
        Label {
            if renamingListID == list.id {
                TextField("목록 이름", text: $renameDraft)
                    .textFieldStyle(.plain)
                    .focused($renameFocused)
                    .onSubmit { commitRename(list) }
                    .onExitCommand { renamingListID = nil }
                    .onChange(of: renameFocused) { _, focused in
                        if !focused { commitRename(list) }
                    }
            } else {
                Text(list.name)
            }
        } icon: {
            ListGlyph(name: list.name, size: 15)
        }
        .badge(openCount(in: list))
        .tag(SidebarItem.list(list.id))
        .contextMenu {
            Button("이름 바꾸기") { startRename(list) }
            // '할 일' 목록은 날짜 없는 할 일이 갈 곳이라 지우지 않는다.
            if !list.isDefault {
                Divider()
                Button("목록 지우기…", role: .destructive) { listPendingDeletion = list }
            }
        }
    }

    // MARK: - 목록 관리

    private func createList() {
        let list = ListStore(context: context).create()
        selection = .list(list.id)
        startRename(list)
    }

    private func startRename(_ list: TaskList) {
        renameDraft = list.name
        renamingListID = list.id
        // 줄이 텍스트 필드로 바뀐 다음에 포커스를 준다.
        Task { renameFocused = true }
    }

    private func commitRename(_ list: TaskList) {
        guard renamingListID == list.id else { return }
        ListStore(context: context).rename(list, to: renameDraft)
        renamingListID = nil
    }

    private func deleteList(_ list: TaskList) {
        if selection == .list(list.id) { selection = .today }
        ListStore(context: context).delete(list)
    }

    // MARK: - 개수

    private var todayCount: Int {
        tasks.filter { !$0.isCompleted && $0.isDueToday }.count
    }

    private var upcomingCount: Int {
        tasks.filter { !$0.isCompleted && $0.isUpcoming }.count
    }

    private func openCount(in list: TaskList) -> Int {
        tasks.filter { !$0.isCompleted && $0.listID == list.id }.count
    }

    /// 남은 할 일에 붙은 태그와 개수. 많이 쓰는 것부터.
    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for task in tasks where !task.isCompleted {
            for tag in task.tags { counts[tag, default: 0] += 1 }
        }
        return counts
            .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .map { (tag: $0.key, count: $0.value) }
    }
}

/// 사이드바 맨 위의 넓은 버튼. 단축키를 같이 적는다.
private struct SidebarWideButton: View {
    let title: String
    let icon: String
    let keys: String
    var isProminent: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.dge(size: 12, weight: .medium))
                    .frame(width: 14)
                Text(title)
                    .font(.dge(size: 12.5, weight: isProminent ? .medium : .regular))
                Spacer(minLength: 0)
                KeyHint(keys)
            }
            .foregroundStyle(isProminent ? DGE.Palette.primaryText : DGE.Palette.secondaryText)
            .padding(.leading, 9)
            .padding(.trailing, 6)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.row, style: .continuous)
                    .fill(isHovering ? DGE.Palette.selected : (isProminent ? DGE.Palette.hover : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DGE.Radius.row, style: .continuous)
                    .strokeBorder(isProminent ? DGE.Palette.border : DGE.Palette.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}

/// 사이드바 아래쪽 글자 버튼.
private struct FooterButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.dge(size: 12, weight: .regular))
                Text(title)
                    .font(.dge(size: 12.5))
            }
            .foregroundStyle(isHovering ? DGE.Palette.primaryText : DGE.Palette.secondaryText)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.control, style: .continuous)
                    .fill(isHovering ? DGE.Palette.hover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}
