import Foundation

enum PrefixResultItemBuilder {
    static func items(matching query: String) -> [ResultItem] {
        let normalized = query.lowercased()
        let entries = PrefixRegistry.entries()

        var results: [ResultItem] = []
        results.reserveCapacity(entries.count)

        for entry in entries {
            results.append(resultItem(from: entry, normalizedQuery: normalized))
        }

        return results.sorted { lhs, rhs in
            // 如果分数相同，翻译前缀优先
            if lhs.score == rhs.score {
                if lhs.providerID == TranslateProvider.providerID && rhs.providerID != TranslateProvider.providerID {
                    return true
                }
                if lhs.providerID != TranslateProvider.providerID && rhs.providerID == TranslateProvider.providerID {
                    return false
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
    }

    static func fallbackItem(for entry: PrefixEntry) -> ResultItem {
        resultItem(from: entry, normalizedQuery: "")
    }

    private static func resultItem(from entry: PrefixEntry, normalizedQuery: String) -> ResultItem {
        let matchScore: Double
        if normalizedQuery.isEmpty {
            matchScore = 0.99
        } else if entry.id == normalizedQuery {
            matchScore = 1.0
        } else if entry.id.hasPrefix(normalizedQuery) {
            matchScore = 0.97
        } else {
            matchScore = 0.6
        }

        return ResultItem(
            title: entry.title,
            subtitle: entry.subtitle ?? "Press Enter to scope",
            icon: entry.icon ?? .system("bolt.circle"),
            score: matchScore,
            action: .none,
            providerID: entry.providerID,
            category: .standard,
            isPrefix: true
        )
    }
}
