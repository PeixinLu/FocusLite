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

        let projects = TranslatePreferences.activeProjects()
        if projects.isEmpty {
            return []
        }

        let orderMap = Dictionary(uniqueKeysWithValues: projects.enumerated().map { ($0.element.id, $0.offset) })
        let services = serviceMap()

        return await withTaskGroup(of: TranslationResult?.self) { group in
            for project in projects {
                guard let id = TranslateServiceID(rawValue: project.serviceID),
                      let service = services[id] else { continue }
                let direction = TranslationDirection.resolve(for: project, detected: detected)
                let request = TranslationRequest(
                    text: text,
                    sourceLanguage: direction.source,
                    targetLanguage: direction.target,
                    projectID: project.id,
                    usedFallback: direction.usedFallback
                )
                group.addTask {
                    await service.translate(request: request)
                }
            }

            var results: [TranslationResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                    let sorted = sortResults(results, orderMap: orderMap)
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .translationResultsUpdated,
                            object: nil,
                            userInfo: [
                                TranslationCoordinator.queryKey: text,
                                TranslationCoordinator.resultsKey: sorted
                            ]
                        )
                    }
                }
            }
            return sortResults(results, orderMap: orderMap)
        }
    }

    private func serviceMap() -> [TranslateServiceID: TranslationService] {
        Dictionary(uniqueKeysWithValues: TranslateServiceID.allCases.map { id in
            (id, APITranslationService(id: id, displayName: serviceDisplayName(for: id)))
        })
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

    private func serviceDisplayName(for id: TranslateServiceID) -> String {
        switch id {
        case .youdaoAPI:
            return "有道 API"
        case .baiduAPI:
            return "百度 API"
        case .googleAPI:
            return "Google API"
        case .bingAPI:
            return "微软翻译 API"
        case .deepseekAPI:
            return "DeepSeek API"
        }
    }
}

extension TranslationCoordinator {
    static let queryKey = "query"
    static let resultsKey = "results"
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
