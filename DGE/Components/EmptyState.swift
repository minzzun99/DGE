import SwiftUI

/// 목록이 비었을 때 가운데에 놓는 안내. 아이콘 타일 · 한 줄 제목 · 짧은 도움말.
struct EmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.dge(size: 17, weight: .regular))
                .foregroundStyle(DGE.Palette.tertiaryText)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: DGE.Radius.container, style: .continuous)
                        .fill(DGE.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DGE.Radius.container, style: .continuous)
                        .strokeBorder(DGE.Palette.hairline, lineWidth: 1)
                )
                .padding(.bottom, 14)

            Text(title)
                .font(.dge(size: 13.5, weight: .medium))
                .foregroundStyle(DGE.Palette.primaryText)

            if let message {
                Text(message)
                    .font(.dge(size: 12))
                    .foregroundStyle(DGE.Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        // 정가운데보다 조금 위에 있어야 눈에는 가운데로 보인다.
        .padding(.bottom, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
