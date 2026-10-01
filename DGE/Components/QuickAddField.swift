import SwiftUI
import SwiftData

/// 좁은 곳에 쓰는 한 줄 입력. 적고 Enter를 누르면 할 일이 된다.
/// 메인 입력창처럼 "내일", "#태그" 같은 말을 알아듣는다.
struct QuickAddField: View {
    var placeholder: String = "오늘 할 일 추가"
    let onSubmit: (ParsedTask) -> Void

    @Query(sort: \TaskList.order) private var lists: [TaskList]
    @AppStorage(SettingsKey.smartInput) private var smartInput = true
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    private var parsed: ParsedTask {
        guard smartInput else {
            return ParsedTask(title: draft.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return QuickAddParser.parse(draft, listNames: lists.map(\.name))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.dge(size: 10, weight: .semibold))
                    .foregroundStyle(isFocused ? DGE.Palette.accent : DGE.Palette.tertiaryText)
                    .frame(width: 14, height: 14)

                TextField(placeholder, text: $draft)
                    .textFieldStyle(.plain)
                    .font(.dge(size: 12.5))
                    .focused($isFocused)
                    .onSubmit(submit)

                if !draft.isEmpty {
                    KeyHint("↵")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                    .fill(DGE.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                    .strokeBorder(isFocused ? DGE.Palette.accent.opacity(0.55) : DGE.Palette.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }

            if !draft.isEmpty, parsed.hasHints {
                ScrollView(.horizontal, showsIndicators: false) {
                    ParseHints(parsed: parsed)
                }
            }
        }
        .animation(DGE.Motion.hover, value: isFocused)
    }

    private func submit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(parsed)
        draft = ""
        // 연달아 적을 수 있게 포커스를 유지한다.
        isFocused = true
    }
}
