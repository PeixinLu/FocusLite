import Foundation

struct SnippetsProvider: ResultProvider {
    static let providerID = "snippets"
    let id = SnippetsProvider.providerID
    let displayName = "Snippets"

    private let store: SnippetStore

    init(store: SnippetStore = .shared) {
        self.store = store
        Task {
            await store.loadIfNeeded()
        }
    }

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && !isScoped {
            return []
        }

        let snippets = await store.snapshot()
        if trimmed.isEmpty && isScoped {
            return snippets.map { resultItem(snippet: $0, score: 1.0) }
        }
        if let keywordQuery = SnippetMatcher.keywordQuery(from: trimmed) {
            return keywordResults(query: keywordQuery, snippets: snippets)
        }

        return searchResults(query: trimmed, snippets: snippets)
    }

    private func keywordResults(query: String, snippets: [Snippet]) -> [ResultItem] {
        var matches: [(Snippet, Double)] = []
        matches.reserveCapacity(snippets.count)

        for snippet in snippets {
            if let score = SnippetMatcher.keywordScore(query: query, keyword: snippet.keyword) {
                matches.append((snippet, score))
            }
        }

        return matches.sorted { $0.1 > $1.1 }.map { resultItem(snippet: $0.0, score: $0.1) }
    }

    private func searchResults(query: String, snippets: [Snippet]) -> [ResultItem] {
        var matches: [(Snippet, Double)] = []
        matches.reserveCapacity(min(snippets.count, 40))

        for snippet in snippets {
            if let score = SnippetMatcher.searchScore(query: query, snippet: snippet) {
                matches.append((snippet, score))
            }
        }

        return matches
            .sorted { $0.1 > $1.1 }
            .map { resultItem(snippet: $0.0, score: $0.1) }
    }

    private func resultItem(snippet: Snippet, score: Double) -> ResultItem {
        let subtitle = contentPreview(snippet.content)
        let action: ResultAction = SnippetsPreferences.autoPasteAfterSelect
            ? .pasteText(snippet.content)
            : .copyText(snippet.content)
        return ResultItem(
            title: snippet.title,
            subtitle: subtitle,
            icon: .system("text.append"),
            score: score,
            action: action,
            providerID: id,
            category: .standard,
            preview: .text(snippet.content)
        )
    }

    private func contentPreview(_ content: String, limit: Int = 120) -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let collapsed = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        if collapsed.count <= limit {
            return collapsed
        }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<endIndex]) + "..."
    }
}
