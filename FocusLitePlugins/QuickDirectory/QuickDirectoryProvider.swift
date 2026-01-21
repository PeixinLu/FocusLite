import Foundation

struct QuickDirectoryProvider: ResultProvider {
    static let providerID = "quick_directory"
    let id = QuickDirectoryProvider.providerID
    let displayName = "Quick Directories"

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        let entries = QuickDirectoryPreferences.entries()
        guard !entries.isEmpty else { return [] }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSlashMode = trimmed.hasPrefix("/")
        let normalized = (isSlashMode ? String(trimmed.drop(while: { $0 == "/" })) : trimmed)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let fm = FileManager.default
        var items: [(ResultItem, Double)] = []
        items.reserveCapacity(entries.count)

        for (index, entry) in entries.enumerated() {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            guard let score = matchScore(entry: entry, normalizedQuery: normalized, index: index, isSlashMode: isSlashMode) else {
                continue
            }
            items.append((resultItem(from: entry, score: score), score))
        }

        return items.sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 > rhs.1
            }
            return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
        }.map { $0.0 }
    }

    private func matchScore(entry: QuickDirectoryEntry, normalizedQuery: String, index: Int, isSlashMode _: Bool) -> Double? {
        if normalizedQuery.isEmpty {
            // Keep the seeded order in slash mode by applying a small decay on the index.
            return 0.8 - Double(index) * 0.01
        }

        let title = entry.displayTitle.lowercased()
        let folderName = URL(fileURLWithPath: entry.path).lastPathComponent.lowercased()

        if title == normalizedQuery || folderName == normalizedQuery {
            return 1.0
        }
        if title.hasPrefix(normalizedQuery) || folderName.hasPrefix(normalizedQuery) {
            return 0.96
        }
        if let alias = entry.alias?.lowercased(), alias.contains(normalizedQuery) {
            return 0.9
        }
        if title.contains(normalizedQuery) || folderName.contains(normalizedQuery) {
            return 0.85
        }
        if entry.path.lowercased().contains(normalizedQuery) {
            return 0.75
        }
        return nil
    }

    private func resultItem(from entry: QuickDirectoryEntry, score: Double) -> ResultItem {
        let home = NSHomeDirectory()
        let displayPath: String
        if entry.path.hasPrefix(home) {
            displayPath = entry.path.replacingOccurrences(of: home, with: "~")
        } else {
            displayPath = entry.path
        }

        return ResultItem(
            title: entry.displayTitle,
            subtitle: displayPath,
            icon: .system("folder"),
            score: score,
            action: .openURL(URL(fileURLWithPath: entry.path)),
            providerID: Self.providerID,
            category: .standard
        )
    }
}
