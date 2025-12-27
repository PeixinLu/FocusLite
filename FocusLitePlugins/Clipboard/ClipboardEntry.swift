import Foundation

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

enum ClipboardContent: Codable, Hashable, Sendable {
    case text(String)
    case image(ClipboardImageItem)
    case files([FilePreviewItem])
}

struct ClipboardImageItem: Codable, Hashable, Sendable {
    let path: String
    let type: String
    let width: Int
    let height: Int
}

extension ClipboardContent {
    private enum CodingKeys: String, CodingKey {
        case kind
        case text
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
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .text:
            let value = try container.decode(String.self, forKey: .text)
            self = .text(value)
        case .image:
            let value = try container.decode(ClipboardImageItem.self, forKey: .image)
            self = .image(value)
        case .files:
            let value = try container.decode([FilePreviewItem].self, forKey: .files)
            self = .files(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(value, forKey: .text)
        case .image(let value):
            try container.encode(Kind.image, forKey: .kind)
            try container.encode(value, forKey: .image)
        case .files(let value):
            try container.encode(Kind.files, forKey: .kind)
            try container.encode(value, forKey: .files)
        }
    }
}
