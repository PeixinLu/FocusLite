import Foundation

enum MatchBucket: Int, Sendable {
    case exact = 10
    case prefix = 9
    case acronymOrInitials = 8
    case token = 7
    case substring = 6
    case fuzzy = 5
}

enum MatchedField: String, Sendable {
    case name
    case token
    case acronym
    case pinyin
    case aliasStrong
    case aliasWeak
    case substring
    case fuzzy
}

struct MatchResult: Sendable {
    let bucket: MatchBucket
    let scoreInBucket: Double
    let finalScore: Double
    let matchedField: MatchedField
    let debug: String?
}

struct QueryInfo: Sendable {
    let raw: String
    let normalized: String
    let length: Int
    let isLatinOnly: Bool
    let hasCJK: Bool
    let tokens: [String]
}

enum Matcher {
    static func queryInfo(for query: String) -> QueryInfo {
        QueryInfoBuilder.build(query)
    }

    static func match(query: String, index: AppNameIndex) -> MatchResult? {
        let info = QueryInfoBuilder.build(query)
        guard !info.normalized.isEmpty else { return nil }
        
        // 过滤低质量查询（大量重复字符）
        if QueryInfoBuilder.isLowQualityQuery(info.normalized) {
            return nil
        }

        var candidates: [Candidate] = []

        candidates.append(contentsOf: exactCandidates(info: info, index: index))
        candidates.append(contentsOf: prefixCandidates(info: info, index: index))
        candidates.append(contentsOf: acronymCandidates(info: info, index: index))
        candidates.append(contentsOf: tokenCandidates(info: info, index: index))
        candidates.append(contentsOf: substringCandidates(info: info, index: index))
        candidates.append(contentsOf: fuzzyCandidates(info: info, index: index))

        guard let best = pickBest(candidates) else { return nil }
        let base = Double(best.bucket.rawValue)
        let finalScore = base + best.scoreInBucket
        return MatchResult(
            bucket: best.bucket,
            scoreInBucket: best.scoreInBucket,
            finalScore: finalScore,
            matchedField: best.field,
            debug: best.debug
        )
    }

    static func shouldInclude(_ result: MatchResult, info: QueryInfo) -> Bool {
        switch result.bucket {
        case .exact, .prefix, .acronymOrInitials:
            return result.scoreInBucket >= 0.6
        case .token:
            if info.length <= 3 {
                return result.scoreInBucket >= 0.78
            }
            return result.scoreInBucket >= 0.7
        case .substring:
            if info.length <= 3 {
                return result.scoreInBucket >= 0.75  // 降低阈值以支持短查询的部分匹配
            }
            return result.scoreInBucket >= 0.7
        case .fuzzy:
            return result.scoreInBucket >= 0.85
        }
    }

    private static func exactCandidates(info: QueryInfo, index: AppNameIndex) -> [Candidate] {
        var result: [Candidate] = []
        if index.normalized == info.normalized {
            result.append(Candidate(bucket: .exact, scoreInBucket: 1.0, field: .name, debug: debug("exact", info, index)))
        }
        if index.aliasStrong.contains(info.normalized) {
            result.append(Candidate(bucket: .exact, scoreInBucket: 1.0, field: .aliasStrong, debug: debug("exact-alias", info, index)))
        }
        return result
    }

    private static func prefixCandidates(info: QueryInfo, index: AppNameIndex) -> [Candidate] {
        guard Gate.allowPrefix(info) else { return [] }
        var result: [Candidate] = []

        if index.normalized.hasPrefix(info.normalized) {
            let score = prefixScore(query: info.normalized, candidate: index.normalized)
            result.append(Candidate(bucket: .prefix, scoreInBucket: score, field: .name, debug: debug("prefix-name", info, index)))
        }

        if let token = index.tokens.first(where: { $0.hasPrefix(info.normalized) }) {
            let score = prefixScore(query: info.normalized, candidate: token)
            result.append(Candidate(bucket: .prefix, scoreInBucket: score, field: .token, debug: debug("prefix-token", info, index)))
        }

        if info.isLatinOnly, let pinyinFull = index.pinyinFull, pinyinFull.hasPrefix(info.normalized) {
            let score = prefixScore(query: info.normalized, candidate: pinyinFull)
            result.append(Candidate(bucket: .prefix, scoreInBucket: score, field: .pinyin, debug: debug("prefix-pinyin", info, index)))
        }

        if let alias = index.aliasStrong.first(where: { $0.hasPrefix(info.normalized) }) {
            let score = min(1.0, prefixScore(query: info.normalized, candidate: alias) + 0.08)
            result.append(Candidate(bucket: .prefix, scoreInBucket: score, field: .aliasStrong, debug: debug("prefix-alias", info, index)))
        }

        return result
    }

