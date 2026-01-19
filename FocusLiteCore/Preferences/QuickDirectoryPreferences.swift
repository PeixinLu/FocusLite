import Foundation

struct QuickDirectoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var path: String
    var name: String
    var alias: String?
    var isDefault: Bool

    var displayTitle: String {
        alias?.trimmedNonEmpty ?? name
    }

    var normalizedPath: String {
        QuickDirectoryPreferences.normalize(path)
    }
}

enum QuickDirectoryPreferences {
    private static let storageKey = "quickDirectories.entries"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func entries() -> [QuickDirectoryEntry] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? decoder.decode([QuickDirectoryEntry].self, from: data) {
            let sanitized = sanitize(decoded)
            if sanitized != decoded {
                save(sanitized)
            }
            return sanitized
        }

        let seeded = defaultEntries()
        save(seeded)
        return seeded
    }

    static func save(_ entries: [QuickDirectoryEntry]) {
        let sanitized = sanitize(entries)
        guard let data = try? encoder.encode(sanitized) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func normalize(_ path: String) -> String {
        let expanded = NSString(string: path).expandingTildeInPath
        return NSString(string: expanded).standardizingPath
    }

    private static func defaultEntries() -> [QuickDirectoryEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let defaults: [(String, String)] = [
            ("Applications", "应用程序"),
            ("Desktop", "桌面"),
            ("Downloads", "下载"),
            ("Documents", "文档"),
            ("Pictures", "图片"),
            ("Movies", "视频")
        ]

        return defaults.compactMap { folder, name in
            let url = home.appendingPathComponent(folder, isDirectory: true)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }
            return QuickDirectoryEntry(
                id: UUID(),
                path: url.path,
                name: name,
                alias: nil,
                isDefault: true
            )
        }
    }

    private static func sanitize(_ entries: [QuickDirectoryEntry]) -> [QuickDirectoryEntry] {
        var seen: Set<String> = []
        var cleaned: [QuickDirectoryEntry] = []

        for entry in entries {
            let normalizedPath = normalize(entry.path)
            guard !normalizedPath.isEmpty else { continue }
            guard seen.insert(normalizedPath).inserted else { continue }

            var next = entry
            next.path = normalizedPath
            let trimmedName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            next.name = trimmedName.isEmpty ? URL(fileURLWithPath: normalizedPath).lastPathComponent : trimmedName
            next.alias = entry.alias?.trimmedNonEmpty
            cleaned.append(next)
        }

        return cleaned
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
