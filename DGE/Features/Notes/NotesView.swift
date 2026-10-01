import SwiftUI
import SwiftData

/// 메모 화면. 왼쪽은 메모 목록, 오른쪽은 고른 메모를 바로 고치는 편집기.
///
/// "데일리 스크럼"을 누르면 할 일 기록에서 어제 한 일 · 오늘 할 일 · 오늘 일정을 모아
/// 오늘 스크럼에서 할 말을 미리 채워 둔다.
struct NotesView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @AppStorage(SettingsKey.scrumListID) private var scrumListID = ""

    @State private var selectedNoteID: UUID?
    @State private var search = ""
    @State private var showsScrumPicker = false

    private var filtered: [Note] {
        notes.filter { $0.matches(search) }
    }

    private var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(icon: "note.text", title: "메모", count: notes.count, subtitle: "회의 · 생각 · 데일리 스크럼에서 할 말") {
                HStack(spacing: 8) {
                    ChipButton(
                        title: "데일리 스크럼",
                        icon: "person.3",
                        help: "오늘 또는 다음 근무일 스크럼 메모. 없으면 할 일 기록으로 채워 만듭니다"
                    ) { showsScrumPicker = true }
                    .popover(isPresented: $showsScrumPicker, arrowEdge: .bottom) {
                        ScrumDayPicker(hasScrum: hasScrum) { day in
                            showsScrumPicker = false
                            openScrum(for: day)
                        }
                    }
                    ChipButton(title: "새 메모", icon: "square.and.pencil", help: "새 메모 (⌘N)") { createNote() }
                }
            }
            .padding(.horizontal, DGE.Spacing.screenHorizontal)
            .padding(.top, DGE.Spacing.screenTop)
            .padding(.bottom, DGE.Spacing.headerBottom)

            HStack(spacing: 0) {
                noteList
                    .frame(width: 270)
                Rectangle()
                    .fill(DGE.Palette.hairline)
                    .frame(width: 1)
                editor
            }
            .background(DGE.Palette.canvas)
            .clipShape(RoundedRectangle(cornerRadius: DGE.Radius.container, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DGE.Radius.container, style: .continuous)
                    .strokeBorder(DGE.Palette.border, lineWidth: 1)
            )
            .padding(.horizontal, DGE.Spacing.screenHorizontal)
            .padding(.bottom, DGE.Spacing.screenHorizontal - 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("메모")
        .onAppear {
            handleRequest()
            handleReveal()
            if selectedNoteID == nil { selectedNoteID = notes.first?.id }
        }
        .onChange(of: appState.noteRequest) { _, _ in handleRequest() }
        .onChange(of: appState.revealNoteID) { _, _ in handleReveal() }
    }

    // MARK: - 목록

    private var noteList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.dge(size: 11, weight: .medium))
                    .foregroundStyle(DGE.Palette.tertiaryText)
                TextField("메모 검색", text: $search)
                    .textFieldStyle(.plain)
                    .font(.dge(size: 12.5))
                if !search.isEmpty {
                    IconButton(icon: "xmark.circle.fill", help: "검색 지우기", width: 16, height: 16) { search = "" }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                    .fill(DGE.Palette.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                    .strokeBorder(DGE.Palette.border, lineWidth: 1)
            )
            .padding(10)

            if filtered.isEmpty {
                Text(search.isEmpty ? "아직 메모가 없습니다." : "찾는 메모가 없습니다.")
                    .font(.dge(size: 12))
                    .foregroundStyle(DGE.Palette.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedNoteID) {
                    let pinned = filtered.filter(\.isPinned)
                    if !pinned.isEmpty {
                        Section("고정") {
                            ForEach(pinned) { row(for: $0) }
                        }
                    }
                    Section(pinned.isEmpty ? "" : "메모") {
                        ForEach(filtered.filter { !$0.isPinned }) { row(for: $0) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(DGE.Palette.surface.opacity(0.6))
    }

    private func row(for note: Note) -> some View {
        NoteRow(note: note)
            .listRowSeparator(.hidden)
            .contextMenu {
                Button(note.isPinned ? "고정 해제" : "맨 위에 고정") {
                    withAnimation(DGE.Motion.list) { NoteStore(context: context).togglePin(note) }
                }
                Divider()
                Button("삭제", role: .destructive) { delete(note) }
            }
    }

    // MARK: - 편집기

    @ViewBuilder
    private var editor: some View {
        if let selectedNote {
            NoteEditor(note: selectedNote, onDelete: { delete(selectedNote) })
                .id(selectedNote.id)
        } else {
            EmptyState(
                icon: "note.text",
                title: "메모를 고르거나 새로 만드세요",
                message: "‘데일리 스크럼’을 누르면 어제 한 일 · 오늘 할 일을 할 일 기록에서 채워 줍니다."
            )
        }
    }

    // MARK: - 동작

    private func createNote() {
        search = ""
        let note = NoteStore(context: context).create()
        withAnimation(DGE.Motion.list) { selectedNoteID = note.id }
    }

    private func openScrum(for day: Date) {
        search = ""
        let result = NoteStore(context: context).scrum(for: day, listID: UUID(uuidString: scrumListID))
        withAnimation(DGE.Motion.list) { selectedNoteID = result.note.id }
    }

    private func hasScrum(_ day: Date) -> Bool {
        notes.contains { $0.scrumDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false }
    }

    private func delete(_ note: Note) {
        let store = NoteStore(context: context)
        let title = note.displayTitle
        if selectedNoteID == note.id {
            // 지운 자리에는 바로 다음 메모를 연다.
            let index = filtered.firstIndex { $0.id == note.id } ?? 0
            let next = filtered.indices.contains(index + 1) ? filtered[index + 1] : (index > 0 ? filtered[index - 1] : nil)
            selectedNoteID = next?.id
        }
        var snapshot: NoteSnapshot?
        withAnimation(DGE.Motion.list) { snapshot = store.delete(note) }
        guard let snapshot else { return }
        appState.showToast("‘\(title)’ 메모를 삭제했습니다", actionTitle: "실행 취소") {
            store.restore(snapshot)
            selectedNoteID = snapshot.id
        }
    }

    /// ⌘N, 검색 창, 메뉴에서 맡긴 일.
    private func handleRequest() {
        guard let request = appState.noteRequest else { return }
        appState.noteRequest = nil
        switch request {
        case .new: createNote()
        case .scrum(let day): openScrum(for: day)
        }
    }

    private func handleReveal() {
        guard let id = appState.revealNoteID else { return }
        appState.revealNoteID = nil
        search = ""
        selectedNoteID = id
    }
}

/// 메모 목록 한 줄. 제목과 고친 때, 본문 앞부분.
private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if note.isScrum {
                    Image(systemName: "person.3")
                        .font(.dge(size: 9.5, weight: .semibold))
                        .foregroundStyle(DGE.Palette.accent)
                }
                Text(note.displayTitle)
                    .font(.dge(size: 13, weight: .semibold))
                    .foregroundStyle(DGE.Palette.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.dge(size: 9))
                        .foregroundStyle(DGE.Palette.tertiaryText)
                }
            }
            HStack(spacing: 6) {
                Text(dateText)
                    .font(.dge(size: 11.5))
                    .foregroundStyle(DGE.Palette.secondaryText)
                    .fixedSize()
                Text(note.preview.isEmpty ? "내용 없음" : note.preview)
                    .font(.dge(size: 11.5))
                    .foregroundStyle(DGE.Palette.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
    }

    /// 오늘 고친 것은 시각, 아니면 날짜.
    private var dateText: String {
        Calendar.current.isDateInToday(note.updatedAt) ? note.updatedAt.dgeTimeText : note.updatedAt.dgeShortText
    }
}

/// 메모 하나를 고치는 곳. 제목 · 본문, 그리고 고른 줄을 할 일로 바꾸는 버튼.
private struct NoteEditor: View {
    @Bindable var note: Note
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \TaskList.order) private var lists: [TaskList]
    @AppStorage(SettingsKey.smartInput) private var smartInput = true
    @AppStorage(SettingsKey.scrumListID) private var scrumListID = ""

    @State private var selection: TextSelection?
    @State private var confirmsRefill = false
    @FocusState private var titleFocused: Bool
    @FocusState private var bodyFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar

            Rectangle()
                .fill(DGE.Palette.hairline)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                TextField("제목", text: $note.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.dge(size: 22, weight: .semibold))
                    .lineLimit(1...3)
                    .focused($titleFocused)
                    .onSubmit { bodyFocused = true }

                if note.isScrum {
                    scrumBar
                }

                TextEditor(text: $note.body, selection: $selection)
                    .font(.dge(size: 14))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .focused($bodyFocused)
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onChange(of: note.title) { _, _ in note.updatedAt = Date() }
        .onChange(of: note.body) { _, _ in note.updatedAt = Date() }
        .onAppear {
            // 방금 만든 빈 메모면 제목부터 적게 한다.
            if note.title.isEmpty && note.body.isEmpty { titleFocused = true }
        }
        .onDisappear { NoteStore(context: context).save() }
        .confirmationDialog("할 일 기록으로 다시 채울까요?", isPresented: $confirmsRefill) {
            Button("다시 채우기", role: .destructive) {
                NoteStore(context: context).refill(note, listID: UUID(uuidString: scrumListID))
            }
        } message: {
            Text("지금 이 메모에 적은 내용은 새로 모은 내용으로 바뀝니다.")
        }
    }

    // MARK: - 도구 줄

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("\(note.updatedAt.formatted(date: .abbreviated, time: .shortened))에 고침")
                .font(.dge(size: 11.5))
                .foregroundStyle(DGE.Palette.tertiaryText)

            Spacer(minLength: 0)

            ChipButton(
                title: "할 일로 만들기",
                icon: "checklist",
                help: "고른 줄(없으면 커서가 있는 줄)을 할 일로 만듭니다 (⇧⌘↩)"
            ) { makeTasks() }
            .keyboardShortcut(.return, modifiers: [.command, .shift])

            IconButton(
                icon: note.isPinned ? "pin.fill" : "pin",
                help: note.isPinned ? "고정 해제" : "맨 위에 고정",
                isActive: note.isPinned
            ) {
                withAnimation(DGE.Motion.list) { NoteStore(context: context).togglePin(note) }
            }

            IconButton(icon: "trash", help: "메모 삭제", isDestructive: true, action: onDelete)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    /// 스크럼 메모에만 붙는 줄. 어느 날 스크럼인지, 어느 할 일을 모을지 고르고, 다시 채울 수 있다.
    private var scrumBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.3")
                .font(.dge(size: 11, weight: .semibold))
                .foregroundStyle(DGE.Palette.accent)
            Text("스크럼 날짜")
                .font(.dge(size: 12))
                .foregroundStyle(DGE.Palette.secondaryText)
            DatePicker("", selection: scrumDayBinding, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()
                .help("어느 날 스크럼에서 할 말인지. 바꾼 뒤 ‘다시 채우기’로 그날 기준으로 모읍니다")

            Spacer(minLength: 8)

            Picker("", selection: $scrumListID) {
                Text("모든 할 일").tag("")
                Divider()
                ForEach(lists) { list in
                    Text("‘\(list.name)’ 목록만").tag(list.id.uuidString)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help("스크럼에 넣을 할 일")

            ChipButton(title: "다시 채우기", icon: "arrow.clockwise") { confirmsRefill = true }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                .fill(DGE.Palette.surface)
        )
    }

    private var scrumDayBinding: Binding<Date> {
        Binding(
            get: { note.scrumDay ?? Date.startOfToday },
            set: { day in
                guard let old = note.scrumDay, !Calendar.current.isDate(old, inSameDayAs: day) else { return }
                NoteStore(context: context).setScrumDay(note, day)
                // 날짜만 옮기고 내용은 그대로 둔다. 새 날짜로 모을지는 사용자가 고른다.
                appState.showToast(
                    "\(day.formatted(.dateTime.month(.wide).day().weekday(.abbreviated))) 스크럼으로 옮겼습니다",
                    actionTitle: "그날 기준으로 다시 채우기"
                ) {
                    NoteStore(context: context).refill(note, listID: UUID(uuidString: scrumListID))
                }
            }
        )
    }

    // MARK: - 줄을 할 일로

    private func makeTasks() {
        let created = NoteStore(context: context).makeTasks(
            from: selectedLines(),
            smartInput: smartInput,
            listNames: lists.map(\.name)
        )
        guard let first = created.first else {
            appState.showToast("할 일로 만들 줄을 고르거나 그 줄에 커서를 두세요")
            return
        }
        let message = created.count == 1
            ? "‘\(first.displayTitle)’ 할 일을 만들었습니다"
            : "할 일 \(created.count)개를 만들었습니다"
        appState.showToast(message, actionTitle: "보기") { appState.reveal(first) }
    }

    /// 고른 부분이 걸친 줄 전체. 고른 것이 없으면 커서가 있는 줄.
    private func selectedLines() -> [String] {
        let text = note.body
        guard !text.isEmpty, let selection else { return [] }

        let picked: Range<String.Index>?
        switch selection.indices {
        case .selection(let range):
            picked = range
        case .multiSelection(let set):
            picked = set.ranges.first
        @unknown default:
            picked = nil
        }
        guard let picked, picked.upperBound <= text.endIndex else { return [] }

        // 세 번 눌러 줄을 고르면 끝의 줄바꿈까지 잡히므로, 그 경우 다음 줄은 빼고 본다.
        var upper = picked.upperBound
        if !picked.isEmpty, upper > text.startIndex, text[text.index(before: upper)] == "\n" {
            upper = text.index(before: upper)
        }
        let start = text[..<picked.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let end = text[upper...].firstIndex(of: "\n") ?? text.endIndex
        guard start <= end else { return [] }
        return text[start..<end].split(separator: "\n").map(String.init)
    }
}

/// "데일리 스크럼"을 눌렀을 때 뜨는 작은 창. 오늘 것을 쓸지, 다음 근무일 것을 미리 준비할지 고른다.
private struct ScrumDayPicker: View {
    let hasScrum: (Date) -> Bool
    let onPick: (Date) -> Void

    @State private var customDay = NoteStore.nextWorkday(after: Date.startOfToday)

    private var today: Date { Date.startOfToday }
    private var nextWorkday: Date { NoteStore.nextWorkday(after: today) }

    /// 오후에는 다음 근무일 스크럼을 준비할 때가 많아서 그쪽을 위에 둔다.
    private var prefersNext: Bool {
        Calendar.current.component(.hour, from: Date()) >= 15
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("어느 날 스크럼을 준비할까요?")
                .font(.dge(size: 12, weight: .semibold))
                .foregroundStyle(DGE.Palette.secondaryText)
                .padding(.bottom, 2)

            if prefersNext {
                nextOption
                todayOption
            } else {
                todayOption
                nextOption
            }

            Rectangle()
                .fill(DGE.Palette.hairline)
                .frame(height: 1)
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                Text("다른 날")
                    .font(.dge(size: 12.5))
                    .foregroundStyle(DGE.Palette.primaryText)
                Spacer(minLength: 0)
                DatePicker("", selection: $customDay, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .fixedSize()
                ChipButton(title: hasScrum(customDay) ? "열기" : "만들기") { onPick(customDay) }
            }
            .padding(.horizontal, 10)

            Text("‘어제 한 일’에는 그 전 근무일에 끝낸 일이, ‘오늘 할 일’에는 그날까지 할 일이 들어갑니다. 미리 만들었다면 당일 아침에 ‘다시 채우기’로 새로 모을 수 있어요.")
                .font(.dge(size: 11))
                .foregroundStyle(DGE.Palette.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.top, 4)
        }
        .padding(12)
        .frame(width: 340)
    }

    private var todayOption: some View {
        ScrumOption(
            icon: "sun.max",
            title: "오늘 스크럼",
            day: today,
            exists: hasScrum(today),
            isSuggested: !prefersNext
        ) { onPick(today) }
    }

    private var nextOption: some View {
        let isTomorrow = Calendar.current.isDateInTomorrow(nextWorkday)
        let name = isTomorrow ? "내일" : nextWorkday.formatted(.dateTime.weekday(.wide))
        return ScrumOption(
            icon: "moon.stars",
            title: "\(name) 스크럼 미리 준비",
            day: nextWorkday,
            exists: hasScrum(nextWorkday),
            isSuggested: prefersNext
        ) { onPick(nextWorkday) }
    }
}

/// 스크럼 날짜 선택지 한 줄. 누르면 바로 그날 메모를 연다.
private struct ScrumOption: View {
    let icon: String
    let title: String
    let day: Date
    let exists: Bool
    let isSuggested: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.dge(size: 13, weight: .medium))
                    .foregroundStyle(isSuggested ? DGE.Palette.accent : DGE.Palette.secondaryText)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.dge(size: 13, weight: .medium))
                        .foregroundStyle(DGE.Palette.primaryText)
                    Text("\(day.formatted(.dateTime.month(.wide).day().weekday(.abbreviated))) · 어제 한 일은 \(previous.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))부터")
                        .font(.dge(size: 11.5))
                        .foregroundStyle(DGE.Palette.secondaryText)
                }

                Spacer(minLength: 8)

                Text(exists ? "열기" : "만들기")
                    .font(DGE.Typography.chip)
                    .foregroundStyle(DGE.Palette.accent)
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.row, style: .continuous)
                    .fill(isHovering ? DGE.Palette.selected : (isSuggested ? DGE.Palette.hover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }

    private var previous: Date {
        NoteStore.previousWorkday(before: day)
    }
}
