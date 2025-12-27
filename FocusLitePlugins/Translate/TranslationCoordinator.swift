import Foundation

actor TranslationCoordinator {
    static let shared = TranslationCoordinator()

    private let debounceNanos: UInt64 = 320_000_000
    private var debounceTask: Task<[TranslationResult], Never>?
    private var cache: [String: [TranslationResult]] = [:]
    private var lastQuery: String = ""
    private var lastQueryAt: Date = .distantPast

    func translate(text: String) async -> [TranslationResult] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed == lastQuery, Date().timeIntervalSince(lastQueryAt) < 1.0, let cached = cache[trimmed] {
            return cached
        }

        debounceTask?.cancel()
        let task = Task { [trimmed] in
            try? await Task.sleep(nanoseconds: debounceNanos)
            return await performTranslation(for: trimmed)
        }
        debounceTask = task
        let results = await task.value
        cache[trimmed] = results
        lastQuery = trimmed
        lastQueryAt = Date()
        return results
    }

    private func performTranslation(for text: String) async -> [TranslationResult] {
        guard let detected = LanguageDetector.detect(text) else {
            return []
        }

        let policy = TranslatePreferences.mixedTextPolicy
        if detected.isMixed, policy == .none {
            return []
        }

        let direction = TranslationDirection.from(detected: detected, policy: policy)
        guard let direction else { return [] }

        let request = TranslationRequest(
            text: text,
            sourceLanguage: direction.source,
            targetLanguage: direction.target
        )

        let services = activeServices()
        if services.isEmpty {
            return []
        }

        return await withTaskGroup(of: TranslationResult?.self) { group in
            for service in services {
                group.addTask {
                    await service.translate(request: request)
                }
            }

            var results: [TranslationResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
        }
    }

    private func activeServices() -> [TranslationService] {
        let order = TranslatePreferences.enabledServices
        return order.compactMap { rawValue in
            guard let id = TranslateServiceID(rawValue: rawValue) else { return nil }
            switch id {
            case .system:
                return SystemTranslationService()
            case .youdaoAPI:
                return APITranslationService(id: id, displayName: "有道 API")
            case .baiduAPI:
                return APITranslationService(id: id, displayName: "百度 API")
            case .googleAPI:
                return APITranslationService(id: id, displayName: "Google API")
            case .bingAPI:
                return APITranslationService(id: id, displayName: "微软翻译 API")
            }
        }
    }
}

private struct TranslationDirection {
    let source: String
    let target: String

    static func from(detected: DetectedLanguage, policy: TranslatePreferences.MixedTextPolicy) -> TranslationDirection? {
        let code = detected.code.lowercased()
        if code.hasPrefix("zh") {
            return TranslationDirection(source: "zh-Hans", target: "en")
        }
        if code.hasPrefix("en") {
            return TranslationDirection(source: "en", target: "zh-Hans")
        }
        if detected.isMixed && policy == .auto {
            return fallbackForMixed(code: code)
        }
        return nil
    }

    private static func fallbackForMixed(code: String) -> TranslationDirection? {
        if code.hasPrefix("zh") {
            return TranslationDirection(source: "zh-Hans", target: "en")
        }
        if code.hasPrefix("en") {
            return TranslationDirection(source: "en", target: "zh-Hans")
        }
        return nil
    }
}
