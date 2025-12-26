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

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        icon: ItemIcon? = nil,
        score: Double = 0,
        action: ResultAction = .none,
        providerID: String = "unknown",
        category: ResultCategory = .standard
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.score = score
        self.action = action
        self.providerID = providerID
        self.category = category
    }
}

enum ItemIcon: Hashable, Sendable {
    case system(String)
    case bundle(String)
}

enum ResultAction: Hashable, Sendable {
    case none
    case openURL(URL)
    case copyText(String)
    case runApp(bundleID: String)
}

enum ResultCategory: Int, Hashable, Sendable {
    case calc = 0
    case standard = 1
}
