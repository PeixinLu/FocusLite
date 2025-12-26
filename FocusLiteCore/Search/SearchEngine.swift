import Foundation

final class SearchEngine {
    private let providers: [any ResultProvider]

    init(providers: [any ResultProvider]) {
        self.providers = providers
    }

    func search(query: String) async -> [ResultItem] {
        await withTaskGroup(of: [ResultItem].self) { group in
            for provider in providers {
                group.addTask {
                    await provider.results(for: query)
                }
            }

            var items: [ResultItem] = []
            for await result in group {
                items.append(contentsOf: result)
            }

            return items.sorted { $0.score > $1.score }
        }
    }
}
