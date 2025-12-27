import Foundation

struct APITranslationService: TranslationService {
    let id: TranslateServiceID
    let displayName: String

    func translate(request: TranslationRequest) async -> TranslationResult? {
        guard TranslatePreferences.isConfigured(serviceID: id) else { return nil }
        guard let translated = await TranslationProxy.translateText(request: request, serviceID: id) else {
            return nil
        }
        return TranslationResult(
            serviceID: id,
            serviceName: displayName,
            translatedText: translated,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage
        )
    }
}
