import SwiftUI

/// 좁은 곳에 쓰는 할 일 한 줄. 메뉴바와 미니 창이 같이 쓴다.
/// 메인 창의 `TaskRow`보다 촘촘하고, 체크만 할 수 있다.
struct CompactTaskRow: View {
    let task: TodoTask
    let isChecked: Bool
    let onToggle: () -> Void
    var onPostpone: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Checkbox(
                isChecked: isChecked,
                size: 14,
                tint: task.isOverdue && !isChecked ? DGE.Palette.overdue : nil,
                action: onToggle
            )
            .padding(.top, 1)

            Text(task.displayTitle)
                .font(.dge(size: 12.5))
                .foregroundStyle(isChecked ? DGE.Palette.secondaryText : DGE.Palette.primaryText)
                .strikethrough(isChecked, color: DGE.Palette.secondaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.control, style: .continuous)
                .fill(isHovering ? DGE.Palette.hover : Color.clear)
        )
        .contentShape(Rectangle())
        .contextMenu {
            if let onPostpone {
                Button("내일로 미루기", action: onPostpone)
            }
        }
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}