    private static func acronymCandidates(info: QueryInfo, index: AppNameIndex) -> [Candidate] {
        guard Gate.allowAcronym(info) else { return [] }
        var result: [Candidate] = []

        if !index.acronym.isEmpty, index.acronym.hasPrefix(info.normalized) {
            let score = prefixScore(query: info.normalized, candidate: index.acronym)
            result.append(Candidate(bucket: .acronymOrInitials, scoreInBucket: score, field: .acronym, debug: debug("acronym", info, index)))
        }

        if info.isLatinOnly, let pinyinInitials = index.pinyinInitials, pinyinInitials.hasPrefix(info.normalized) {
            let score = prefixScore(query: info.normalized, candidate: pinyinInitials)
            result.append(Candidate(bucket: .acronymOrInitials, scoreInBucket: score, field: .pinyin, debug: debug("pinyin-initials", info, index)))
        }

        if let alias = index.aliasStrong.first(where: { $0.hasPrefix(info.normalized) }) {
            let score = min(1.0, prefixScore(query: info.normalized, candidate: alias) + 0.06)
            result.append(Candidate(bucket: .acronymOrInitials, scoreInBucket: score, field: .aliasStrong, debug: debug("alias-strong", info, index)))
        }

        return result
    }

    private static func tokenCandidates(info: QueryInfo, index: AppNameIndex) -> [Candidate] {
        guard Gate.allowToken(info) else { return [] }
        guard !info.tokens.isEmpty else { return [] }

        var matchedTokens = 0
        for token in info.tokens {
            if index.tokens.contains(where: { $0.hasPrefix(token) }) {
                matchedTokens += 1
            }
        }

        if matchedTokens == info.tokens.count {
            let score = min(1.0, 0.78 + 0.04 * Double(max(0, matchedTokens - 1)))
            return [Candidate(bucket: .token, scoreInBucket: score, field: .token, debug: debug("token-all", info, index))]
        }

        if matchedTokens > 0 {
            let score = min(0.85, 0.74 + 0.03 * Double(matchedTokens))
            return [Candidate(bucket: .token, scoreInBucket: score, field: .token, debug: debug("token-partial", info, index))]
        }

        if let alias = index.aliasWeak.first(where: { $0.hasPrefix(info.normalized) }) {
            let score = prefixScore(query: info.normalized, candidate: alias)
            return [Candidate(bucket: .token, scoreInBucket: score, field: .aliasWeak, debug: debug("alias-weak", info, index))]
        }

        return []
    }

    private static func substringCandidates(info: QueryInfo, index: AppNameIndex) -> [Candidate] {
        guard Gate.allowSubstring(info) else { return [] }
        var candidates: [Candidate] = []
        
        // Check main name
        if let positions = positionsForSubstring(info.normalized, in: index.normalized) {
            let startBonus = positions.first == 0 ? 0.08 : 0.0
            let lengthRatio = Double(info.length) / Double(max(1, index.normalized.count))
            let score = min(0.9, 0.7 + startBonus + 0.15 * lengthRatio)
            candidates.append(Candidate(bucket: .substring, scoreInBucket: score, field: .substring, debug: debug("substring", info, index)))
        }
        
        // Check strong aliases (extra field contains aliases like "设置" for "系统设置")
        for alias in index.aliasStrong {
            if alias.contains(info.normalized) {
                let startBonus = alias.hasPrefix(info.normalized) ? 0.08 : 0.0
                let lengthRatio = Double(info.length) / Double(max(1, alias.count))
                // Slightly higher score for alias matches to prioritize them
                let score = min(0.92, 0.72 + startBonus + 0.15 * lengthRatio)
                candidates.append(Candidate(bucket: .substring, scoreInBucket: score, field: .aliasStrong, debug: debug("substring-alias", info, index)))
                break // Take the first matching alias
            }
        }
        
        return candidates
    }

    private static func fuzzyCandidates(info: QueryInfo, index: AppNameIndex) -> [Candidate] {
        guard Gate.allowFuzzy(info) else { return [] }
        guard let positions = positionsForSubsequence(info.normalized, in: index.normalized) else { return [] }
        let score = fuzzyScore(queryLength: info.length, candidateLength: index.normalized.count, positions: positions)
        return [Candidate(bucket: .fuzzy, scoreInBucket: score, field: .fuzzy, debug: debug("fuzzy", info, index))]
    }

    private static func pickBest(_ candidates: [Candidate]) -> Candidate? {
        candidates.max { lhs, rhs in
            if lhs.bucket.rawValue != rhs.bucket.rawValue {
                return lhs.bucket.rawValue < rhs.bucket.rawValue
            }
            if lhs.scoreInBucket != rhs.scoreInBucket {
                return lhs.scoreInBucket < rhs.scoreInBucket
            }
            return lhs.field.rawValue < rhs.field.rawValue
        }
    }

