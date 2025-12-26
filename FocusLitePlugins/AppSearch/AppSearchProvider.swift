import Foundation

struct AppSearchProvider: ResultProvider {
    let id = "app_search"
    let displayName = "Applications"

    private let index: AppIndex

    init(index: AppIndex = .shared) {
        self.index = index
        Task {
            await index.warmUp()
        }
    }

    func results(for query: String) async -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        await index.warmUp()
        let apps = await index.snapshot()

        var items: [ResultItem] = []
        items.reserveCapacity(min(apps.count, 80))
        let threshold = 0.55

        for app in apps {
            guard let match = Matcher.match(query: trimmed, index: app.nameIndex) else {
                continue
            }

            if match.score >= threshold {
                Log.debug("AppSearch: \(app.name) -> \(match.debug)")
                items.append(resultItem(for: app, score: match.score))
            }
        }

        return items
    }

    private func resultItem(for app: AppIndex.AppEntry, score: Double) -> ResultItem {
        let subtitle = app.bundleID ?? app.path
        let url = URL(fileURLWithPath: app.path)
        return ResultItem(
            title: app.name,
            subtitle: subtitle,
            icon: .filePath(app.path),
            score: score,
            action: .openURL(url),
            providerID: id,
            category: .standard
        )
    }
}
