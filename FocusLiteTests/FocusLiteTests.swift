import XCTest
@testable import FocusLite

final class FocusLiteTests: XCTestCase {
    func testSearchEngineAggregatesAndSorts() async {
        let providerA = TestProvider(items: [
            ResultItem(title: "A", score: 0.2),
            ResultItem(title: "B", score: 0.5)
        ])
        let providerB = TestProvider(items: [
            ResultItem(title: "C", score: 0.9)
        ])

        let engine = SearchEngine(providers: [providerA, providerB])
        let results = await engine.search(query: "test", isScoped: false)

        XCTAssertEqual(results.map(\.title), ["C", "B", "A"])
    }

    func testSunglassesMaterialStyleUsesLiquidRenderingPath() {
        let style = AppearancePreferences.MaterialStyle.sunglasses

        XCTAssertEqual(style.rawValue, "sunglasses")
        XCTAssertEqual(style.displayName, "太阳眼镜")
        XCTAssertTrue(style.isLiquid)
        XCTAssertFalse(AppearancePreferences.MaterialStyle.classic.isLiquid)
        XCTAssertEqual(AppearancePreferences.GlassStyle.regular.baseGlassStyle, .regular)
        XCTAssertEqual(AppearancePreferences.GlassStyle.clear.baseGlassStyle, .clear)
    }

    func testTranslationBubblePersistenceControlsAutomaticDismissal() {
        XCTAssertTrue(TranslationBubblePersistence.transient.allowsAutomaticDismissal)
        XCTAssertFalse(TranslationBubblePersistence.pinned.allowsAutomaticDismissal)
    }

    func testTranslationBubblePinnedPreferencePersists() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: TranslatePreferences.translationBubblePinnedKey)
        defer {
            defaults.removeObject(forKey: TranslatePreferences.translationBubblePinnedKey)
        }

        XCTAssertFalse(TranslatePreferences.translationBubblePinned)

        TranslatePreferences.translationBubblePinned = true

        XCTAssertTrue(TranslatePreferences.translationBubblePinned)
        XCTAssertTrue(defaults.bool(forKey: TranslatePreferences.translationBubblePinnedKey))
    }

    func testTranslationResultUsesCompactDirectionLabel() {
        let result = TranslationResult(
            projectID: UUID(),
            serviceID: .deepseekAPI,
            serviceName: "DeepSeek API",
            translatedText: "Hello",
            sourceLanguage: "zh-Hans",
            targetLanguage: "en",
            usedFallback: false
        )

        XCTAssertEqual(result.compactDirectionLabel, "中->英")
    }

    func testAppleNativeFallbackProjectUsesChineseEnglishDirectionsOnlyWhenNoProjectsAreAvailable() {
        let chineseFallback = AppleNativeTranslationFallback.project(
            detected: DetectedLanguage(code: "zh-Hans", isMixed: false),
            existingProjects: []
        )
        XCTAssertEqual(chineseFallback?.serviceID, TranslateServiceID.appleNative.rawValue)
        XCTAssertEqual(chineseFallback?.primaryLanguage, "zh-Hans")
        XCTAssertEqual(chineseFallback?.secondaryLanguage, "en")

        let englishFallback = AppleNativeTranslationFallback.project(
            detected: DetectedLanguage(code: "en", isMixed: false),
            existingProjects: []
        )
        XCTAssertEqual(englishFallback?.primaryLanguage, "en")
        XCTAssertEqual(englishFallback?.secondaryLanguage, "zh-Hans")

        let configuredProject = TranslatePreferences.defaultProject(for: .deepseekAPI)
        XCTAssertNil(AppleNativeTranslationFallback.project(
            detected: DetectedLanguage(code: "zh-Hans", isMixed: false),
            existingProjects: [configuredProject]
        ))
    }

    func testTranslationResponseApplicabilityRejectsStaleTargetLanguage() {
        XCTAssertFalse(LauncherViewModel.shouldApplyTranslationResponse(
            capturedQuery: "hello",
            capturedTargetLanguage: "fr",
            currentQuery: "hello",
            currentTargetLanguage: "en"
        ))

        XCTAssertTrue(LauncherViewModel.shouldApplyTranslationResponse(
            capturedQuery: "hello",
            capturedTargetLanguage: "en",
            currentQuery: "hello",
            currentTargetLanguage: "en"
        ))
    }
}

private struct TestProvider: ResultProvider {
    let id = "test"
    let displayName = "Test"
    let items: [ResultItem]

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        items
    }
}
