import Foundation

final class UserAliasStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func getAliases(bundleID: String) -> [String] {
        loadPayload().byBundleID[bundleID] ?? []
    }

    func setAliases(bundleID: String, aliases: [String]) {
        var payload = loadPayload()
        payload.byBundleID[bundleID] = normalizeAliases(aliases)
        savePayload(payload)
    }

    func addAlias(bundleID: String, alias: String) {
        var payload = loadPayload()
        var existing = payload.byBundleID[bundleID] ?? []
        existing.append(alias)
        payload.byBundleID[bundleID] = normalizeAliases(existing)
        savePayload(payload)
    }

    func removeAlias(bundleID: String, alias: String) {
        var payload = loadPayload()
        let normalizedAlias = normalizeAlias(alias)
        let existing = payload.byBundleID[bundleID] ?? []
        payload.byBundleID[bundleID] = existing.filter { normalizeAlias($0) != normalizedAlias }
        savePayload(payload)
    }

    func snapshot() -> Payload {
        loadPayload()
    }

    struct Payload: Codable {
        var byBundleID: [String: [String]]
        var byName: [String: [String]]?
        var aliases: [String: [String]]?
    }

    private func loadPayload() -> Payload {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return Payload(byBundleID: [:], byName: nil, aliases: nil)
        }
        return payload
    }

    private func savePayload(_ payload: Payload) {
        lock.lock()
        defer { lock.unlock() }

        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private func normalizeAliases(_ aliases: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for alias in aliases {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = normalizeAlias(trimmed)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    private func normalizeAlias(_ alias: String) -> String {
        MatchingNormalizer.normalize(alias)
    }
}
