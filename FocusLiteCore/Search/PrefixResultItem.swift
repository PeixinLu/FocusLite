import Foundation

enum PrefixResultItemBuilder {
    static func items(matching query: String) -> [ResultItem] {
        let normalized = query.lowercased()
        let entries = PrefixRegistry.entries()

        var results: [ResultItem] = []
        results.reserveCapacity(entries.count)

        for entry in entries {
            guard shouldInclude(entry: entry, normalizedQuery: normalized) else { continue }
            results.append(resultItem(from: entry, normalizedQuery: normalized))
        }

        return results.sorted { lhs, rhs in
            lhs.score == rhs.score
                ? lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                : lhs.score > rhs.score
        }
    }

    static func fallbackItem(for entry: PrefixEntry) -> ResultItem {
        resultItem(from: entry, normalizedQuery: "")
    }

    private static func shouldInclude(entry: PrefixEntry, normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }
        return entry.id.hasPrefix(normalizedQuery)
    }

    private static func resultItem(from entry: PrefixEntry, normalizedQuery: String) -> ResultItem {
        let matchScore: Double
        if normalizedQuery.isEmpty {
            matchScore = 0.99
        } else if entry.id == normalizedQuery {
            matchScore = 1.0
        } else {
            matchScore = 0.95
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
