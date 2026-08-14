import AppKit
import Foundation
import UniformTypeIdentifiers

struct ClipboardProvider: ResultProvider {
    static let providerID = "clipboard"
    let id = ClipboardProvider.providerID
    let displayName = "Clipboard"

    private let store: ClipboardStore

    init(store: ClipboardStore = .shared) {
        self.store = store
        Task { await store.loadIfNeeded() }
    }

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && !isScoped { return [] }

        let entries = await store.snapshot()
        if Task.isCancelled { return [] }
        if trimmed.isEmpty && isScoped {
            return entries.prefix(ClipboardTextPolicy.initialResultLimit).enumerated().map { index, entry in
                resultItem(entry: entry, score: 1.0 - Double(index) * 0.001, query: "")
            }
        }

        let normalizedQuery = ClipboardTextProcessor.normalizeForSearch(trimmed)
        var matches: [(ClipboardEntry, Double)] = []
        matches.reserveCapacity(min(entries.count, ClipboardTextPolicy.searchResultLimit))

        for entry in entries {
            if Task.isCancelled { return [] }
            guard let score = ClipboardMatcher.score(normalizedQuery: normalizedQuery, entry: entry) else { continue }
            matches.append((entry, score))
        }

        if Task.isCancelled { return [] }
        return matches
            .sorted { $0.1 > $1.1 }
            .prefix(ClipboardTextPolicy.searchResultLimit)
            .map { resultItem(entry: $0.0, score: $0.1, query: trimmed) }
    }

    private func resultItem(entry: ClipboardEntry, score: Double, query: String) -> ResultItem {
        switch entry.content {
        case .text(let item):
            let behavior: ClipboardEntryActionBehavior = ClipboardPreferences.autoPasteAfterSelect ? .paste : .copy
            return ResultItem(
                id: entry.id,
                title: item.title,
                subtitle: subtitle(for: entry, extra: ByteCountFormatter.string(fromByteCount: Int64(item.byteCount), countStyle: .file)),
                icon: .system("doc.text"),
                score: score,
                action: .clipboardEntry(id: entry.id, behavior: behavior),
                providerID: id,
                category: .standard,
                preview: .clipboardText(ClipboardTextPreview(
                    entryID: entry.id,
                    text: item.previewText,
                    byteCount: item.byteCount,
                    lineCount: item.lineCount,
                    isTruncated: item.isPreviewTruncated
                )),
                clipboardMetadata: metadata(
                    for: entry,
                    type: "文本",
                    byteCount: item.byteCount
                )
            )
        case .image(let image):
            let sizeText = imageSizeText(width: image.width, height: image.height)
            let formatText = imageFormatText(from: image.type)
            let title = query.isEmpty ? sizeText : sizeText + " (\(query))"
            return ResultItem(
                id: entry.id,
                title: formatText.isEmpty ? title : "\(formatText) \(title)",
                subtitle: subtitle(for: entry),
                icon: .system("photo"),
                score: score,
                action: .clipboardEntry(id: entry.id, behavior: .copy),
                providerID: id,
                category: .standard,
                preview: .clipboardImage(entryID: entry.id, path: image.path),
                clipboardMetadata: metadata(
                    for: entry,
                    type: formatText.isEmpty ? "图片" : "\(formatText) 图片",
                    byteCount: image.byteCount
                )
            )
        case .files(let files):
            let firstName = files.first?.name ?? "File"
            let countText = files.count > 1 ? " (\(files.count))" : ""
            return ResultItem(
                id: entry.id,
                title: firstName + countText,
                subtitle: subtitle(for: entry, extra: files.count > 1 ? files.dropFirst().map(\.name).joined(separator: ", ") : nil),
                icon: fileIcon(files),
                score: score,
                action: .clipboardEntry(id: entry.id, behavior: .copy),
                providerID: id,
                category: .standard,
                preview: .clipboardFiles(entryID: entry.id, files: files),
                clipboardMetadata: metadata(
                    for: entry,
                    type: fileTypeText(files),
                    byteCount: totalByteCount(files)
                )
            )
        }
    }

    private func metadata(for entry: ClipboardEntry, type: String, byteCount: Int?) -> ClipboardResultMetadata {
        ClipboardResultMetadata(
            sourceBundleID: entry.sourceBundleID,
            sourceAppName: entry.sourceAppName,
            timeText: relativeTime(for: entry.createdAt),
            typeText: type,
            sizeText: byteCount.map {
                ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
            } ?? "大小未知"
        )
    }

    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func fileTypeText(_ files: [FilePreviewItem]) -> String {
        guard files.count == 1, let file = files.first else {
            return "\(files.count) 个文件"
        }
        let suffix = URL(fileURLWithPath: file.name).pathExtension.uppercased()
        return suffix.isEmpty ? "文件" : "\(suffix) 文件"
    }

    private func totalByteCount(_ files: [FilePreviewItem]) -> Int? {
        let sizes = files.compactMap(\.byteCount)
        guard sizes.count == files.count else { return nil }
        return sizes.reduce(0, +)
    }

    private func fileIcon(_ files: [FilePreviewItem]) -> ItemIcon {
        let types = files.compactMap { file in
            UTType(filenameExtension: URL(fileURLWithPath: file.name).pathExtension)
        }
        guard types.count == files.count, !types.isEmpty else { return .system("doc") }
        if types.allSatisfy({ $0.conforms(to: .image) }) { return .system("photo") }
        if types.allSatisfy({ $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
            return .system("film")
        }
        if types.allSatisfy({ $0.conforms(to: .text) }) { return .system("doc.text") }
        return .system("doc")
    }

    private func subtitle(for entry: ClipboardEntry, extra: String? = nil) -> String? {
        var parts = [relativeTime(for: entry.createdAt)]
        if let extra, !extra.isEmpty { parts.append(extra) }
        return parts.joined(separator: " - ")
    }

    private func imageSizeText(width: Int, height: Int) -> String {
        width == 0 && height == 0 ? "Image" : "Image \(width)x\(height)"
    }

    private func imageFormatText(from type: String) -> String {
        let lowered = type.lowercased()
        if lowered.contains("jpeg") || lowered.contains("jpg") { return "JPG" }
        if lowered.contains("png") { return "PNG" }
        if lowered.contains("heic") { return "HEIC" }
        if lowered.contains("heif") { return "HEIF" }
        if lowered.contains("gif") { return "GIF" }
        if lowered.contains("webp") { return "WEBP" }
        if lowered.contains("bmp") { return "BMP" }
        if lowered.contains("tiff") { return "TIFF" }
        if lowered.contains("pdf") { return "PDF" }
        return ""
    }
}

