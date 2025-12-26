import Foundation

struct MatchResult: Sendable {
    let score: Double
    let debug: MatchDebug
    let highlights: [Int]
}

struct MatchDebug: Sendable {
    let normalizedQuery: String
    let normalizedName: String
    let types: [MatchType]
    let scoreBreakdown: [ScorePart]
    let positions: [Int]

    struct ScorePart: Sendable {
        let type: MatchType
        let score: Double
    }
}

extension MatchDebug: CustomStringConvertible {
    var description: String {
        let typeList = types.map { $0.rawValue }.joined(separator: ",")
        let breakdownList = scoreBreakdown
            .map { "\($0.type.rawValue)=\(String(format: "%.2f", $0.score))" }
            .joined(separator: ",")
        return "[MatchDebug] query=\(normalizedQuery) name=\(normalizedName) types=[\(typeList)] breakdown=[\(breakdownList)] positions=\(positions)"
    }
}

enum MatchType: String, Sendable {
    case exact
    case prefix
    case substring
    case tokenAll
    case token
    case acronym
    case pinyinFull
    case pinyinInitials
    case alias
    case fuzzy
    case tokenBonus

    var priority: Int {
        switch self {
        case .exact: return 0
        case .prefix: return 1
        case .substring: return 2
        case .tokenAll: return 3
        case .token: return 4
        case .alias: return 5
        case .acronym: return 6
        case .pinyinFull: return 7
        case .pinyinInitials: return 8
        case .fuzzy: return 9
        case .tokenBonus: return 10
        }
    }
}

enum Matcher {
    static func match(query: String, index: AppNameIndex) -> MatchResult? {
        let normalizedQuery = MatchingNormalizer.normalize(query)
        guard !normalizedQuery.isEmpty else { return nil }

        let tokenQueries = MatchingNormalizer.tokens(from: query)
            .map { MatchingNormalizer.normalize($0) }
            .filter { !$0.isEmpty }

        var best = evaluateToken(normalizedQuery, index: index)

        var tokenMatches: [MatchCandidate] = []
        var matchedTokenCount = 0
        for token in tokenQueries {
            if let candidate = evaluateToken(token, index: index) {
                matchedTokenCount += 1
                tokenMatches.append(candidate)
            }
        }

        if best == nil && tokenMatches.isEmpty {
            return nil
        }

        if tokenQueries.count > 1, matchedTokenCount == tokenQueries.count {
            let tokenAll = MatchCandidate(
                score: 0.88,
                types: [.tokenAll],
                breakdown: [.init(type: .tokenAll, score: 0.88)],
                positions: []
            )
            best = pickBest(lhs: best, rhs: tokenAll)
        }

        if let strongestToken = tokenMatches.max(by: { $0.score < $1.score }) {
            best = pickBest(lhs: best, rhs: strongestToken)
        }

        if tokenQueries.count > 1, matchedTokenCount > 1, var updated = best {
            let bonus = min(0.08, 0.03 * Double(matchedTokenCount - 1))
            if bonus > 0 {
                updated.score = min(1.0, updated.score + bonus)
                updated.types.append(.tokenBonus)
                updated.breakdown.append(.init(type: .tokenBonus, score: bonus))
                best = updated
            }
        }

        guard let final = best else { return nil }

        let debug = MatchDebug(
            normalizedQuery: normalizedQuery,
            normalizedName: index.normalized,
            types: final.types,
            scoreBreakdown: final.breakdown,
            positions: final.positions
        )
        return MatchResult(score: final.score, debug: debug, highlights: final.positions)
    }

