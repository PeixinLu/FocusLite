import Foundation

enum SearchQueryClassifier {
    static func isMathQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("=") { return true }

        let mathSymbols: Set<Character> = ["+", "-", "*", "/", "%", "(", ")"]
        return trimmed.contains { mathSymbols.contains($0) }
    }
}
