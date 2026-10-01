import Foundation
import SwiftData

/// 할 일이 아닌 글. 회의 메모, 생각 정리, 데일리 스크럼에서 할 말 같은 것.
///
/// 할 일처럼 끝내는 것이 아니라 적어 두고 다시 보는 것이라 따로 둔다.
/// 모든 저장 프로퍼티에 기본값을 두어 가벼운 마이그레이션으로 넘어가게 한다.
@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPinned: Bool = false
    /// 데일리 스크럼 메모면 그날 0시. 보통 메모는 nil.
    var scrumDay: Date?

    init(title: String = "", body: String = "", scrumDay: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
        self.scrumDay = scrumDay
    }
}

extension Note {
    var isScrum: Bool {
        scrumDay != nil
    }

    /// 제목이 없으면 본문 첫 줄을 쓴다.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return lines.first ?? "새 메모"
    }

    /// 목록에 한 줄로 보여줄 본문 앞부분. 제목으로 쓴 줄은 뺀다.
    var preview: String {
        let usesFirstLine = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rest = usesFirstLine ? Array(lines.dropFirst()) : lines
        return rest.prefix(3).joined(separator: " · ")
    }

    /// 비어 있지 않은 줄들. 글머리표는 뗀다.
    private var lines: [String] {
        body.split(separator: "\n")
            .map { NoteStore.stripBullet(String($0)) }
            .filter { !$0.isEmpty }
    }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(query) || body.localizedCaseInsensitiveContains(query)
    }
}
