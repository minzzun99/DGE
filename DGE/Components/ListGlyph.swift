import SwiftUI

/// 목록을 나타내는 작은 네모. 이름 첫 글자를 넣어 색 없이도 구분되게 한다.
struct ListGlyph: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.62, weight: .semibold))
            .foregroundStyle(DGE.Palette.secondaryText)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(DGE.Palette.selected)
            )
            .accessibilityHidden(true)
    }

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "·"
    }
}

/// 할 일 줄 오른쪽에 붙는 목록 표시.
struct ListTag: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            ListGlyph(name: name, size: 13)
            Text(name)
                .font(DGE.Typography.chip)
                .foregroundStyle(DGE.Palette.secondaryText)
                .lineLimit(1)
        }
        .padding(.leading, 3)
        .padding(.trailing, 7)
        .frame(height: 20)
        .overlay(
            RoundedRectangle(cornerRadius: DGE.Radius.chip + 1, style: .continuous)
                .strokeBorder(DGE.Palette.border, lineWidth: 1)
        )
        // 이름이 잘리면 무슨 목록인지 알 수 없으므로 늘 제 폭을 쓴다.
        .fixedSize()
    }
}
