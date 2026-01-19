import Foundation

struct WebSearchProvider: ResultProvider {
    static let providerID = "web_search"
    let id = WebSearchProvider.providerID
    let displayName = "Web Search"

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        guard WebSearchPreferences.isEnabled else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let questionLeading = trimmed.hasPrefix("?") || trimmed.hasPrefix("？")
        let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: " ?？"))
        if cleaned.isEmpty && !questionLeading {
            return []
        }
        guard isScoped || WebSearchPreferences.showFallback else { return [] }

        if cleaned.isEmpty && questionLeading {
            return [
                ResultItem(
                    title: "输入内容以在浏览器中搜索",
                    subtitle: "请输入关键词后回车",
                    icon: .system("magnifyingglass.circle.fill"),
                    score: 1.2,
                    action: .none,
                    providerID: id,
                    category: .standard
                )
            ]
        }

        guard let url = WebSearchPreferences.searchURL(for: cleaned) else { return [] }

        return [
            ResultItem(
                title: "在浏览器中搜索 “\(cleaned)”",
                subtitle: engineLabel(),
                icon: .system("magnifyingglass.circle.fill"),
                score: questionLeading ? 1.2 : 0.05,
                action: .openURL(url),
                providerID: id,
                category: .standard
            )
        ]
    }

    private func engineLabel() -> String {
        switch WebSearchPreferences.engine {
        case .google: return "Google"
        case .bing: return "Bing"
        case .baidu: return "百度"
        case .systemDefault: return "默认"
        case .custom: return "自定义"
        }
    }
}
