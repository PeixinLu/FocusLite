import Foundation

#if canImport(Translation)
import Translation
#endif

enum AppleNativeTranslationFallback {
    static let serviceName = "Apple 系统翻译"

    static func project(
        detected: DetectedLanguage,
        existingProjects: [TranslateProject]
    ) -> TranslateProject? {
        guard existingProjects.isEmpty else { return nil }

        switch TranslatePreferences.normalizedLanguageCode(detected.code) {
        case "zh":
            return fallbackProject(source: "zh-Hans", target: "en")
        case "en":
            return fallbackProject(source: "en", target: "zh-Hans")
        default:
            return nil
        }
    }

    private static func fallbackProject(source: String, target: String) -> TranslateProject {
        TranslateProject(
            id: UUID(uuidString: "2D8B2D75-2B9C-4D4D-9B6A-7BCA73E8A001") ?? UUID(),
            serviceID: TranslateServiceID.appleNative.rawValue,
            primaryLanguage: source,
            secondaryLanguage: target
        )
    }
}

struct AppleNativeTranslationService: TranslationService {
    let id = TranslateServiceID.appleNative
    let displayName = AppleNativeTranslationFallback.serviceName

    func translate(request: TranslationRequest) async -> TranslationResult? {
        guard await Self.isInstalled(sourceLanguage: request.sourceLanguage, targetLanguage: request.targetLanguage) else {
            return nil
        }
        guard let translated = await Self.translateText(
            request.text,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage
        ) else {
            return nil
        }

        return TranslationResult(
            projectID: request.projectID,
            serviceID: id,
            serviceName: displayName,
            translatedText: translated,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage,
            usedFallback: request.usedFallback
        )
    }

    static func isInstalled(sourceLanguage: String, targetLanguage: String) async -> Bool {
        #if canImport(Translation)
        if #available(macOS 26.0, *) {
            return await AppleNativeTranslationRuntime.isInstalled(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }
        #endif
        return false
    }

    static func isSupported(sourceLanguage: String, targetLanguage: String) async -> Bool {
        #if canImport(Translation)
        if #available(macOS 26.0, *) {
            return await AppleNativeTranslationRuntime.isSupported(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }
        #endif
        return false
    }

    private static func translateText(
        _ text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async -> String? {
        #if canImport(Translation)
        if #available(macOS 26.0, *) {
            return await AppleNativeTranslationRuntime.translate(
                text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }
        #endif
        return nil
    }
}

#if canImport(Translation)
@available(macOS 26.0, *)
private enum AppleNativeTranslationRuntime {
    static func isInstalled(sourceLanguage: String, targetLanguage: String) async -> Bool {
        await status(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) == .installed
    }

    static func isSupported(sourceLanguage: String, targetLanguage: String) async -> Bool {
        let availability = await status(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        return availability == .installed || availability == .supported
    }

    static func translate(
        _ text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async -> String? {
        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)
        let session = TranslationSession(installedSource: source, target: target)

        do {
            let response = try await session.translate(text)
            let translated = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            return translated.isEmpty ? nil : translated
        } catch {
            Log.debug("Apple native translation failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func status(
        sourceLanguage: String,
        targetLanguage: String
    ) async -> LanguageAvailability.Status {
        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)
        let status = await LanguageAvailability().status(from: source, to: target)
        Log.info("Apple translation status \(sourceLanguage)->\(targetLanguage): \(status)")
        return status
    }
}
#endif
