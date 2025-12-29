import Foundation

struct AppNameIndex: Codable, Hashable, Sendable {
    let original: String
    let normalized: String
    let tokens: [String]
    let acronym: String
    let pinyinFull: String?
    let pinyinInitials: String?
    let aliasStrong: [String]
    let aliasWeak: [String]

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

        let strongSet = Set(normalizedFull + normalizedInitials + normalizedExtra)
        aliasStrong = strongSet.sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        var weakCandidates = tokens
        if !acronym.isEmpty {
            weakCandidates.append(acronym)
        }
        if let pinyinInitials {
            weakCandidates.append(pinyinInitials)
        }
        let weakSet = Set(weakCandidates).subtracting(strongSet)
        aliasWeak = weakSet.sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        original = try container.decode(String.self, forKey: .original)
        normalized = try container.decode(String.self, forKey: .normalized)
        tokens = try container.decode([String].self, forKey: .tokens)
        acronym = try container.decode(String.self, forKey: .acronym)
        pinyinFull = try container.decodeIfPresent(String.self, forKey: .pinyinFull)
        pinyinInitials = try container.decodeIfPresent(String.self, forKey: .pinyinInitials)
        aliasStrong = try container.decodeIfPresent([String].self, forKey: .aliasStrong) ?? []
        aliasWeak = try container.decodeIfPresent([String].self, forKey: .aliasWeak) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(original, forKey: .original)
        try container.encode(normalized, forKey: .normalized)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(acronym, forKey: .acronym)
        try container.encodeIfPresent(pinyinFull, forKey: .pinyinFull)
        try container.encodeIfPresent(pinyinInitials, forKey: .pinyinInitials)
        try container.encode(aliasStrong, forKey: .aliasStrong)
        try container.encode(aliasWeak, forKey: .aliasWeak)
    }

    private enum CodingKeys: String, CodingKey {
        case original
        case normalized
        case tokens
        case acronym
        case pinyinFull
        case pinyinInitials
        case aliasStrong
        case aliasWeak
    }
}

struct AliasEntry: Codable, Hashable, Sendable {
    let full: [String]
    let initials: [String]
    let extra: [String]
}

struct AliasStore: Sendable {
    private let nameMap: [String: AliasEntry]
    private let bundleMap: [String: AliasEntry]

    static let builtIn = AliasStore(nameMap: [
        "微信": AliasEntry(full: ["weixin", "wechat"], initials: ["wx"], extra: []),
        "WeChat": AliasEntry(full: ["weixin", "wechat"], initials: ["wx"], extra: ["微信"]),
        "Terminal": AliasEntry(full: [], initials: [], extra: ["终端"]),
        "系统设置": AliasEntry(full: [], initials: [], extra: ["设置"]),
        "支付宝": AliasEntry(full: ["zhifubao"], initials: ["zfb"], extra: []),
        "QQ音乐": AliasEntry(full: ["qqyinyue", "qqmusic"], initials: ["qqyy"], extra: []),
        "网易云音乐": AliasEntry(full: ["wangyiyun", "wangyiyunyinyue"], initials: ["wyy"], extra: []),
        "Final Cut Pro": AliasEntry(full: [], initials: ["fcp"], extra: []),
        "Visual Studio Code": AliasEntry(full: [], initials: ["vsc"], extra: ["vscode"])
    ], bundleMap: [:])

    init(nameMap: [String: AliasEntry], bundleMap: [String: AliasEntry]) {
        self.nameMap = nameMap
        self.bundleMap = bundleMap
    }

    init(userAliases: [String: [String]], bundleAliases: [String: [String]] = [:]) {
        nameMap = AliasStore.buildMap(from: userAliases)
        bundleMap = AliasStore.buildMap(from: bundleAliases)
    }

    func entry(for name: String, bundleID: String?) -> AliasEntry? {
        if let bundleID, let entry = bundleMap[bundleID] {
            return entry
        }
        return nameMap[name]
    }

    func merged(with other: AliasStore) -> AliasStore {
        let mergedNames = AliasStore.mergeMap(nameMap, other.nameMap)
        let mergedBundles = AliasStore.mergeMap(bundleMap, other.bundleMap)
        return AliasStore(nameMap: mergedNames, bundleMap: mergedBundles)
    }

    static func loadUserAliases(from url: URL) -> AliasStore {
        guard let data = try? Data(contentsOf: url) else {
            return AliasStore(nameMap: [:], bundleMap: [:])
        }

        struct Payload: Codable {
            let byBundleID: [String: [String]]?
            let byName: [String: [String]]?
            let aliases: [String: [String]]?
        }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return AliasStore(nameMap: [:], bundleMap: [:])
        }

        let byName = payload.byName ?? payload.aliases ?? [:]
        let byBundleID = payload.byBundleID ?? [:]
        return AliasStore(userAliases: byName, bundleAliases: byBundleID)
    }

    private static func buildMap(from source: [String: [String]]) -> [String: AliasEntry] {
        var derived: [String: AliasEntry] = [:]
        for (name, aliases) in source {
            let grouped = splitAliases(aliases)
            derived[name] = grouped
        }
        return derived
    }

    private static func mergeMap(_ lhs: [String: AliasEntry], _ rhs: [String: AliasEntry]) -> [String: AliasEntry] {
        var merged = lhs
        for (name, entry) in rhs {
            if let existing = merged[name] {
                merged[name] = AliasEntry(
                    full: Array(Set(existing.full + entry.full)),
                    initials: Array(Set(existing.initials + entry.initials)),
                    extra: Array(Set(existing.extra + entry.extra))
                )
            } else {
                merged[name] = entry
            }
        }
        return merged
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

    static func isCJKUnifiedIdeograph(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0x2A700...0x2B73F,
             0x2B740...0x2B81F, 0x2B820...0x2CEAF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}
