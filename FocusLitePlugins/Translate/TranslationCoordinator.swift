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

    func translate(text: String, sourceLanguage: String, targetLanguage: String) async -> [TranslationResult] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        debounceTask?.cancel()
        return await performTranslation(
            for: trimmed,
            forcedDirection: TranslationDirection(
                source: sourceLanguage,
                target: targetLanguage,
                usedFallback: false
            )
        )
    }

    /// 自动检测源语言，翻译到指定目标语言
    func translate(text: String, targetLanguage: String) async -> [TranslationResult] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let detected = LanguageDetector.detect(trimmed) else { return [] }

        let normalizedDetected = TranslatePreferences.normalizedLanguageCode(detected.code)
        let normalizedTarget = TranslatePreferences.normalizedLanguageCode(targetLanguage)

        // 标准化语言代码：zh → zh-Hans（Apple 翻译支持简体中文）
        func appleLanguageCode(_ normalized: String) -> String {
            switch normalized {
            case "zh": return "zh-Hans"
            default:   return normalized
            }
        }

        // 源语言与目标语言相同时，取反向语言
        let source: String
        if normalizedDetected == normalizedTarget {
            source = appleLanguageCode(normalizedTarget == "en" ? "zh" : "en")
        } else {
            source = appleLanguageCode(normalizedDetected)
        }
        let target = appleLanguageCode(normalizedTarget)

        debounceTask?.cancel()
        return await performTranslation(
            for: trimmed,
            forcedDirection: TranslationDirection(
                source: source,
                target: target,
                usedFallback: false
            )
        )
    }

    private func performTranslation(
        for text: String,
        forcedDirection: TranslationDirection? = nil
    ) async -> [TranslationResult] {
        guard let detected = LanguageDetector.detect(text) else {
            return []
        }

        let policy = TranslatePreferences.mixedTextPolicy
        if forcedDirection == nil, detected.isMixed, policy == .none {
            return []
        }

        await logAppleNativeAvailability(detected: detected)

        let projects = TranslatePreferences.activeProjects()
        if projects.isEmpty {
            if let fallbackProject = AppleNativeTranslationFallback.project(
                detected: detected,
                existingProjects: projects
            ) {
                return await performAppleNativeFallback(for: text, project: fallbackProject)
            }
            return []
        }

        let services = serviceMap()
        let orderMap = Dictionary(uniqueKeysWithValues: projects.enumerated().map { ($0.element.id, $0.offset) })

        // 分离 Apple 系统翻译和 API 服务
        let appleProject = projects.first { $0.serviceID == TranslateServiceID.appleNative.rawValue }
        let apiProject = projects.first { $0.serviceID != TranslateServiceID.appleNative.rawValue }

        var allResults: [TranslationResult] = []

        // 提取目标语言，用于通知过滤（防止旧翻译结果覆盖新目标语言的结果）
        let resolvedTarget = forcedDirection?.target
            ?? projects.first?.secondaryLanguage
            ?? TranslatePreferences.defaultTargetLanguage

        /// 通知 UI 流式更新
        func notifyProgress() async {
            let sorted = sortResults(allResults, orderMap: orderMap)
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .translationResultsUpdated,
                    object: nil,
                    userInfo: [
                        TranslationCoordinator.queryKey: text,
                        TranslationCoordinator.resultsKey: sorted,
                        TranslationCoordinator.targetLanguageKey: resolvedTarget
                    ]
                )
            }
        }

        // Phase 1: Apple 系统翻译优先（离线、快速）
        if let project = appleProject,
           let service = services[.appleNative] {
            let direction = forcedDirection ?? TranslationDirection.resolve(for: project, detected: detected)
            let request = TranslationRequest(
                text: text,
                sourceLanguage: direction.source,
                targetLanguage: direction.target,
                projectID: project.id,
                usedFallback: direction.usedFallback
            )
            if let result = await service.translate(request: request) {
                allResults.append(result)
                await notifyProgress()
            }
        }

        // Phase 2: 用户首选 API 服务
        if let project = apiProject,
           let id = TranslateServiceID(rawValue: project.serviceID),
           let service = services[id] {
            let direction = forcedDirection ?? TranslationDirection.resolve(for: project, detected: detected)
            let request = TranslationRequest(
                text: text,
                sourceLanguage: direction.source,
                targetLanguage: direction.target,
                projectID: project.id,
                usedFallback: direction.usedFallback
            )
            if let result = await service.translate(request: request) {
                allResults.append(result)
                await notifyProgress()
            }
        }

        // 始终发送最终通知（即使无结果），防止 UI 卡在"翻译中"
        await notifyProgress()
        return sortResults(allResults, orderMap: orderMap)
    }

    private func serviceMap() -> [TranslateServiceID: TranslationService] {
        var map: [TranslateServiceID: TranslationService] = [:]
        for id in TranslateServiceID.allCases {
            if id == .appleNative {
                map[id] = AppleNativeTranslationService()
            } else {
                map[id] = APITranslationService(id: id, displayName: TranslatePreferences.serviceDisplayName(for: id))
            }
        }
        return map
    }

    private func logAppleNativeAvailability(detected: DetectedLanguage) async {
        let normalized = TranslatePreferences.normalizedLanguageCode(detected.code)
        switch normalized {
        case "zh":
            let installed = await AppleNativeTranslationService.isInstalled(
                sourceLanguage: "zh-Hans", targetLanguage: "en"
            )
            Log.info("Apple native translation zh→en: installed=\(installed)")
        case "en":
            let installed = await AppleNativeTranslationService.isInstalled(
                sourceLanguage: "en", targetLanguage: "zh-Hans"
            )
            Log.info("Apple native translation en→zh: installed=\(installed)")
        default:
            Log.info("Apple native translation: not applicable for detected language \(detected.code)")
        }
    }

    private func performAppleNativeFallback(
        for text: String,
        project: TranslateProject
    ) async -> [TranslationResult] {
        let request = TranslationRequest(
            text: text,
            sourceLanguage: project.primaryLanguage,
            targetLanguage: project.secondaryLanguage,
            projectID: project.id,
            usedFallback: false
        )
        guard let result = await AppleNativeTranslationService().translate(request: request) else {
            return []
        }
        return [result]
    }

    private func sortResults(
        _ results: [TranslationResult],
        orderMap: [UUID: Int]
    ) -> [TranslationResult] {
        results.sorted { lhs, rhs in
            let left = orderMap[lhs.projectID] ?? Int.max
            let right = orderMap[rhs.projectID] ?? Int.max
            if left != right {
                return left < right
            }
            return lhs.serviceName.localizedCaseInsensitiveCompare(rhs.serviceName) == .orderedAscending
        }
    }

}

extension TranslationCoordinator {
    static let queryKey = "query"
    static let resultsKey = "results"
    static let targetLanguageKey = "targetLanguage"
}

extension Notification.Name {
    static let translationResultsUpdated = Notification.Name("translationResultsUpdated")
}

private struct TranslationDirection {
    let source: String
    let target: String
    let usedFallback: Bool

    static func resolve(for project: TranslateProject, detected: DetectedLanguage) -> TranslationDirection {
        let detectedCode = TranslatePreferences.normalizedLanguageCode(detected.code)
        let primaryCode = TranslatePreferences.normalizedLanguageCode(project.primaryLanguage)
        let secondaryCode = TranslatePreferences.normalizedLanguageCode(project.secondaryLanguage)
        if detectedCode == primaryCode {
            return TranslationDirection(
                source: project.primaryLanguage,
                target: project.secondaryLanguage,
                usedFallback: false
            )
        }
        if detectedCode == secondaryCode {
            return TranslationDirection(
                source: project.secondaryLanguage,
                target: project.primaryLanguage,
                usedFallback: false
            )
        }
        return TranslationDirection(
            source: project.primaryLanguage,
            target: project.secondaryLanguage,
            usedFallback: true
        )
    }
}
