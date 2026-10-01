import SwiftUI

/// 할 일을 끝내는 체크 버튼. 누르는 순간만 짧게 반응한다.
/// 마우스를 올리면 흐린 체크가 미리 보인다. 메인 창과 메뉴바가 같은 모양을 쓴다.
struct Checkbox: View {
    let isChecked: Bool
    var size: CGFloat = DGE.Size.checkbox
    /// 체크 전 테두리 색. 기한이 지난 할 일처럼 눈에 띄어야 할 때만 넘긴다.
    var tint: Color? = nil
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(strokeColor, lineWidth: 1.3)
                    .opacity(isChecked ? 0 : 1)

                Circle()
                    .fill(DGE.Palette.accent)
                    .opacity(isChecked ? 1 : 0)

                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(isChecked ? Color.white : DGE.Palette.tertiaryText)
                    .opacity(isChecked || isHovering ? 1 : 0)
            }
            .frame(width: size, height: size)
            .scaleEffect(isChecked ? 1.06 : 1)
            .contentShape(Circle())
            .animation(DGE.Motion.check, value: isChecked)
            .animation(DGE.Motion.hover, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(isChecked ? "완료 취소" : "완료")
    }

    private var strokeColor: Color {
        if let tint { return tint }
        return Color.primary.opacity(isHovering ? 0.55 : 0.3)
    }
}
