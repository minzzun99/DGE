import SwiftUI
import SwiftData

/// 할 일을 적고 Enter만 누르면 끝나는 입력창. Modal을 열지 않는다.
/// "내일 오후 3시 보고서 #업무 !!"처럼 적으면 날짜 · 알림 · 태그 · 우선순위를 알아듣고,
/// 알아들은 것은 입력창 아래에 미리 보여준다.
struct TaskInput: View {
    let placeholder: String
    /// 값이 바뀌면 포커스를 가져온다. (⌘N)
    var focusRequest: Int = 0
    let onSubmit: (ParsedTask) -> Void

    @Query(sort: \TaskList.order) private var lists: [TaskList]
    @AppStorage(SettingsKey.smartInput) private var smartInput = true
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var parsed: ParsedTask {
        guard smartInput else {
            return ParsedTask(title: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return QuickAddParser.parse(text, listNames: lists.map(\.name))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            composer

            if hasText, parsed.hasHints {
                ParseHints(parsed: parsed)
                    .padding(.leading, DGE.Spacing.rowHorizontal + DGE.Size.checkbox + 10)
            }
        }
        .animation(DGE.Motion.hover, value: parsed.hasHints && hasText)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.dge(size: 11, weight: .semibold))
                .foregroundStyle(isFocused ? DGE.Palette.accent : DGE.Palette.tertiaryText)
                .frame(width: DGE.Size.checkbox, height: DGE.Size.checkbox)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DGE.Typography.taskTitle)
                .focused($isFocused)
                .onSubmit(submit)

            // 지금 누르면 되는 키만 알려준다.
            if hasText {
                KeyHint("↵")
            } else if !isFocused {
                KeyHint("⌘N")
            }
        }
        .padding(.horizontal, DGE.Spacing.rowHorizontal)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.composer, style: .continuous)
                .fill(DGE.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DGE.Radius.composer, style: .continuous)
                .strokeBorder(isFocused ? DGE.Palette.accent.opacity(0.55) : DGE.Palette.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .animation(DGE.Motion.hover, value: isFocused)
        .animation(DGE.Motion.hover, value: hasText)
        .onChange(of: focusRequest) { _, _ in
            isFocused = true
        }
        .onExitCommand {
            text = ""
            isFocused = false
        }
    }

    private func submit() {
        guard hasText else {
            isFocused = false
            return
        }
        onSubmit(parsed)
        text = ""
        // 연달아 적을 수 있게 포커스를 유지한다.
        isFocused = true
    }
}
