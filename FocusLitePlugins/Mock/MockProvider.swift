import Foundation

struct MockProvider: ResultProvider {
    let id = "mock"
    let displayName = "Mock Provider"

    func results(for query: String) async -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return []
        }

        return [
            ResultItem(
                title: "\(trimmed) - Quick Action",
                subtitle: "Mock result with highest score",
                icon: .system("bolt.circle"),
                score: 0.9,
                action: .none,
                providerID: id,
                category: .standard
            ),
            ResultItem(
                title: "\(trimmed) - Documentation",
                subtitle: "Mock result with medium score",
                icon: .system("book"),
                score: 0.6,
                action: .none,
                providerID: id,
                category: .standard
            ),
            ResultItem(
                title: "\(trimmed) - Suggestion",
                subtitle: "Mock result with lower score",
                icon: .system("lightbulb"),
                score: 0.3,
                action: .none,
                providerID: id,
                category: .standard
            )
        ]
    }
}