    private static func prefixScore(query: String, candidate: String) -> Double {
        let ratio = Double(query.count) / Double(max(1, candidate.count))
        return min(1.0, max(0.6, ratio + 0.2))
    }

    private static func fuzzyScore(queryLength: Int, candidateLength: Int, positions: [Int]) -> Double {
        guard let first = positions.first, let last = positions.last else { return 0 }
        let span = max(1, last - first + 1)
        let density = Double(queryLength) / Double(span)
        let consecutiveRatio = consecutiveRatioFor(positions)
        let lengthRatio = Double(queryLength) / Double(candidateLength)
        let startBonus = first == 0 ? 0.06 : 0.0
        let raw = (0.55 * density) + (0.25 * consecutiveRatio) + (0.1 * lengthRatio) + startBonus
        return min(0.92, max(0.6, raw))
    }

    private static func consecutiveRatioFor(_ positions: [Int]) -> Double {
        guard positions.count > 1 else { return 1.0 }
        var consecutive = 0
        for index in 1..<positions.count where positions[index] == positions[index - 1] + 1 {
            consecutive += 1
        }
        return Double(consecutive) / Double(positions.count - 1)
    }

    private static func positionsForSubstring(_ query: String, in candidate: String) -> [Int]? {
        guard let range = candidate.range(of: query) else { return nil }
        let start = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
        return Array(start..<(start + query.count))
    }

    private static func positionsForSubsequence(_ query: String, in candidate: String) -> [Int]? {
        var positions: [Int] = []
        var searchIndex = candidate.startIndex

        for char in query {
            guard let foundIndex = candidate[searchIndex...].firstIndex(of: char) else {
                return nil
            }
            let position = candidate.distance(from: candidate.startIndex, to: foundIndex)
            positions.append(position)
            searchIndex = candidate.index(after: foundIndex)
        }

        return positions
    }

    private static func debug(_ tag: String, _ info: QueryInfo, _ index: AppNameIndex) -> String? {
        #if DEBUG
        return "[\(tag)] q=\(info.normalized) name=\(index.normalized)"
        #else
        return nil
        #endif
    }
}

private struct Candidate {
    let bucket: MatchBucket
    let scoreInBucket: Double
    let field: MatchedField
    let debug: String?
}

private enum Gate {
    static func allowPrefix(_ info: QueryInfo) -> Bool {
        info.length >= 1
    }

    static func allowAcronym(_ info: QueryInfo) -> Bool {
        info.length >= 1
    }

    static func allowToken(_ info: QueryInfo) -> Bool {
        info.length >= 2
    }

    static func allowSubstring(_ info: QueryInfo) -> Bool {
        return info.length >= 2
    }

    static func allowFuzzy(_ info: QueryInfo) -> Bool {
        guard info.length >= 5 else { return false }
        return info.isLatinOnly
    }
}

enum QueryInfoBuilder {
    static func build(_ query: String) -> QueryInfo {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = MatchingNormalizer.normalize(trimmed)
        let tokens = MatchingNormalizer.tokens(from: trimmed)
            .map { MatchingNormalizer.normalize($0) }
            .filter { !$0.isEmpty }
        let scalars = normalized.unicodeScalars
        let isLatinOnly = !normalized.isEmpty && scalars.allSatisfy { $0.isASCII && ($0.properties.isAlphabetic || $0.properties.numericType != nil) }
        let hasCJK = scalars.contains { MatchingNormalizer.isCJKUnifiedIdeograph($0) }
        return QueryInfo(
            raw: trimmed,
            normalized: normalized,
            length: normalized.count,
            isLatinOnly: isLatinOnly,
            hasCJK: hasCJK,
            tokens: tokens
        )
    }
    
    /// 检测查询是否为低质量（过多重复字符）
    static func isLowQualityQuery(_ query: String) -> Bool {
        guard query.count >= 5 else { return false }
        
        // 统计每个字符出现的次数
        var charCounts: [Character: Int] = [:]
        for char in query {
            charCounts[char, default: 0] += 1
        }
        
        // 如果任何单个字符占比超过60%，认为是低质量查询
        let maxCount = charCounts.values.max() ?? 0
        let repetitionRatio = Double(maxCount) / Double(query.count)
        if repetitionRatio > 0.6 {
            return true
        }
        
        // 如果唯一字符数太少（少于总长度的30%），认为是低质量
        let uniqueChars = charCounts.keys.count
        let uniqueRatio = Double(uniqueChars) / Double(query.count)
        if uniqueRatio < 0.3 {
            return true
        }
        
        return false
    }
}
