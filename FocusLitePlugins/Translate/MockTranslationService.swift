import Foundation

struct MockTranslationService: TranslationService {
    let id: TranslateServiceID = .mock
    let displayName = "Mock"

    func translate(request: TranslationRequest) async -> TranslationResult? {
        let prefix = request.targetLanguage.lowercased().hasPrefix("zh") ? "ZH" : "EN"
        let translated = "[Mock \(prefix)] " + request.text
        return TranslationResult(
            serviceID: .mock,
            serviceName: "Mock",
            translatedText: translated,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage
        )
    }
}
