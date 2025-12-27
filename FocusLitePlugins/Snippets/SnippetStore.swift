import Foundation

actor SnippetStore {
    static let shared = SnippetStore()

    private let fileURL: URL
    private var snippets: [Snippet] = []
    private var isLoaded = false

    init(fileURL: URL = SnippetStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        snippets = loadFromDisk()
        isLoaded = true
    }

    func snapshot() async -> [Snippet] {
        await loadIfNeeded()
        return snippets.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func upsert(_ snippet: Snippet) async {
        await loadIfNeeded()
        let normalized = sanitize(snippet)

        if let index = snippets.firstIndex(where: { $0.id == normalized.id }) {
            snippets[index] = normalized
        } else {
            snippets.append(normalized)
        }

        saveToDisk()
    }

    func delete(id: UUID) async {
        await loadIfNeeded()
        snippets.removeAll { $0.id == id }
        saveToDisk()
    }

    private func loadFromDisk() -> [Snippet] {
        ensureDirectoryExists()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Snippet].self, from: data)
        } catch {
            Log.info("Failed to load snippets: \(error.localizedDescription)")
            return []
        }
    }

    private func saveToDisk() {
        ensureDirectoryExists()
        do {
            let data = try JSONEncoder().encode(snippets)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            Log.info("Failed to save snippets: \(error.localizedDescription)")
        }
    }

    private func ensureDirectoryExists() {
        let directory = fileURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: directory.path) {
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Log.info("Failed to create snippets directory: \(error.localizedDescription)")
        }
    }

    private func sanitize(_ snippet: Snippet) -> Snippet {
        var updated = snippet
        updated.title = snippet.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.content = snippet.content.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedKeyword = snippet.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.keyword = trimmedKeyword.hasPrefix(";")
            ? String(trimmedKeyword.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmedKeyword

        updated.tags = snippet.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        updated.updatedAt = Date()
        return updated
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("FocusLite", isDirectory: true)
            .appendingPathComponent("snippets.json")
    }
}
