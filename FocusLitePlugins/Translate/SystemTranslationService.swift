import Foundation

struct SystemTranslationService: TranslationService {
    let id: TranslateServiceID = .system
    let displayName = "System"

    func translate(request: TranslationRequest) async -> TranslationResult? {
#if canImport(Translation)
        if #available(macOS 26.0, *) {
            return await translateWithSystem(request)
        }
#endif
        return nil
    }
}

#if canImport(Translation)
import Translation

@available(macOS 26.0, *)
private func translateWithSystem(_ request: TranslationRequest) async -> TranslationResult? {
    let source = localeLanguage(from: request.sourceLanguage)
    let target = localeLanguage(from: request.targetLanguage)
    let session = TranslationSession(installedSource: source, target: target)
    do {
        let response = try await session.translate(request.text)
        return TranslationResult(
            serviceID: .system,
            serviceName: "System",
            translatedText: response.targetText,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage
        )
    } catch {
        return nil
    }
}

@available(macOS 26.0, *)
private func localeLanguage(from code: String) -> Locale.Language {
    let normalized = code.lowercased()
    if normalized.hasPrefix("zh") {
        return Locale.Language(languageCode: "zh")
    }
    if normalized.hasPrefix("en") {
        return Locale.Language(languageCode: "en")
    }
    return Locale.Language(languageCode: "en")
}
#endif
