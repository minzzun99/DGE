import SwiftUI
import SwiftData

/// 할 일에 붙은 태그를 보여주고 고친다. 적다 보면 이미 쓰는 태그를 추천한다.
struct TagEditor: View {
    @Bindable var task: TodoTask
    /// 다른 할 일에서 쓰고 있는 태그. 추천에 쓴다.
    let knownTags: [String]
    let onChange: () -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    private var suggestions: [String] {
        let query = draft.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        return knownTags
            .filter { !task.tags.contains($0) }
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(task.tags, id: \.self) { tag in
                    TagToken(tag: tag) { remove(tag) }
                }

                TextField(task.tags.isEmpty ? "태그 추가" : "추가", text: $draft)
                    .textFieldStyle(.plain)
                    .font(DGE.Typography.propertyValue)
                    .frame(width: 70)
                    .focused($isFocused)
                    .onSubmit(add)
            }
            .padding(.vertical, 5)

            if isFocused, !suggestions.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(suggestions, id: \.self) { tag in
                        ChipButton(title: "#\(tag)") { add(tag) }
                    }
                }
            }
        }
    }

    private func add() {
        add(draft)
    }

    private func add(_ raw: String) {
        let name = raw.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
        draft = ""
        guard !name.isEmpty, !task.tags.contains(name) else { return }
        task.tags.append(name)
        onChange()
    }

    private func remove(_ tag: String) {
        task.tags.removeAll { $0 == tag }
        onChange()
    }
}

/// 태그 하나. 마우스를 올리면 지우는 ×가 뜬다.
private struct TagToken: View {
    let tag: String
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 3) {
            Text("#\(tag)")
                .font(DGE.Typography.chip)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.dge(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.4)
            .help("태그 빼기")
        }
        .foregroundStyle(DGE.Palette.primaryText)
        .padding(.leading, 7)
        .padding(.trailing, 5)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.chip + 1, style: .continuous)
                .fill(DGE.Palette.selected)
        )
        .fixedSize()
        .onHover { isHovering = $0 }
    }
}

/// 할 일 안의 작은 단계들. 체크하고, 고쳐 쓰고, 지운다.
struct ChecklistEditor: View {
    @Bindable var task: TodoTask
    let onChange: () -> Void

    @State private var draft = ""
    @FocusState private var focusedItem: UUID?
    @FocusState private var isAdding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(task.checklist) { item in
                ChecklistRow(
                    item: binding(for: item),
                    onDelete: { delete(item) },
                    onSubmit: { isAdding = true }
                )
                .focused($focusedItem, equals: item.id)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.dge(size: 10, weight: .semibold))
                    .foregroundStyle(isAdding ? DGE.Palette.accent : DGE.Palette.tertiaryText)
                    .frame(width: 14, height: 14)
                TextField("단계 추가", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.dge(size: 12.5))
                    .focused($isAdding)
                    .onSubmit(add)
            }
            .padding(.horizontal, 6)
            .frame(height: 26)
        }
    }

    private func binding(for item: ChecklistItem) -> Binding<ChecklistItem> {
        Binding(
            get: { task.checklist.first { $0.id == item.id } ?? item },
            set: { updated in
                var items = task.checklist
                guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
                items[index] = updated
                task.checklist = items
                onChange()
            }
        )
    }

    private func add() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        task.checklist.append(ChecklistItem(title: title))
        draft = ""
        isAdding = true
        onChange()
    }

    private func delete(_ item: ChecklistItem) {
        task.checklist.removeAll { $0.id == item.id }
        onChange()
    }
}

private struct ChecklistRow: View {
    @Binding var item: ChecklistItem
    let onDelete: () -> Void
    let onSubmit: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Checkbox(isChecked: item.isDone, size: 14) {
                item.isDone.toggle()
            }

            TextField("", text: $item.title)
                .textFieldStyle(.plain)
                .font(.dge(size: 12.5))
                .foregroundStyle(item.isDone ? DGE.Palette.secondaryText : DGE.Palette.primaryText)
                .strikethrough(item.isDone, color: DGE.Palette.secondaryText)
                .onSubmit(onSubmit)

            IconButton(icon: "xmark", help: "단계 지우기", width: 18, height: 18, action: onDelete)
                .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 6)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.control, style: .continuous)
                .fill(isHovering ? DGE.Palette.hover : Color.clear)
        )
        .onHover { isHovering = $0 }
    }
}
