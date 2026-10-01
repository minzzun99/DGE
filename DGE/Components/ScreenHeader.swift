import SwiftUI

/// 화면 맨 위의 제목 줄.
/// 왼쪽은 아이콘 · 제목 · 개수 · 부제목, 오른쪽에는 화면마다 다른 도구가 들어간다.
struct ScreenHeader<Trailing: View>: View {
    let icon: String
    let title: String
    var count: Int? = nil
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.dge(size: 13, weight: .medium))
                .foregroundStyle(DGE.Palette.secondaryText)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                        .fill(DGE.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                        .strokeBorder(DGE.Palette.hairline, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(DGE.Typography.screenTitle)
                        .foregroundStyle(DGE.Palette.primaryText)

                    if let count, count > 0 {
                        Text("\(count)")
                            .font(DGE.Typography.count)
                            .foregroundStyle(DGE.Palette.tertiaryText)
                            .contentTransition(.numericText())
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(DGE.Typography.screenSubtitle)
                        .foregroundStyle(DGE.Palette.secondaryText)
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
        .animation(DGE.Motion.list, value: count)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(icon: String, title: String, count: Int? = nil, subtitle: String? = nil) {
        self.init(icon: icon, title: title, count: count, subtitle: subtitle) { EmptyView() }
    }
}

/// 오늘 얼마나 끝냈는지. 가는 막대와 "2/5"만 보여준다.
struct ProgressSummary: View {
    let done: Int
    let total: Int

    private let barWidth: CGFloat = 72

    private var fraction: CGFloat {
        total == 0 ? 0 : CGFloat(done) / CGFloat(total)
    }

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(DGE.Palette.selected)
                .frame(width: barWidth, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(DGE.Palette.accent)
                        .frame(width: barWidth * fraction)
                }

            Text("\(done)/\(total)")
                .font(DGE.Typography.count)
                .foregroundStyle(DGE.Palette.secondaryText)
                .contentTransition(.numericText())
        }
        .animation(DGE.Motion.list, value: done)
        .animation(DGE.Motion.list, value: total)
        .help("오늘 끝낸 일 \(done)개 · 남은 일 \(total - done)개")
    }
}
