import SwiftUI

/// 단축키를 알려주는 작은 키캡. 누를 수는 없고 보여주기만 한다.
struct KeyHint: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(DGE.Typography.keyHint)
            .foregroundStyle(DGE.Palette.tertiaryText)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 17)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DGE.Palette.hover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(DGE.Palette.hairline, lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}
