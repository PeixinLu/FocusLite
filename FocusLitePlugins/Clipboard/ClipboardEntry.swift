import Foundation

enum ClipboardTextPolicy {
    static let titleCharacterLimit = 160
    static let previewByteLimit = 8 * 1024
    static let previewLineLimit = 40
    static let searchHeadByteLimit = 32 * 1024
    static let searchTailByteLimit = 4 * 1024
    static let inlineStorageByteLimit = 16 * 1024
    static let maximumCapturedTextBytes = 16 * 1024 * 1024
    static let initialResultLimit = 80
    static let searchResultLimit = 100
}

struct ClipboardEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let content: ClipboardContent
    let createdAt: Date
    let sourceBundleID: String?
    let sourceAppName: String?
    let contentHash: String

    init(
        id: UUID = UUID(),
        content: ClipboardContent,
        createdAt: Date = Date(),
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil,
        contentHash: String
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.contentHash = contentHash
    }
}

enum ClipboardTextStorage: Codable, Hashable, Sendable {
    case inline(String)
    case file(String)
}

struct ClipboardTextItem: Codable, Hashable, Sendable {
    let title: String
    let previewText: String
    let searchText: String
    let byteCount: Int
    let lineCount: Int
    let isPreviewTruncated: Bool
    let storage: ClipboardTextStorage

    func replacingStorage(_ storage: ClipboardTextStorage) -> ClipboardTextItem {
        ClipboardTextItem(
            title: title,
            previewText: previewText,
            searchText: searchText,
            byteCount: byteCount,
            lineCount: lineCount,
            isPreviewTruncated: isPreviewTruncated,
            storage: storage
        )
    }
}

enum ClipboardTextProcessor {
    static func makeItem(text: String, storage: ClipboardTextStorage) -> ClipboardTextItem {
        let byteCount = text.utf8.count
        let preview = boundedPrefix(
            text,
            byteLimit: ClipboardTextPolicy.previewByteLimit,
            lineLimit: ClipboardTextPolicy.previewLineLimit
        )
        return ClipboardTextItem(
            title: makeTitle(from: text),
            previewText: preview.text,
            searchText: normalizeForSearch(searchExcerpt(from: text)),
            byteCount: byteCount,
            lineCount: text.reduce(into: 1) { count, character in
                if character == "\n" { count += 1 }
            },
            isPreviewTruncated: preview.isTruncated,
            storage: storage
        )
    }

    static func makeTitle(from text: String) -> String {
        var output = ""
        output.reserveCapacity(ClipboardTextPolicy.titleCharacterLimit)
        var hasVisibleContent = false
        var pendingWhitespace = false
        var reachedLimit = false

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)
            if character.isWhitespace {
                if hasVisibleContent { pendingWhitespace = true }
                index = nextIndex
                continue
            }
            if pendingWhitespace && output.count < ClipboardTextPolicy.titleCharacterLimit {
                output.append(" ")
            }
            pendingWhitespace = false
            guard output.count < ClipboardTextPolicy.titleCharacterLimit else {
                reachedLimit = true
                break
            }
            output.append(character)
            hasVisibleContent = true
            if output.count >= ClipboardTextPolicy.titleCharacterLimit {
                reachedLimit = nextIndex < text.endIndex
                break
            }
            index = nextIndex
        }

        if reachedLimit { output.append("…") }
        return output.isEmpty ? "空文本" : output
    }

    static func normalizeForSearch(_ text: String) -> String {
        let folded = text.folding(
            options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive],
            locale: .current
        )
        var output = ""
        output.reserveCapacity(folded.count)
        var previousWasSpace = false

        for scalar in folded.unicodeScalars {
            let isSearchable = CharacterSet.alphanumerics.contains(scalar) || isCJK(scalar)
            if isSearchable {
                output.unicodeScalars.append(scalar)
                previousWasSpace = false
            } else if !previousWasSpace {
                output.append(" ")
                previousWasSpace = true
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func searchExcerpt(from text: String) -> String {
        let head = boundedPrefix(text, byteLimit: ClipboardTextPolicy.searchHeadByteLimit, lineLimit: nil)
        guard head.isTruncated else { return head.text }
        return head.text + "\n" + boundedSuffix(text, byteLimit: ClipboardTextPolicy.searchTailByteLimit)
    }

    private static func boundedPrefix(
        _ text: String,
        byteLimit: Int,
        lineLimit: Int?
    ) -> (text: String, isTruncated: Bool) {
        var output = ""
        output.reserveCapacity(min(text.count, byteLimit))
        var bytes = 0
        var lines = 1
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let characterBytes = character.utf8.count
            if bytes + characterBytes > byteLimit { break }
            if let lineLimit, lines > lineLimit { break }
            output.append(character)
            bytes += characterBytes
            index = text.index(after: index)
            if character == "\n" {
                lines += 1
                if let lineLimit, lines > lineLimit { break }
            }
        }
        return (output, index < text.endIndex)
    }

    private static func boundedSuffix(_ text: String, byteLimit: Int) -> String {
        var characters: [Character] = []
        var bytes = 0
        var index = text.endIndex

        while index > text.startIndex {
            let previous = text.index(before: index)
            let character = text[previous]
            let characterBytes = character.utf8.count
            guard bytes + characterBytes <= byteLimit else { break }
            characters.append(character)
            bytes += characterBytes
            index = previous
        }
        return String(characters.reversed())
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

enum ClipboardContent: Codable, Hashable, Sendable {
    case text(ClipboardTextItem)
    case image(ClipboardImageItem)
    case files([FilePreviewItem])
}

struct ClipboardImageItem: Codable, Hashable, Sendable {
    let path: String
    let type: String
    let width: Int
    let height: Int
    let byteCount: Int?
}

extension ClipboardContent {
    private enum CodingKeys: String, CodingKey {
        case kind
        case text
        case textItem
        case image
        case files
    }

    private enum Kind: String, Codable {
        case text
        case image
        case files
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .text:
            if let item = try container.decodeIfPresent(ClipboardTextItem.self, forKey: .textItem) {
                self = .text(item)
            } else {
                let legacyText = try container.decode(String.self, forKey: .text)
                self = .text(ClipboardTextProcessor.makeItem(text: legacyText, storage: .inline(legacyText)))
            }
        case .image:
            self = .image(try container.decode(ClipboardImageItem.self, forKey: .image))
        case .files:
            self = .files(try container.decode([FilePreviewItem].self, forKey: .files))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(value, forKey: .textItem)
        case .image(let value):
            try container.encode(Kind.image, forKey: .kind)
            try container.encode(value, forKey: .image)
        case .files(let value):
            try container.encode(Kind.files, forKey: .kind)
            try container.encode(value, forKey: .files)
        }
    }
}
