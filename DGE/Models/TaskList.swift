import Foundation
import SwiftData

/// 사용자가 만든 목록. MVP에서는 이름과 순서만 갖는다.
@Model
final class TaskList {
    var id: UUID = UUID()
    var name: String = ""
    var order: Int = 0

    init(name: String, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.order = order
    }
}

extension TaskList {
    /// 날짜도 목록도 정하지 않은 할 일이 들어가는 '할 일' 목록.
    /// ⌘1 · 시작 화면 · 백업 어디서나 같은 목록을 가리키도록 id를 고정한다.
    static let defaultID = UUID(uuidString: "D6E00000-0000-4000-8000-000000000001")!
    static let defaultListName = "할 일"

    /// 지울 수 없는 기본 목록인지. 이름은 바꿀 수 있다.
    var isDefault: Bool { id == Self.defaultID }

    /// 첫 실행 때 넣어두는 기본 목록.
    static let defaultNames = ["개인", "업무", "공부"]

    /// 영어로 만들어 두었던 초기 목록의 이름을 한 번만 바꿔준다.
    static let renamedFromEnglish = ["Personal": "개인", "Work": "업무", "Study": "공부"]
}
