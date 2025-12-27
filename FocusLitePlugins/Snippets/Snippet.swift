import Foundation

struct Snippet: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var keyword: String
    var content: String
    var tags: [String]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        keyword: String = "",
        content: String,
        tags: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.keyword = keyword
        self.content = content
        self.tags = tags
        self.updatedAt = updatedAt
    }
}
