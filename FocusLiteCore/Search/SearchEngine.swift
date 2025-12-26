import Foundation

final class SearchEngine {
    private let providers: [any ResultProvider]

    init(providers: [any ResultProvider]) {
        self.providers = providers
    }

    func search(query: String) async -> [ResultItem] {
        let preferCalc = SearchQueryClassifier.isMathQuery(query)
        return await withTaskGroup(of: [ResultItem].self) { group in
            for provider in providers {
                group.addTask {
                    await provider.results(for: query)
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
