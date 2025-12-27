import Foundation

struct SnippetMatcher {
    static func keywordQuery(from query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(";") else { return nil }
        let remainder = trimmed.dropFirst()
        guard let token = remainder.split(whereSeparator: { $0.isWhitespace }).first else {
            return nil
        }
        return String(token)
    }

    static func keywordScore(query: String, keyword: String) -> Double? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return nil }
        let normalizedKeyword = normalize(keyword)
        guard !normalizedKeyword.isEmpty else { return nil }

        if normalizedKeyword == normalizedQuery {
            return 1.0
        }
        if normalizedKeyword.hasPrefix(normalizedQuery) {
            return 0.92
        }
        if normalizedKeyword.contains(normalizedQuery) {
            return 0.82
        }
        return nil
    }

    static func searchScore(query: String, snippet: Snippet) -> Double? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return nil }
        let tokens = tokenize(normalizedQuery)

        let title = normalize(snippet.title)
        let keyword = normalize(snippet.keyword)
        let tags = normalize(snippet.tags.joined(separator: " "))
        let content = normalize(snippet.content)

        var best = 0.0

        if let score = scoreField(query: normalizedQuery, candidate: title) {
            best = max(best, score)
        }

        if let score = scoreField(query: normalizedQuery, candidate: keyword) {
            best = max(best, min(1.0, score + 0.05))
        }

        if let score = scoreField(query: normalizedQuery, candidate: tags) {
            best = max(best, score * 0.9)
        }

        if let score = scoreField(query: normalizedQuery, candidate: content) {
            best = max(best, score * 0.6)
        }

        guard best > 0 else { return nil }

        if tokens.count > 1 {
            let haystack = [title, keyword, tags, content].joined(separator: " ")
            if tokens.allSatisfy({ haystack.contains($0) }) {
                best = min(1.0, best + 0.05)
            }
        }

        return best
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
