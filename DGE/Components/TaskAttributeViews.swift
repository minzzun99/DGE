import SwiftUI

/// 우선순위를 막대 세 개로. 높음만 주황으로 눈에 띄게 한다.
struct PriorityGlyph: View {
    let priority: Priority

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(1...3, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(level <= priority.rawValue ? filled : DGE.Palette.border)
                    .frame(width: 3, height: CGFloat(3 + level * 2))
            }
        }
        .frame(height: 9, alignment: .bottom)
        .help("우선순위 \(priority.title)")
        .accessibilityLabel("우선순위 \(priority.title)")
    }

    private var filled: Color {
        priority == .high ? DGE.Palette.overdue : DGE.Palette.secondaryText
    }
}

/// "#업무"처럼 글자만 있는 가벼운 태그 표시.
struct TagLabel: View {
    let tag: String

    var body: some View {
        Text("#\(tag)")
            .font(DGE.Typography.chip)
            .foregroundStyle(DGE.Palette.secondaryText)
            .lineLimit(1)
            .fixedSize()
    }
}

/// 입력창에서 알아들은 것을 보여주는 작은 칩 줄. 적는 동안 결과를 미리 본다.
struct ParseHints: View {
    let parsed: ParsedTask

    var body: some View {
        HStack(spacing: 6) {
            if let dueDate = parsed.dueDate {
                hint("calendar", dueDate.dgeDayTitle)
            }
            if let remindAt = parsed.remindAt {
                hint("bell", remindAt.dgeTimeText)
            }
            if let rule = parsed.repeatRule {
                hint("arrow.clockwise", rule.title)
            }
            if parsed.priority != .none {
                HStack(spacing: 4) {
                    PriorityGlyph(priority: parsed.priority)
                    Text(parsed.priority.title)
                }
                .modifier(HintChip())
            }
            ForEach(parsed.tags, id: \.self) { tag in
                Text("#\(tag)").modifier(HintChip())
            }
            if let list = parsed.listName {
                HStack(spacing: 4) {
                    ListGlyph(name: list, size: 12)
                    Text(list)
                }
                .modifier(HintChip())
            }
        }
        .transition(.opacity)
    }

    private func hint(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.dge(size: 9.5, weight: .semibold))
            Text(text)
        }
        .modifier(HintChip())
    }
}

private struct HintChip: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DGE.Typography.chip)
            .foregroundStyle(DGE.Palette.accent)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: DGE.Radius.chip, style: .continuous)
                    .fill(DGE.Palette.accentSoft)
            )
            .fixedSize()
    }
}

/// 칩처럼 폭이 제각각인 것들을 줄 바꿈하며 늘어놓는다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        let used = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? used, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
