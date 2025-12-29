import AppKit
import Foundation

struct ClipboardProvider: ResultProvider {
    static let providerID = "clipboard"
    let id = ClipboardProvider.providerID
    let displayName = "Clipboard"

    private let store: ClipboardStore

    init(store: ClipboardStore = .shared) {
        self.store = store
        Task {
            await store.loadIfNeeded()
        }
    }

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && !isScoped {
            return []
        }

        let entries = await store.snapshot()
        if trimmed.isEmpty && isScoped {
            return entries.enumerated().map { index, entry in
                resultItem(entry: entry, score: 1.0 - Double(index) * 0.001, query: "")
            }
        }
        var matches: [(ClipboardEntry, Double)] = []
        matches.reserveCapacity(min(entries.count, 60))

        for entry in entries {
            guard let score = ClipboardMatcher.score(query: trimmed, entry: entry) else { continue }
            matches.append((entry, score))
        }

        return matches
            .sorted { $0.1 > $1.1 }
            .map { resultItem(entry: $0.0, score: $0.1, query: trimmed) }
    }

    private func resultItem(entry: ClipboardEntry, score: Double, query: String) -> ResultItem {
        switch entry.content {
        case .text(let text):
            let action: ResultAction = ClipboardPreferences.autoPasteAfterSelect
                ? .pasteText(text)
                : .copyText(text)
            return ResultItem(
                title: contentPreview(text),
                subtitle: subtitle(for: entry),
                icon: .system("doc.on.clipboard"),
                score: score,
                action: action,
                providerID: id,
                category: .standard,
                preview: .text(text)
            )
        case .image(let image):
            let sizeText = imageSizeText(width: image.width, height: image.height)
            let formatText = imageFormatText(from: image.type)
            let title = query.isEmpty ? sizeText : sizeText + " (\(query))"
            let imageData = loadImageData(from: image.path)
            return ResultItem(
                title: formatText.isEmpty ? title : "\(formatText) \(title)",
                subtitle: subtitle(for: entry),
                icon: .system("photo"),
                score: score,
                action: imageData.map { .copyImage(data: $0, type: image.type) } ?? .none,
                providerID: id,
                category: .standard,
                preview: imageData.map { .image($0) }
            )
        case .files(let files):
            let firstName = files.first?.name ?? "File"
            let countText = files.count > 1 ? " (\(files.count))" : ""
            let title = firstName + countText
            return ResultItem(
                title: title,
                subtitle: subtitle(for: entry, extra: files.count > 1 ? files[1...].map(\.name).joined(separator: ", ") : nil),
                icon: .system("folder"),
                score: score,
                action: .copyFiles(files.map { $0.path }),
                providerID: id,
                category: .standard,
                preview: .files(files)
            )
        }
    }

    private func contentPreview(_ content: String, limit: Int = 120) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if collapsed.count <= limit {
            return collapsed
        }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<endIndex]) + "..."
    }

    private func subtitle(for entry: ClipboardEntry, extra: String? = nil) -> String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let time = formatter.localizedString(for: entry.createdAt, relativeTo: Date())
        var parts: [String] = [time]
        if let source = entry.sourceAppName, !source.isEmpty {
            parts.append(source)
        }
        if let extra, !extra.isEmpty {
            parts.append(extra)
        }
        return parts.joined(separator: " - ")
    }

    private func imageSizeText(width: Int, height: Int) -> String {
        if width == 0 && height == 0 {
            return "Image"
        }
        return "Image \(width)x\(height)"
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

    private func loadImageData(from path: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: path))
    }
}

private enum ClipboardMatcher {
    static func score(query: String, entry: ClipboardEntry) -> Double? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return nil }

        let source = normalize(entry.sourceAppName ?? "")

        switch entry.content {
        case .text(let text):
            let content = normalize(text)
            var best = scoreField(query: normalizedQuery, candidate: content) ?? 0
            if let sourceScore = scoreField(query: normalizedQuery, candidate: source) {
                best = max(best, sourceScore * 0.9)
            }
            if best == 0 {
                return nil
            }
            let tokens = tokenize(normalizedQuery)
            if tokens.count > 1 {
                let haystack = content + " " + source
                if tokens.allSatisfy({ haystack.contains($0) }) {
                    best = min(1.0, best + 0.05)
                }
            }
            return best
        case .image:
            // Allow basic keyword search for "img"/"image" or source app.
            let label = "image photo screenshot"
            var best = scoreField(query: normalizedQuery, candidate: label) ?? 0
            if let sourceScore = scoreField(query: normalizedQuery, candidate: source) {
                best = max(best, sourceScore * 0.8)
            }
            return best > 0 ? best : nil
        case .files(let files):
            let names = files.map { normalize($0.name) }.joined(separator: " ")
            let paths = files.map { normalize($0.path) }.joined(separator: " ")
            var best = scoreField(query: normalizedQuery, candidate: names) ?? 0
            if let pathScore = scoreField(query: normalizedQuery, candidate: paths) {
                best = max(best, pathScore)
            }
            if let sourceScore = scoreField(query: normalizedQuery, candidate: source) {
                best = max(best, sourceScore * 0.8)
            }
            return best > 0 ? best : nil
        }
    }

    private static func scoreField(query: String, candidate: String) -> Double? {
        guard !query.isEmpty, !candidate.isEmpty else { return nil }

        if candidate == query {
            return 1.0
        }

        if candidate.hasPrefix(query) {
            return 0.95
        }

        if let range = candidate.range(of: query) {
            let position = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
            let penalty = min(0.2, Double(position) * 0.02)
            return max(0.7, 0.9 - penalty)
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

        guard queryIndex == query.endIndex, let first = positions.first, let last = positions.last else {
            return nil
        }

        let span = max(1, last - first + 1)
        let gaps = span - query.count
        let density = Double(query.count) / Double(span)
        let gapPenalty = min(0.2, Double(gaps) * 0.02)

        return max(0.55, 0.7 + density * 0.2 - gapPenalty)
    }

    private static func tokenize(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
    }

    private static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
        var output = ""
        output.reserveCapacity(folded.count)

        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar) || isCJK(scalar) {
                output.unicodeScalars.append(scalar)
            } else {
                output.append(" ")
            }
        }

        return output.lowercased()
    }

    private static func isCJK(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}
