import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

actor ClipboardStore {
    static let shared = ClipboardStore()

    private var entries: [ClipboardEntry] = []
    private var isLoaded = false
    private var canCleanupOrphanedFiles = true
    private var loadedLegacyTextPayload = false
    private let fileManager: FileManager
    private let fileURL: URL
    private let imagesDirectory: URL
    private let textDirectory: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        let base = baseDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("FocusLite", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FocusLite", isDirectory: true)
        fileURL = base.appendingPathComponent("clipboard_history.json")
        imagesDirectory = base.appendingPathComponent("clipboard_images", isDirectory: true)
        textDirectory = base.appendingPathComponent("clipboard_text", isDirectory: true)
    }

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        entries = loadFromDisk()
        let migrated = migrateLargeInlineTexts()
        let pruned = pruneExpiredEntries()
        cleanupOrphanedTextFiles()
        isLoaded = true
        if loadedLegacyTextPayload || migrated || pruned {
            saveToDisk()
        }
    }

    func snapshot() async -> [ClipboardEntry] {
        await loadIfNeeded()
        return entries
    }

    @discardableResult
    func clearHistory() async -> Int {
        await loadIfNeeded()
        let removedCount = entries.count
        let removedEntries = entries
        entries.removeAll()
        removeFiles(for: removedEntries, preserving: [])
        cleanupOrphanedTextFiles()
        saveToDisk()
        return removedCount
    }

    func text(for entryID: UUID) async -> String? {
        await loadIfNeeded()
        guard let entry = entries.first(where: { $0.id == entryID }),
              case .text(let item) = entry.content else {
            return nil
        }
        return loadText(for: item)
    }

    func resolvedContent(for entryID: UUID) async -> ClipboardResolvedContent? {
        await loadIfNeeded()
        guard let entry = entries.first(where: { $0.id == entryID }) else { return nil }
        switch entry.content {
        case .text(let item):
            return loadText(for: item).map(ClipboardResolvedContent.text)
        case .image(let image):
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: image.path)) else { return nil }
            return .image(data: data, type: image.type)
        case .files(let files):
            let existingPaths = files.map(\.path).filter { fileManager.fileExists(atPath: $0) }
            return existingPaths.isEmpty ? nil : .files(existingPaths)
        }
    }

    func addText(_ text: String, sourceBundleID: String?, sourceAppName: String?) async {
        await loadIfNeeded()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let hash = digestHex(for: Data(text.utf8))
        let storage: ClipboardTextStorage
        if text.utf8.count > ClipboardTextPolicy.inlineStorageByteLimit {
            let filename = hash + ".txt"
            guard writeTextIfNeeded(text, filename: filename) else { return }
            storage = .file(filename)
        } else {
            storage = .inline(text)
        }

        let item = ClipboardTextProcessor.makeItem(text: text, storage: storage)
        replaceDuplicateAndInsert(ClipboardEntry(
            content: .text(item),
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            contentHash: hash
        ))
        finishMutation()
    }

    func add(content: ClipboardContent, sourceBundleID: String?, sourceAppName: String?) async {
        await loadIfNeeded()
        guard !content.isEmpty else { return }

        if case .text(let item) = content, let text = loadText(for: item) {
            await addText(text, sourceBundleID: sourceBundleID, sourceAppName: sourceAppName)
            return
        }

        let hash = contentHash(for: content)
        replaceDuplicateAndInsert(ClipboardEntry(
            content: content,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            contentHash: hash
        ))
        finishMutation()
    }

    func addImage(
        data: Data,
        type: NSPasteboard.PasteboardType,
        sourceBundleID: String?,
        sourceAppName: String?
    ) async {
        await loadIfNeeded()
        guard !data.isEmpty, let image = NSImage(data: data) else { return }

        let size = image.size
        let hash = contentHash(for: data, type: type.rawValue)
        let filename = hash + "." + imageFileExtension(from: type)
        let path = imagesDirectory.appendingPathComponent(filename)
        ensureDirectories()
        if !fileManager.fileExists(atPath: path.path) {
            do {
                try data.write(to: path, options: [.atomic])
            } catch {
                Log.info("Unable to persist clipboard image: \(error.localizedDescription)")
                return
            }
        }

        let imageItem = ClipboardImageItem(
            path: path.path,
            type: type.rawValue,
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            byteCount: data.count
        )
        replaceDuplicateAndInsert(ClipboardEntry(
            content: .image(imageItem),
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            contentHash: hash
        ))
        finishMutation()
    }

    private func replaceDuplicateAndInsert(_ entry: ClipboardEntry) {
        let duplicates = entries.filter { $0.contentHash == entry.contentHash }
        entries.removeAll { $0.contentHash == entry.contentHash }
        entries.insert(entry, at: 0)
        removeFiles(for: duplicates, preserving: entries)
    }

    private func finishMutation() {
        let limit = ClipboardPreferences.maxEntries
        if entries.count > limit {
            let removed = Array(entries.dropFirst(limit))
            entries = Array(entries.prefix(limit))
            removeFiles(for: removed, preserving: entries)
        }
        _ = pruneExpiredEntries()
        cleanupOrphanedTextFiles()
        saveToDisk()
    }

    private func contentHash(for content: ClipboardContent) -> String {
        let data: Data
        switch content {
        case .text(let item):
            data = loadText(for: item).map { Data($0.utf8) } ?? Data(item.previewText.utf8)
        case .image(let image):
            let imageData = (try? Data(contentsOf: URL(fileURLWithPath: image.path))) ?? Data()
            data = imageData + Data(image.type.utf8)
        case .files(let files):
            data = Data(files.map(\.path).joined(separator: "|").utf8)
        }
        return digestHex(for: data)
    }

    private func contentHash(for data: Data, type: String) -> String {
        digestHex(for: data + Data(type.utf8))
    }

    private func digestHex(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func loadFromDisk() -> [ClipboardEntry] {
        ensureDirectories()
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            loadedLegacyTextPayload = containsLegacyTextPayload(in: data)
            return try JSONDecoder().decode([ClipboardEntry].self, from: data)
        } catch {
            Log.info("Unable to load clipboard history; starting with an empty history: \(error.localizedDescription)")
            preserveCorruptHistoryFile()
            canCleanupOrphanedFiles = false
            return []
        }
    }

    private func saveToDisk() {
        ensureDirectories()
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            Log.info("Unable to save clipboard history: \(error.localizedDescription)")
        }
    }

    private func migrateLargeInlineTexts() -> Bool {
        var didMigrate = false
        entries = entries.map { entry in
            guard case .text(let item) = entry.content,
                  case .inline(let text) = item.storage,
                  item.byteCount > ClipboardTextPolicy.inlineStorageByteLimit else {
                return entry
            }
            let filename = entry.contentHash + ".txt"
            guard writeTextIfNeeded(text, filename: filename) else { return entry }
            didMigrate = true
            return ClipboardEntry(
                id: entry.id,
                content: .text(item.replacingStorage(.file(filename))),
                createdAt: entry.createdAt,
                sourceBundleID: entry.sourceBundleID,
                sourceAppName: entry.sourceAppName,
                contentHash: entry.contentHash
            )
        }
        return didMigrate
    }

    private func loadText(for item: ClipboardTextItem) -> String? {
        switch item.storage {
        case .inline(let text):
            return text
        case .file(let filename):
            let url = textDirectory.appendingPathComponent(filename)
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                Log.info("Clipboard text file is unavailable: \(filename)")
                return nil
            }
        }
    }

    private func writeTextIfNeeded(_ text: String, filename: String) -> Bool {
        ensureDirectories()
        let url = textDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: url.path) { return true }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            Log.info("Unable to persist clipboard text: \(error.localizedDescription)")
            return false
        }
    }

    private func ensureDirectories() {
        for directory in [fileURL.deletingLastPathComponent(), imagesDirectory, textDirectory] {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }

    private func imageFileExtension(from type: NSPasteboard.PasteboardType) -> String {
        if let utType = UTType(type.rawValue), let ext = utType.preferredFilenameExtension {
            return ext
        }
        return "img"
    }

    @discardableResult
    private func pruneExpiredEntries() -> Bool {
        let hours = ClipboardPreferences.historyRetentionHours
        guard hours > 0 else { return false }
        let cutoff = Date().addingTimeInterval(-TimeInterval(hours) * 60 * 60)
        let expired = entries.filter { $0.createdAt < cutoff }
        guard !expired.isEmpty else { return false }
        entries.removeAll { $0.createdAt < cutoff }
        removeFiles(for: expired, preserving: entries)
        return true
    }

    private func removeFiles(for targets: [ClipboardEntry], preserving retainedEntries: [ClipboardEntry]) {
        let retainedTextFiles = Set(retainedEntries.compactMap { entry -> String? in
            guard case .text(let item) = entry.content,
                  case .file(let filename) = item.storage else { return nil }
            return filename
        })

        for entry in targets {
            switch entry.content {
            case .image(let image):
                try? fileManager.removeItem(atPath: image.path)
            case .text(let item):
                guard case .file(let filename) = item.storage,
                      !retainedTextFiles.contains(filename) else { continue }
                try? fileManager.removeItem(at: textDirectory.appendingPathComponent(filename))
            case .files:
                break
            }
        }
    }

    private func cleanupOrphanedTextFiles() {
        guard canCleanupOrphanedFiles else { return }
        ensureDirectories()
        let referenced = Set(entries.compactMap { entry -> String? in
            guard case .text(let item) = entry.content,
                  case .file(let filename) = item.storage else { return nil }
            return filename
        })
        guard let files = try? fileManager.contentsOfDirectory(
            at: textDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files where !referenced.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    private func preserveCorruptHistoryFile() {
        let backup = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? fileManager.moveItem(at: fileURL, to: backup)
    }

    private func containsLegacyTextPayload(in data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return false }

        func containsLegacyTextPayload(_ value: Any) -> Bool {
            if let object = value as? [String: Any] {
                if object["kind"] as? String == "text",
                   object["text"] is String,
                   object["textItem"] == nil {
                    return true
                }
                return object.values.contains(where: containsLegacyTextPayload)
            }
            if let array = value as? [Any] {
                return array.contains(where: containsLegacyTextPayload)
            }
            return false
        }

        return containsLegacyTextPayload(root)
    }
}

private extension ClipboardContent {
    var isEmpty: Bool {
        switch self {
        case .text(let item):
            return item.byteCount == 0
        case .image(let image):
            return image.path.isEmpty
        case .files(let files):
            return files.isEmpty
        }
    }
}