    private static func evaluateToken(_ query: String, index: AppNameIndex) -> MatchCandidate? {
        var candidates: [MatchCandidate] = []

        if index.normalized == query {
            candidates.append(candidate(type: .exact, score: 1.0, positions: positionsForPrefix(query, in: index.normalized)))
        } else if index.normalized.hasPrefix(query) {
            candidates.append(candidate(type: .prefix, score: 0.95, positions: positionsForPrefix(query, in: index.normalized)))
        } else if let substringPositions = positionsForSubstring(query, in: index.normalized) {
            candidates.append(candidate(type: .substring, score: 0.90, positions: substringPositions))
        }

        if index.tokens.contains(query) {
            candidates.append(candidate(type: .token, score: 0.88, positions: positionsForPrefix(query, in: query)))
        } else if index.tokens.contains(where: { $0.hasPrefix(query) }) {
            candidates.append(candidate(type: .token, score: 0.85, positions: positionsForPrefix(query, in: query)))
        }

        if !index.acronym.isEmpty {
            if index.acronym == query {
                candidates.append(candidate(type: .acronym, score: 0.86, positions: positionsForPrefix(query, in: index.acronym)))
            } else if index.acronym.hasPrefix(query) {
                candidates.append(candidate(type: .acronym, score: 0.84, positions: positionsForPrefix(query, in: index.acronym)))
            }
        }

        if let pinyinFull = index.pinyinFull {
            if pinyinFull == query {
                candidates.append(candidate(type: .pinyinFull, score: 0.85, positions: positionsForPrefix(query, in: pinyinFull)))
            } else if pinyinFull.hasPrefix(query) {
                candidates.append(candidate(type: .pinyinFull, score: 0.82, positions: positionsForPrefix(query, in: pinyinFull)))
            }
        }

        if let pinyinInitials = index.pinyinInitials {
            if pinyinInitials == query {
                candidates.append(candidate(type: .pinyinInitials, score: 0.83, positions: positionsForPrefix(query, in: pinyinInitials)))
            } else if pinyinInitials.hasPrefix(query) {
                candidates.append(candidate(type: .pinyinInitials, score: 0.80, positions: positionsForPrefix(query, in: pinyinInitials)))
            }
        }

        if let aliasMatch = matchAlias(query, index: index) {
            candidates.append(aliasMatch)
        }

        if query.count <= 4 {
            for token in index.tokens where token.unicodeScalars.allSatisfy({ $0.isASCII }) {
                if let positions = positionsForSubsequence(query, in: token) {
                    candidates.append(candidate(type: .acronym, score: 0.84, positions: positions))
                    break
                }
            }
        }

        if let fuzzy = fuzzyCandidate(query, candidateText: index.normalized) {
            candidates.append(fuzzy)
        }

        return candidates.max(by: { scoreOrder(lhs: $0, rhs: $1) })
    }

    private static func matchAlias(_ query: String, index: AppNameIndex) -> MatchCandidate? {
        guard !index.aliases.isEmpty else { return nil }
        let reserved = Set([index.pinyinFull, index.pinyinInitials].compactMap { $0 })

        for alias in index.aliases {
            if reserved.contains(alias) {
                continue
            }
            if alias == query {
                return candidate(type: .alias, score: 0.86, positions: positionsForPrefix(query, in: alias))
            }
            if alias.hasPrefix(query) {
                return candidate(type: .alias, score: 0.84, positions: positionsForPrefix(query, in: alias))
            }
        }

        return nil
    }

    private static func fuzzyCandidate(_ query: String, candidateText: String) -> MatchCandidate? {
        guard let positions = positionsForSubsequence(query, in: candidateText) else { return nil }
        let score = fuzzyScore(queryLength: query.count, candidateLength: candidateText.count, positions: positions)
        if score < 0.60 {
            return nil
        }
        return candidate(type: .fuzzy, score: score, positions: positions)
    }

    private static func fuzzyScore(queryLength: Int, candidateLength: Int, positions: [Int]) -> Double {
        guard let first = positions.first, let last = positions.last else { return 0 }
        let span = max(1, last - first + 1)
        let density = Double(queryLength) / Double(span)
        let consecutiveRatio = consecutiveRatioFor(positions)
        let lengthRatio = Double(queryLength) / Double(candidateLength)
        let startBonus = first == 0 ? 0.08 : 0.0
        let raw = (0.55 * density) + (0.25 * consecutiveRatio) + (0.1 * lengthRatio) + startBonus
        return min(0.84, max(0.60, raw))
    }

    private static func consecutiveRatioFor(_ positions: [Int]) -> Double {
        guard positions.count > 1 else { return 1.0 }
        var consecutive = 0
        for index in 1..<positions.count where positions[index] == positions[index - 1] + 1 {
            consecutive += 1
        }
        return Double(consecutive) / Double(positions.count - 1)
    }

    private static func positionsForPrefix(_ query: String, in candidate: String) -> [Int] {
        Array(0..<query.count)
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

    private static func candidate(type: MatchType, score: Double, positions: [Int]) -> MatchCandidate {
        MatchCandidate(
            score: score,
            types: [type],
            breakdown: [.init(type: type, score: score)],
            positions: positions
        )
    }

    private static func scoreOrder(lhs: MatchCandidate, rhs: MatchCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }
        let lhsPriority = lhs.types.first?.priority ?? Int.max
        let rhsPriority = rhs.types.first?.priority ?? Int.max
        return lhsPriority > rhsPriority
    }

    private static func pickBest(lhs: MatchCandidate?, rhs: MatchCandidate) -> MatchCandidate {
        guard let lhs = lhs else { return rhs }
        return scoreOrder(lhs: lhs, rhs: rhs) ? rhs : lhs
    }
}

private struct MatchCandidate {
    var score: Double
    var types: [MatchType]
    var breakdown: [MatchDebug.ScorePart]
    var positions: [Int]
}