private enum ClipboardMatcher {
    static func score(normalizedQuery: String, entry: ClipboardEntry) -> Double? {
        guard !normalizedQuery.isEmpty else { return nil }
        let source = ClipboardTextProcessor.normalizeForSearch(entry.sourceAppName ?? "")

        switch entry.content {
        case .text(let item):
            var best = scoreField(query: normalizedQuery, candidate: item.searchText) ?? 0
            if let sourceScore = scoreField(query: normalizedQuery, candidate: source) {
                best = max(best, sourceScore * 0.9)
            }
            guard best > 0 else { return nil }
            let tokens = tokenize(normalizedQuery)
            if tokens.count > 1 {
                let haystack = item.searchText + " " + source
                if tokens.allSatisfy({ haystack.contains($0) }) {
                    best = min(1.0, best + 0.05)
                }
            }
            return best
        case .image:
            var best = scoreField(query: normalizedQuery, candidate: "image photo screenshot") ?? 0
            if let sourceScore = scoreField(query: normalizedQuery, candidate: source) {
                best = max(best, sourceScore * 0.8)
            }
            return best > 0 ? best : nil
        case .files(let files):
            let names = ClipboardTextProcessor.normalizeForSearch(files.map(\.name).joined(separator: " "))
            let paths = ClipboardTextProcessor.normalizeForSearch(files.map(\.path).joined(separator: " "))
            var best = scoreField(query: normalizedQuery, candidate: names) ?? 0
            if let pathScore = scoreField(query: normalizedQuery, candidate: paths) { best = max(best, pathScore) }
            if let sourceScore = scoreField(query: normalizedQuery, candidate: source) {
                best = max(best, sourceScore * 0.8)
            }
            return best > 0 ? best : nil
        }
    }

    private static func scoreField(query: String, candidate: String) -> Double? {
        guard !query.isEmpty, !candidate.isEmpty else { return nil }
        if candidate == query { return 1.0 }
        if candidate.hasPrefix(query) { return 0.95 }
        if let range = candidate.range(of: query) {
            let position = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
            return max(0.7, 0.9 - min(0.2, Double(position) * 0.02))
        }
        return fuzzyScore(query: query, candidate: candidate)
    }

    private static func fuzzyScore(query: String, candidate: String) -> Double? {
        guard !query.isEmpty, !candidate.isEmpty else { return nil }
        var queryIndex = query.startIndex
        var positions: [Int] = []
        var candidateIndex = candidate.startIndex
        var position = 0

        while candidateIndex < candidate.endIndex && queryIndex < query.endIndex {
            if candidate[candidateIndex] == query[queryIndex] {
                positions.append(position)
                queryIndex = query.index(after: queryIndex)
            }
            candidateIndex = candidate.index(after: candidateIndex)
            position += 1
        }
        guard queryIndex == query.endIndex, let first = positions.first, let last = positions.last else { return nil }
        let span = max(1, last - first + 1)
        let gaps = span - query.count
        let density = Double(query.count) / Double(span)
        return max(0.55, 0.7 + density * 0.2 - min(0.2, Double(gaps) * 0.02))
    }

    private static func tokenize(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
}
