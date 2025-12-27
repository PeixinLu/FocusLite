import Foundation

final class SearchEngine {
    private let providers: [any ResultProvider]

    init(providers: [any ResultProvider]) {
        self.providers = providers
    }

    func search(query: String, isScoped: Bool, providerIDs: Set<String>? = nil) async -> [ResultItem] {
        if !isScoped && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        let preferCalc = SearchQueryClassifier.isMathQuery(query)
        let activeProviders: [any ResultProvider]
        if let providerIDs {
            activeProviders = providers.filter { providerIDs.contains($0.id) }
        } else {
            activeProviders = providers
        }

        if activeProviders.isEmpty {
            return []
        }
        return await withTaskGroup(of: [ResultItem].self) { group in
            for provider in activeProviders {
                group.addTask {
                    await provider.results(for: query, isScoped: isScoped)
                }
            }

            var items: [ResultItem] = []
            for await result in group {
                items.append(contentsOf: result)
            }

            if preferCalc {
                return items.sorted {
                    if $0.category != $1.category {
                        return $0.category.rawValue < $1.category.rawValue
                    }
                    if $0.score != $1.score {
                        return $0.score > $1.score
                    }
                    if $0.title.count != $1.title.count {
                        return $0.title.count < $1.title.count
                    }
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
            }

            return items.sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                if $0.title.count != $1.title.count {
                    return $0.title.count < $1.title.count
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }
}
