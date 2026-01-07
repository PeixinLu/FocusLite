import Foundation

struct AppSearchProvider: ResultProvider {
    static let providerID = "app_search"
    let id = AppSearchProvider.providerID
    let displayName = "Applications"

    private let index: AppIndex

    init(index: AppIndex = .shared) {
        self.index = index
        Task {
            await index.warmUp()
        }
    }

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        await index.warmUp()
        let apps = await index.snapshot()
        let excludedBundleIDs = AppSearchPreferences.excludedBundleIDs
        let excludedPaths = AppSearchPreferences.excludedPaths

        let info = Matcher.queryInfo(for: trimmed)
        var candidates: [(ResultItem, MatchResult, String)] = []
        candidates.reserveCapacity(min(apps.count, 80))

        for app in apps {
            if AppSearchPreferences.isExcluded(
                bundleID: app.bundleID,
                path: app.path,
                excludedBundleIDs: excludedBundleIDs,
                excludedPaths: excludedPaths
            ) {
                continue
            }
            guard let match = Matcher.match(query: trimmed, index: app.nameIndex) else {
                continue
            }

            if Matcher.shouldInclude(match, info: info) {
                Log.debug("AppSearch: \(app.name) -> \(match.debug ?? "")")
                candidates.append((resultItem(for: app, score: match.finalScore), match, app.name))
            }
        }

        return candidates.sorted {
            if $0.1.bucket.rawValue != $1.1.bucket.rawValue {
                return $0.1.bucket.rawValue > $1.1.bucket.rawValue
            }
            if $0.1.finalScore != $1.1.finalScore {
                return $0.1.finalScore > $1.1.finalScore
            }
            return $0.2.localizedCaseInsensitiveCompare($1.2) == .orderedAscending
        }.map { $0.0 }
    }

    private func resultItem(for app: AppIndex.AppEntry, score: Double) -> ResultItem {
        // 简化路径显示：用 ~ 代替 home 目录
        let homeDir = NSHomeDirectory()
        let displayPath: String
        if app.path.hasPrefix(homeDir) {
            displayPath = app.path.replacingOccurrences(of: homeDir, with: "~")
        } else {
            displayPath = app.path
        }
        
        let url = URL(fileURLWithPath: app.path)
        return ResultItem(
            title: app.name,
            subtitle: displayPath,
            icon: .filePath(app.path),
            score: score,
            action: .openURL(url),
            providerID: id,
            category: .standard
        )
    }
}
