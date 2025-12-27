import Foundation

struct ResultItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String?
    let icon: ItemIcon?
    let score: Double
    let action: ResultAction
    let providerID: String
    let category: ResultCategory
    let isPrefix: Bool
    let preview: ResultPreview?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        icon: ItemIcon? = nil,
        score: Double = 0,
        action: ResultAction = .none,
        providerID: String = "unknown",
        category: ResultCategory = .standard,
        isPrefix: Bool = false,
        preview: ResultPreview? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.score = score
        self.action = action
        self.providerID = providerID
        self.category = category
        self.isPrefix = isPrefix
        self.preview = preview
    }
}

enum ItemIcon: Hashable, Sendable {
    case system(String)
    case bundle(String)
    case filePath(String)
}

enum ResultAction: Hashable, Sendable {
    case none
    case openURL(URL)
    case copyText(String)
    case pasteText(String)
    case runApp(bundleID: String)
    case copyImage(data: Data, type: String)
    case copyFiles([String])
}

enum ResultCategory: Int, Hashable, Sendable {
    case calc = 0
    case standard = 1
}

enum ResultPreview: Hashable, Sendable {
    case text(String)
    case image(Data)
    case files([FilePreviewItem])
}

struct FilePreviewItem: Codable, Hashable, Sendable {
    let path: String
    let name: String
}
