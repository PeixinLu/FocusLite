import Foundation

struct AppNameIndex: Codable, Hashable, Sendable {
    let original: String
    let normalized: String
    let tokens: [String]
    let acronym: String
    let pinyinFull: String?
    let pinyinInitials: String?
    let aliases: [String]

    init(name: String, aliasEntry: AliasEntry?, pinyinProvider: PinyinProvider?) {
        original = name
        normalized = MatchingNormalizer.normalize(name)
        tokens = MatchingNormalizer.tokens(from: name)
        acronym = MatchingNormalizer.acronym(from: tokens)

        let normalizedFull = aliasEntry?.full.map { MatchingNormalizer.normalize($0) }.filter { !$0.isEmpty } ?? []
        let normalizedInitials = aliasEntry?.initials.map { MatchingNormalizer.normalize($0) }.filter { !$0.isEmpty } ?? []
        let normalizedExtra = aliasEntry?.extra.map { MatchingNormalizer.normalize($0) }.filter { !$0.isEmpty } ?? []

        if !normalizedFull.isEmpty || !normalizedInitials.isEmpty {
            pinyinFull = normalizedFull.first
            pinyinInitials = normalizedInitials.first
        } else if let pinyinProvider = pinyinProvider, let pinyin = pinyinProvider.pinyin(for: name) {
            pinyinFull = pinyin.full
            pinyinInitials = pinyin.initials
        } else {
            pinyinFull = nil
            pinyinInitials = nil
        }

        let uniqueAliases = Set(normalizedFull + normalizedInitials + normalizedExtra)
        aliases = uniqueAliases.sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }
}

struct AliasEntry: Codable, Hashable, Sendable {
    let full: [String]
    let initials: [String]
    let extra: [String]
}

struct AliasStore: Sendable {
    private let map: [String: AliasEntry]

    static let builtIn = AliasStore(map: [
        "微信": AliasEntry(full: ["weixin", "wechat"], initials: ["wx"], extra: []),
        "支付宝": AliasEntry(full: ["zhifubao"], initials: ["zfb"], extra: []),
        "QQ音乐": AliasEntry(full: ["qqyinyue", "qqmusic"], initials: ["qqyy"], extra: []),
        "网易云音乐": AliasEntry(full: ["wangyiyun", "wangyiyunyinyue"], initials: ["wyy"], extra: []),
        "Final Cut Pro": AliasEntry(full: [], initials: ["fcp"], extra: []),
        "Visual Studio Code": AliasEntry(full: [], initials: ["vsc"], extra: ["vscode"])
    ])

    init(map: [String: AliasEntry]) {
        self.map = map
    }

    init(userAliases: [String: [String]]) {
        var derived: [String: AliasEntry] = [:]
        for (name, aliases) in userAliases {
            let grouped = AliasStore.splitAliases(aliases)
            derived[name] = grouped
        }
        map = derived
    }

    func entry(for name: String) -> AliasEntry? {
        map[name]
    }

    func merged(with other: AliasStore) -> AliasStore {
        var mergedMap = map
        for (name, entry) in other.map {
            if let existing = mergedMap[name] {
                mergedMap[name] = AliasEntry(
                    full: Array(Set(existing.full + entry.full)),
                    initials: Array(Set(existing.initials + entry.initials)),
                    extra: Array(Set(existing.extra + entry.extra))
                )
            } else {
                mergedMap[name] = entry
            }
        }
        return AliasStore(map: mergedMap)
    }

    static func loadUserAliases(from url: URL) -> AliasStore {
        guard let data = try? Data(contentsOf: url) else {
            return AliasStore(map: [:])
        }

        struct Payload: Codable {
            let aliases: [String: [String]]
        }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return AliasStore(map: [:])
        }

        return AliasStore(userAliases: payload.aliases)
    }

    private static func splitAliases(_ aliases: [String]) -> AliasEntry {
        AliasEntry(full: [], initials: [], extra: aliases)
    }
}

enum MatchingNormalizer {
    static func normalize(_ input: String) -> String {
        let folded = input.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
        let lowercased = folded.lowercased()
        let scalars = lowercased.unicodeScalars.filter { isAllowedScalar($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    static func tokens(from input: String) -> [String] {
        let rawParts = input.split { !$0.isLetter && !$0.isNumber }
        var result: [String] = []
        result.reserveCapacity(rawParts.count)

        for part in rawParts {
            let subTokens = splitCamelCase(part)
            for token in subTokens {
                let folded = normalize(token)
                if !folded.isEmpty {
                    result.append(folded)
                }
            }
        }

        return result
    }

    static func acronym(from tokens: [String]) -> String {
        var initials = ""
        initials.reserveCapacity(tokens.count)

        for token in tokens {
            guard token.unicodeScalars.allSatisfy({ $0.isASCII }) else { continue }
            if let first = token.first {
                initials.append(first)
            }
        }

        return initials
    }

    private static func splitCamelCase(_ token: Substring) -> [String] {
        let chars = Array(token)
        guard !chars.isEmpty else { return [] }
        var result: [String] = []
        var current = ""

        for index in chars.indices {
            let char = chars[index]
            let prev = index > 0 ? chars[index - 1] : nil
            let next = index + 1 < chars.count ? chars[index + 1] : nil

            if let prev = prev {
                if isLowercase(prev), isUppercase(char) {
                    if !current.isEmpty {
                        result.append(current)
                        current = ""
                    }
                } else if isUppercase(prev), isUppercase(char), let next = next, isLowercase(next) {
                    if !current.isEmpty {
                        result.append(current)
                        current = ""
                    }
                }
            }

            current.append(char)
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }

    private static func isLowercase(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        return scalar.properties.isLowercase
    }

    private static func isUppercase(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        return scalar.properties.isUppercase
    }

    private static func isAllowedScalar(_ scalar: UnicodeScalar) -> Bool {
        if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
            return true
        }
        return isCJKUnifiedIdeograph(scalar)
    }

    private static func isCJKUnifiedIdeograph(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0x2A700...0x2B73F,
             0x2B740...0x2B81F, 0x2B820...0x2CEAF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}
