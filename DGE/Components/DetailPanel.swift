import SwiftUI

/// 오른쪽에서 열리는 상세 패널의 껍데기.
/// 할 일과 일정이 같은 모양을 쓰도록 여기 한 곳에만 둔다.
struct DetailPanel<Content: View>: View {
    /// 패널 맨 위에 작게 붙는 종류 이름. ("할 일", "일정")
    let kind: String
    let icon: String
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.dge(size: 11, weight: .medium))
                Text(kind)
                    .font(.dge(size: 12, weight: .medium))
                Spacer(minLength: 0)
                IconButton(icon: "xmark", help: "닫기", action: onClose)
            }
            .foregroundStyle(DGE.Palette.secondaryText)
            .padding(.leading, 18)
            .padding(.trailing, 12)
            .frame(height: 40)

            Rectangle()
                .fill(DGE.Palette.hairline)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .onExitCommand(perform: onClose)
    }
}

/// 패널 안의 속성 한 줄. 왼쪽에 이름, 오른쪽에 값.
struct PropertyRow<Content: View>: View {
    let label: String
    let icon: String
    @ViewBuilder var content: () -> Content

    init(_ label: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.icon = icon
        self.content = content
    }

    var body: some View {
        // 값이 여러 줄이어도 이름은 첫 줄에 맞춘다.
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.dge(size: 11, weight: .regular))
                    .frame(width: 14)
                Text(label)
                    .font(DGE.Typography.propertyLabel)
            }
            .foregroundStyle(DGE.Palette.secondaryText)
            .frame(width: 78, height: 28, alignment: .leading)

            content()
                .font(DGE.Typography.propertyValue)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        }
    }
}

/// 패널 안의 넓은 칸. 이름이 위, 내용이 아래. (메모처럼 길게 적는 곳)
struct DetailField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(DGE.Typography.sectionTitle)
                .foregroundStyle(DGE.Palette.secondaryText)
            content()
        }
    }
}

/// 패널 안을 가로지르는 가는 선.
struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(DGE.Palette.hairline)
            .frame(height: 1)
    }
}

extension View {
    /// 입력칸에 깔리는 옅은 면과 테두리.
    func dgeFieldBackground(padding: CGFloat = 7) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                    .fill(DGE.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                    .strokeBorder(DGE.Palette.border, lineWidth: 1)
            )
    }
}

/// 패널 맨 아래에 놓는 삭제 버튼.
struct DeleteButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: "trash")
                .font(.dge(size: 12))
                .foregroundStyle(DGE.Palette.danger)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: DGE.Radius.control, style: .continuous)
                        .fill(isHovering ? DGE.Palette.danger.opacity(0.1) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .padding(.leading, -8)
        .onHover { isHovering = $0 }
        .animation(DGE.Motion.hover, value: isHovering)
    }
}
