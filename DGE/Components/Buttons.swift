import SwiftUI

/// 누르는 동안 살짝 눌려 보이는 plain 버튼.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(DGE.Motion.hover, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// 아이콘 하나짜리 작은 버튼. 평소엔 흐리게 있다가, 마우스를 올리면 옅은 판이 깔린다.
struct IconButton: View {
    let icon: String
    let help: String
    /// 켜져 있는 상태(고정 등)를 계속 보여줘야 할 때.
    var isActive: Bool = false
    var isDestructive: Bool = false
    var width: CGFloat = 22
    var height: CGFloat = 20
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.dge(size: 11, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                        .fill(background)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .help(help)
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }

    private var foreground: Color {
        if isHovering && isDestructive { return DGE.Palette.danger }
        if isActive || isHovering { return DGE.Palette.primaryText }
        return DGE.Palette.secondaryText
    }

    private var background: Color {
        if isHovering && isDestructive { return DGE.Palette.danger.opacity(0.12) }
        if isActive || isHovering { return DGE.Palette.selected }
        return .clear
    }
}

/// 테두리만 있는 작은 글자 버튼. "오늘", "내일" 같은 빠른 선택에 쓴다.
/// 제목을 비우면 아이콘만 보인다.
struct ChipButton: View {
    let title: String
    var icon: String? = nil
    /// 지금 값과 같은 선택지일 때. 회색 판을 깔아 눌린 것처럼 보여준다.
    var isSelected: Bool = false
    var help: String? = nil
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.dge(size: 10, weight: .medium))
                }
                if !title.isEmpty {
                    Text(title)
                }
            }
            .font(DGE.Typography.chip)
            .foregroundStyle(isSelected || isHovering ? DGE.Palette.primaryText : DGE.Palette.secondaryText)
            .padding(.horizontal, title.isEmpty ? 6 : 8)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.chip + 1, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DGE.Radius.chip + 1, style: .continuous)
                    .strokeBorder(DGE.Palette.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        // 글자가 잘리면 무슨 버튼인지 알 수 없다. 늘 제 폭을 쓴다.
        .fixedSize()
        .help(help ?? title)
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
        .animation(DGE.Motion.hover, value: isSelected)
    }

    private var background: Color {
        if isSelected { return DGE.Palette.selected }
        return isHovering ? DGE.Palette.hover : Color.clear
    }
}
