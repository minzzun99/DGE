import SwiftUI

/// 창 아래쪽에 잠깐 뜨는 안내. 되돌릴 수 있는 동작 뒤에 "실행 취소"를 붙인다.
struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .font(.dge(size: 12.5))
                .foregroundStyle(DGE.Palette.primaryText)
                .lineLimit(1)

            if let actionTitle = toast.actionTitle, let action = toast.action {
                Button {
                    action()
                    onDismiss()
                } label: {
                    Text(actionTitle)
                        .font(.dge(size: 12.5, weight: .semibold))
                        .foregroundStyle(DGE.Palette.accent)
                }
                .buttonStyle(.pressable)
            }

            IconButton(icon: "xmark", help: "닫기", width: 18, height: 18, action: onDismiss)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.composer, style: .continuous)
                .fill(DGE.Palette.canvas)
                .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DGE.Radius.composer, style: .continuous)
                .strokeBorder(DGE.Palette.border, lineWidth: 1)
        )
    }
}
