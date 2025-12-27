import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

actor ClipboardStore {
    static let shared = ClipboardStore()

    private var entries: [ClipboardEntry] = []
    private var isLoaded = false
    private let fileURL: URL
    private let imagesDirectory: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let base = appSupport.appendingPathComponent("FocusLite", isDirectory: true)
        fileURL = base.appendingPathComponent("clipboard_history.json")
        imagesDirectory = base.appendingPathComponent("clipboard_images", isDirectory: true)
    }

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        entries = loadFromDisk()
        pruneExpiredEntries()
        isLoaded = true
    }

    func snapshot() async -> [ClipboardEntry] {
        await loadIfNeeded()
        return entries
    }

    func add(content: ClipboardContent, sourceBundleID: String?, sourceAppName: String?) async {
        await loadIfNeeded()
        guard !content.isEmpty else { return }

        let hash = contentHash(for: content)
        entries.removeAll { $0.contentHash == hash }

        let entry = ClipboardEntry(
            content: content,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            contentHash: hash
        )
        entries.insert(entry, at: 0)

        let limit = ClipboardPreferences.maxEntries
        if entries.count > limit {
            let trimmed = Array(entries.prefix(limit))
            removeEntries(Array(entries.dropFirst(limit)))
            entries = trimmed
        }
        pruneExpiredEntries()
        saveToDisk()
    }

    func addImage(data: Data, type: NSPasteboard.PasteboardType, sourceBundleID: String?, sourceAppName: String?) async {
        await loadIfNeeded()
        guard !data.isEmpty else { return }

        guard let image = NSImage(data: data) else { return }
        let size = image.size
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())

        let hash = contentHash(for: data, type: type.rawValue)
        let filename = hash + "." + imageFileExtension(from: type)
        let path = imagesDirectory.appendingPathComponent(filename)
        ensureImagesDirectory()
        if !FileManager.default.fileExists(atPath: path.path) {
            do {
                try data.write(to: path, options: [.atomic])
            } catch {
                return
            }
        }

        let imageItem = ClipboardImageItem(
            path: path.path,
            type: type.rawValue,
            width: width,
            height: height
        )
        let entry = ClipboardEntry(
            content: .image(imageItem),
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            contentHash: hash
        )
        entries.removeAll { $0.contentHash == hash }
        entries.insert(entry, at: 0)

        let limit = ClipboardPreferences.maxEntries
        if entries.count > limit {
            let trimmed = Array(entries.prefix(limit))
            removeEntries(Array(entries.dropFirst(limit)))
            entries = trimmed
        }
        pruneExpiredEntries()
        saveToDisk()
    }

    private func contentHash(for content: ClipboardContent) -> String {
        let data: Data
        switch content {
        case .text(let text):
            data = Data(text.utf8)
        case .image(let image):
            let imageData = (try? Data(contentsOf: URL(fileURLWithPath: image.path))) ?? Data()
            data = imageData + Data(image.type.utf8)
        case .files(let files):
            let joined = files.map { $0.path }.joined(separator: "|")
            data = Data(joined.utf8)
        }

        return digestHex(for: data)
    }

    private func contentHash(for data: Data, type: String) -> String {
        digestHex(for: data + Data(type.utf8))
    }

    private func digestHex(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadFromDisk() -> [ClipboardEntry] {
        ensureDirectories()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ClipboardEntry].self, from: data)
        } catch {
            return []
        }
    }

    private func saveToDisk() {
        ensureDirectories()
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return
        }
    }

    private func ensureDirectories() {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        ensureImagesDirectory()
    }

    private func ensureImagesDirectory() {
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
    }

    private func imageFileExtension(from type: NSPasteboard.PasteboardType) -> String {
        if let utType = UTType(type.rawValue), let ext = utType.preferredFilenameExtension {
            return ext
        }
        return "img"
    }

    private func pruneExpiredEntries() {
        let hours = ClipboardPreferences.historyRetentionHours
        guard hours > 0 else { return }
        let maxAge = TimeInterval(hours) * 60 * 60
        let cutoff = Date().addingTimeInterval(-maxAge)
        let expired = entries.filter { $0.createdAt < cutoff }
        if !expired.isEmpty {
            removeEntries(expired)
            entries.removeAll { $0.createdAt < cutoff }
        }
    }

    private func removeEntries(_ targets: [ClipboardEntry]) {
        for entry in targets {
            if case .image(let image) = entry.content {
                try? FileManager.default.removeItem(atPath: image.path)
            }
        }
    }
}

private extension ClipboardContent {
    var isEmpty: Bool {
        switch self {
        case .text(let text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image(let image):
            return image.path.isEmpty
        case .files(let files):
            return files.isEmpty
        }
    }
}
