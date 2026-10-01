import SwiftUI
import AppKit

/// DGE의 디자인 토큰.
/// 바탕은 무채색으로 깔고, 강조색은 체크 · 포커스 · 오늘 표시처럼 꼭 필요한 곳에만 쓴다.
/// 선택이나 hover 같은 상태는 색이 아니라 회색의 농도로 구분한다.
/// 강조색 · 바탕 · 글자 크기는 설정의 테마와 텍스트 크기를 따른다. (`AppearanceStore`)
enum DGE {
    enum Spacing {
        static let rowVertical: CGFloat = 7
        static let rowHorizontal: CGFloat = 10
        /// 본문 좌우 최소 여백. 창이 넓어지면 `Size.contentMaxWidth`에 맞춰 더 벌어진다.
        static let screenHorizontal: CGFloat = 32
        static let screenTop: CGFloat = 22
        static let headerBottom: CGFloat = 18
    }

    enum Radius {
        static let row: CGFloat = 8
        static let chip: CGFloat = 5
        static let control: CGFloat = 7
        static let field: CGFloat = 8
        /// 입력창처럼 한 덩어리로 보여야 하는 곳.
        static let composer: CGFloat = 12
        static let container: CGFloat = 12
    }

    enum Size {
        static var checkbox: CGFloat { (16 * AppearanceStore.shared.textScale).rounded() }
        static let calendarCellMinHeight: CGFloat = 96
        /// 할 일 목록이 이보다 넓어지면 가운데로 모은다. 줄이 너무 길면 눈이 따라가기 어렵다.
        static let contentMaxWidth: CGFloat = 860
    }

    enum Palette {
        static var accent: Color { AppearanceStore.shared.theme.accent }
        static var accentSoft: Color { accent.opacity(0.13) }

        /// 본문 바탕.
        static var canvas: Color { AppearanceStore.shared.theme.canvas }
        /// 입력창 · 칩 · 아이콘 타일처럼 바탕에서 한 겹 올라온 면.
        static var surface: Color { AppearanceStore.shared.theme.surface }

        static let hover = Color.primary.opacity(0.045)
        static let selected = Color.primary.opacity(0.075)

        /// 영역을 나누는 가는 선.
        static let hairline = Color.primary.opacity(0.08)
        /// 입력창 · 버튼 테두리. 선보다 한 단계 진하다.
        static let border = Color.primary.opacity(0.12)
        static let gridLine = Color.primary.opacity(0.07)

        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(nsColor: .tertiaryLabelColor)

        static let overdue = Color(light: NSColor(srgbRed: 0.84, green: 0.36, blue: 0.12, alpha: 1),
                                   dark: NSColor(srgbRed: 1.0, green: 0.56, blue: 0.34, alpha: 1))
        static let danger = Color(nsColor: .systemRed)
    }

    enum Typography {
        static var screenTitle: Font { .dge(size: 20, weight: .semibold) }
        static var screenSubtitle: Font { .dge(size: 12, weight: .regular) }
        static var sectionTitle: Font { .dge(size: 12, weight: .semibold) }
        static var taskTitle: Font { .dge(size: 13, weight: .regular) }
        static var meta: Font { .dge(size: 11.5, weight: .regular) }
        /// 개수처럼 자릿수가 바뀌어도 폭이 흔들리면 안 되는 숫자.
        static var count: Font { .dge(size: 11.5, weight: .medium).monospacedDigit() }
        static var panelTitle: Font { .dge(size: 16, weight: .semibold) }
        static var propertyLabel: Font { .dge(size: 12, weight: .regular) }
        static var propertyValue: Font { .dge(size: 12.5, weight: .regular) }
        static var calendarDayNumber: Font { .dge(size: 12, weight: .medium).monospacedDigit() }
        static var calendarWeekday: Font { .dge(size: 11, weight: .medium) }
        static var chip: Font { .dge(size: 11, weight: .medium) }
        static var keyHint: Font { .dge(size: 10.5, weight: .medium) }
    }

    enum Motion {
        /// 완료 체크가 눌릴 때. 과하지 않게 한 번만 반응한다.
        static let check = Animation.spring(response: 0.26, dampingFraction: 0.72)
        /// 목록에서 사라지고 나타날 때.
        static let list = Animation.easeInOut(duration: 0.22)
        /// hover처럼 자주 바뀌는 상태. 목록 애니메이션보다 짧게.
        static let hover = Animation.easeOut(duration: 0.12)
        /// 완료 표시를 눈으로 확인할 수 있게 잠깐 남겨두는 시간.
        static let completionHold: Duration = .milliseconds(380)
    }
}

extension Color {
    /// 라이트 / 다크 모드에서 각각 다른 값을 쓰는 색.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}
