import Foundation

enum SearchStateReducer {
    struct UpdateResult {
        let state: SearchState
        let textFieldValue: String
    }

    static func handleInputChange(state: SearchState, newText: String) -> UpdateResult {
        var nextState = state

        if case .global = state.scope, let matched = matchPrefix(in: newText) {
            nextState.scope = .prefixed(providerID: matched.providerID)
            nextState.activePrefix = ActivePrefix(
                id: matched.id,
                providerID: matched.providerID,
                title: matched.title,
                subtitle: matched.subtitle
            )
            let remainder = remainderAfterPrefix(matched.title, in: newText)
            nextState.query = remainder
            return UpdateResult(state: nextState, textFieldValue: remainder)
        }

        nextState.query = newText
        return UpdateResult(state: nextState, textFieldValue: newText)
    }

    static func selectPrefix(state: SearchState, prefix: PrefixEntry) -> UpdateResult {
        var nextState = state
        nextState.scope = .prefixed(providerID: prefix.providerID)
        nextState.activePrefix = ActivePrefix(
            id: prefix.id,
            providerID: prefix.providerID,
            title: prefix.title,
            subtitle: prefix.subtitle
        )
        nextState.query = ""
        return UpdateResult(state: nextState, textFieldValue: "")
    }

    static func selectPrefix(state: SearchState, prefix: PrefixEntry, carryQuery: String) -> UpdateResult {
        var nextState = state
        nextState.scope = .prefixed(providerID: prefix.providerID)
        nextState.activePrefix = ActivePrefix(
            id: prefix.id,
            providerID: prefix.providerID,
            title: prefix.title,
            subtitle: prefix.subtitle
        )
        let trimmed = carryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        nextState.query = trimmed
        return UpdateResult(state: nextState, textFieldValue: trimmed)
    }

    static func exitScope(state: SearchState) -> UpdateResult {
        var nextState = state
        nextState.scope = .global
        nextState.activePrefix = nil
        nextState.query = ""
        return UpdateResult(state: nextState, textFieldValue: "")
    }

    static func handleBackspace(state: SearchState) -> UpdateResult {
        if case .prefixed = state.scope, state.query.isEmpty {
            return exitScope(state: state)
        }
        return UpdateResult(state: state, textFieldValue: state.query)
    }

    static func handleEscape(state: SearchState, currentText: String) -> UpdateResult {
        if case .prefixed = state.scope {
            // Remove tag, keep the text in the field
            var next = SearchState(query: currentText, scope: .global, activePrefix: nil)
            return UpdateResult(state: next, textFieldValue: currentText)
        }
        return UpdateResult(state: state, textFieldValue: currentText)
    }

    private static func matchPrefix(in text: String) -> PrefixEntry? {
        let entries = PrefixRegistry.entries()
        let normalized = text.lowercased()
        for entry in entries {
            if normalized.hasPrefix(entry.id), hasTrailingSpace(after: entry.id, in: normalized) {
                return entry
            }
        }
        return nil
    }

    private static func hasTrailingSpace(after prefix: String, in text: String) -> Bool {
        guard text.count >= prefix.count + 1 else { return false }
        let index = text.index(text.startIndex, offsetBy: prefix.count)
        return text[index].isWhitespace
    }

    private static func remainderAfterPrefix(_ prefix: String, in text: String) -> String {
        guard text.count >= prefix.count else { return "" }
        let index = text.index(text.startIndex, offsetBy: prefix.count)
        let remainder = text[index...]
        return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
