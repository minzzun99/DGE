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
    /// 첫 실행 때 넣어두는 기본 목록.
    static let defaultNames = ["개인", "업무", "공부"]

    /// 영어로 만들어 두었던 초기 목록의 이름을 한 번만 바꿔준다.
    static let renamedFromEnglish = ["Personal": "개인", "Work": "업무", "Study": "공부"]
}
