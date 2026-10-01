import Foundation

/// 사이드바에서 선택할 수 있는 화면.
enum SidebarItem: Hashable {
    case inbox
    case today
    case upcoming
    case calendar
    case completed
    case notes
    case list(UUID)
    case tag(String)
}
