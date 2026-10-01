import SwiftUI
import AppKit

/// 설정의 '테마'. 강조색과 바탕의 옅은 색조를 함께 바꾼다.
/// 바탕은 어느 테마든 거의 무채색에 가깝게 두고, 색은 강조색에만 싣는다.
enum ThemeSetting: String, CaseIterable, Identifiable {
    case standard, ocean, forest, blossom, lavender, paper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "기본"
        case .ocean: "바다"
        case .forest: "숲"
        case .blossom: "벚꽃"
        case .lavender: "라벤더"
        case .paper: "종이"
        }
    }

    var accent: Color {
        switch self {
        case .standard: Color.accentColor
        case .ocean: Color(light: .rgb(0.05, 0.55, 0.62), dark: .rgb(0.30, 0.78, 0.84))
        case .forest: Color(light: .rgb(0.20, 0.56, 0.33), dark: .rgb(0.42, 0.80, 0.53))
        case .blossom: Color(light: .rgb(0.85, 0.29, 0.47), dark: .rgb(1.00, 0.52, 0.66))
        case .lavender: Color(light: .rgb(0.47, 0.35, 0.85), dark: .rgb(0.67, 0.58, 1.00))
        case .paper: Color(light: .rgb(0.60, 0.42, 0.24), dark: .rgb(0.85, 0.67, 0.47))
        }
    }

    /// 본문 바탕.
    var canvas: Color {
        switch self {
        case .standard: Color(light: NSColor(white: 1, alpha: 1), dark: NSColor(white: 0.115, alpha: 1))
        case .ocean: Color(light: .rgb(0.976, 0.988, 0.992), dark: .rgb(0.100, 0.122, 0.132))
        case .forest: Color(light: .rgb(0.984, 0.988, 0.976), dark: .rgb(0.105, 0.120, 0.110))
        case .blossom: Color(light: .rgb(1.000, 0.984, 0.988), dark: .rgb(0.125, 0.110, 0.115))
        case .lavender: Color(light: .rgb(0.988, 0.984, 1.000), dark: .rgb(0.115, 0.110, 0.132))
        case .paper: Color(light: .rgb(0.984, 0.972, 0.945), dark: .rgb(0.130, 0.120, 0.105))
        }
    }

    /// 입력창 · 칩 · 아이콘 타일처럼 바탕에서 한 겹 올라온 면.
    var surface: Color {
        switch self {
        case .standard: Color(light: NSColor(white: 0.965, alpha: 1), dark: NSColor(white: 0.16, alpha: 1))
        case .ocean: Color(light: .rgb(0.933, 0.957, 0.965), dark: .rgb(0.145, 0.170, 0.180))
        case .forest: Color(light: .rgb(0.941, 0.953, 0.933), dark: .rgb(0.150, 0.170, 0.155))
        case .blossom: Color(light: .rgb(0.973, 0.941, 0.949), dark: .rgb(0.175, 0.155, 0.162))
        case .lavender: Color(light: .rgb(0.949, 0.941, 0.973), dark: .rgb(0.160, 0.155, 0.180))
        case .paper: Color(light: .rgb(0.945, 0.925, 0.882), dark: .rgb(0.180, 0.165, 0.145))
        }
    }

    /// 사이드바에 얹는 아주 옅은 색. 기본 테마는 시스템 사이드바를 그대로 둔다.
    var sidebarTint: Color {
        self == .standard ? .clear : accent.opacity(0.05)
    }
}

/// 설정의 '텍스트 크기'. 화면 글자 전체에 같은 배율을 곱한다.
enum TextSizeSetting: String, CaseIterable, Identifiable {
    case small, standard, large, extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "작게"
        case .standard: "기본"
        case .large: "크게"
        case .extraLarge: "아주 크게"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: 0.92
        case .standard: 1
        case .large: 1.12
        case .extraLarge: 1.25
        }
    }

    /// 시스템이 그리는 사이드바 목록도 같은 방향으로 맞춘다.
    var sidebarRowSize: SidebarRowSize {
        switch self {
        case .small: .small
        case .standard: .medium
        case .large, .extraLarge: .large
        }
    }
}

/// 지금 고른 테마와 텍스트 크기. `DGE.Palette`와 `DGE.Typography`가 여기서 값을 읽는다.
/// 뷰가 그리는 도중에 읽으므로, 값이 바뀌면 그 값을 쓴 뷰만 다시 그려진다.
@Observable
final class AppearanceStore {
    static let shared = AppearanceStore()

    var theme: ThemeSetting {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: SettingsKey.theme) }
    }

    var textSize: TextSizeSetting {
        didSet { UserDefaults.standard.set(textSize.rawValue, forKey: SettingsKey.textSize) }
    }

    var textScale: CGFloat { textSize.scale }

    private init() {
        let defaults = UserDefaults.standard
        theme = ThemeSetting(rawValue: defaults.string(forKey: SettingsKey.theme) ?? "") ?? .standard
        textSize = TextSizeSetting(rawValue: defaults.string(forKey: SettingsKey.textSize) ?? "") ?? .standard
    }
}

extension Font {
    /// 설정의 '텍스트 크기'를 따르는 시스템 글꼴. 화면에 쓰는 글자는 모두 이걸로 만든다.
    static func dge(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * AppearanceStore.shared.textScale, weight: weight)
    }
}

extension NSColor {
    fileprivate static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

extension View {
    /// 창마다 한 번 붙인다. 시스템 컨트롤(토글 · 버튼 등)의 강조색과 사이드바 크기를 설정에 맞춘다.
    func dgeAppearance() -> some View {
        modifier(AppearanceModifier())
    }
}

private struct AppearanceModifier: ViewModifier {
    func body(content: Content) -> some View {
        let store = AppearanceStore.shared
        content
            .tint(store.theme.accent)
            .environment(\.sidebarRowSize, store.textSize.sidebarRowSize)
    }
}
