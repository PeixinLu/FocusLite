import Foundation

struct TranslateProvider: ResultProvider {
    static let providerID = "translate"
    let id = TranslateProvider.providerID
    let displayName = "Translate"

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && !isScoped {
            return []
        }
        if trimmed.isEmpty && isScoped {
            return [ResultItem(
                title: "Type text to translate",
                subtitle: "Prefix: \(TranslatePreferences.searchPrefix)",
                icon: .system("globe"),
                score: 0.1,
                action: .none,
                providerID: id,
                category: .standard
            )]
        }

        let results = await TranslationCoordinator.shared.translate(text: trimmed)
        if results.isEmpty {
            return [ResultItem(
                title: "No translation available",
                subtitle: "Check language or settings",
                icon: .system("exclamationmark.triangle"),
                score: 0.1,
                action: .none,
                providerID: id,
                category: .standard
            )]
        }

        return results.enumerated().map { index, result in
            let action: ResultAction = TranslatePreferences.autoPasteAfterSelect
                ? .pasteText(result.translatedText)
                : .copyText(result.translatedText)
            return ResultItem(
                title: result.translatedText,
                subtitle: "\(result.serviceName) · \(result.sourceLanguage) → \(result.targetLanguage)",
                icon: .system("globe"),
                score: 0.9 - Double(index) * 0.05,
                action: action,
                providerID: id,
                category: .standard
            )
        }
    }
}
