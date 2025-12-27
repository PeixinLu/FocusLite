import AppKit
import Foundation
import UniformTypeIdentifiers

final class ClipboardMonitor {
    private let store: ClipboardStore
    private var task: Task<Void, Never>?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    private let pollIntervalNanos: UInt64 = 300_000_000
    private let maxTextBytes = 1_048_576
    private let maxImageBytes = 20_971_520

    init(store: ClipboardStore = .shared) {
        self.store = store
    }

    func start() {
        guard task == nil else { return }
        task = Task.detached { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func run() async {
        while !Task.isCancelled {
            await MainActor.run { [weak self] in
                self?.pollPasteboard()
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanos)
        }
    }

    @MainActor
    private func pollPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if ClipboardPreferences.isPaused {
            return
        }

        let hasText = (pasteboard.string(forType: .string) ?? "").isEmpty == false
        let hasRasterImage = hasRasterImageData()
        let fileURLs = fileURLsFromPasteboard()
        let hasImageFileURL = hasImageFileURL(fileURLs)
        let hasPDF = pasteboard.data(forType: .pdf) != nil
        let hasFileURLs = !fileURLs.isEmpty

        if hasRasterImage || hasImageFileURL {
            if handleImage(allowPDF: false) { return }
        } else if hasPDF && !hasText {
            if handleImage(allowPDF: true) { return }
        }

        if hasFileURLs {
            handleFiles(fileURLs)
            return
        }

        guard let text = pasteboard.string(forType: .string) else { return }
        guard !text.isEmpty else { return }
        guard Data(text.utf8).count <= maxTextBytes else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let bundleID = frontmost?.bundleIdentifier
        if let bundleID, ClipboardPreferences.ignoredBundleIDs.contains(bundleID) {
            return
        }

        let appName = frontmost?.localizedName
        Task {
            await store.add(content: .text(text), sourceBundleID: bundleID, sourceAppName: appName)
        }
    }

    private func handleFiles(_ urls: [URL]) {
        let items = urls.prefix(20).map { url in
            FilePreviewItem(path: url.path, name: url.lastPathComponent)
        }
        guard !items.isEmpty else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let bundleID = frontmost?.bundleIdentifier
        if let bundleID, ClipboardPreferences.ignoredBundleIDs.contains(bundleID) {
            return
        }
        let appName = frontmost?.localizedName

        Task {
            await store.add(content: .files(Array(items)), sourceBundleID: bundleID, sourceAppName: appName)
        }
    }

    @discardableResult
    private func handleImage(allowPDF: Bool) -> Bool {
        guard let payload = getImagePayloadFromPasteboard(allowPDF: allowPDF) else { return false }
        let frontmost = NSWorkspace.shared.frontmostApplication
        let bundleID = frontmost?.bundleIdentifier
        if let bundleID, ClipboardPreferences.ignoredBundleIDs.contains(bundleID) {
            return true
        }
        let appName = frontmost?.localizedName

        switch payload {
        case .data(let data, let type):
            guard data.count <= maxImageBytes else { return true }
            Task {
                await store.addImage(data: data, type: type, sourceBundleID: bundleID, sourceAppName: appName)
            }
        case .file(let url, let type):
            Task {
                guard let data = try? Data(contentsOf: url), data.count <= maxImageBytes else { return }
                await store.addImage(data: data, type: type, sourceBundleID: bundleID, sourceAppName: appName)
            }
        }
        return true
    }

    private var supportedImageTypes: [NSPasteboard.PasteboardType] {
        [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.jpeg-2000"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.heif"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("public.webp"),
            NSPasteboard.PasteboardType("com.microsoft.bmp")
        ]
    }

    private func hasRasterImageData() -> Bool {
        let pasteboard = NSPasteboard.general
        return supportedImageTypes.contains { pasteboard.data(forType: $0) != nil }
    }

    private func hasImageFileURL(_ urls: [URL]) -> Bool {
        return urls.contains { url in
            if let type = UTType(filenameExtension: url.pathExtension.lowercased()) {
                return type.conforms(to: UTType.image)
            }
            return false
        }
    }

    private func getImagePayloadFromPasteboard(allowPDF: Bool) -> ImagePayload? {
        if let payload = getImagePayloadFromFileURL(allowPDF: allowPDF) {
            return payload
        }

        let types: [NSPasteboard.PasteboardType] = allowPDF ? supportedImageTypes + [.pdf] : supportedImageTypes
        for type in types {
            if let data = NSPasteboard.general.data(forType: type) {
                return .data(data, type)
            }
        }
        return nil
    }

    private func getImagePayloadFromFileURL(allowPDF: Bool) -> ImagePayload? {
        let urls = fileURLsFromPasteboard()
        for url in urls {
            guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { continue }
            if type.conforms(to: UTType.image) || (allowPDF && type.conforms(to: UTType.pdf)) {
                let pbType = NSPasteboard.PasteboardType(type.identifier)
                return .file(url, pbType)
            }
        }
        return nil
    }

    private func fileURLsFromPasteboard() -> [URL] {
        let pasteboard = NSPasteboard.general
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return [] }
        var urls: [URL] = []
        urls.reserveCapacity(items.count)

        for item in items {
            if let data = item.data(forType: .fileURL),
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                urls.append(url)
            } else if let string = item.string(forType: .fileURL),
                      let url = URL(string: string) {
                urls.append(url)
            }
        }
        return urls
    }
}

private enum ImagePayload {
    case data(Data, NSPasteboard.PasteboardType)
    case file(URL, NSPasteboard.PasteboardType)
}
