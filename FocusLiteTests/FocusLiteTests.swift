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

    func testFadeGlassStyleUsesClearGlassWithTopToBottomOverlayStops() {
        let style = AppearancePreferences.GlassStyle.fade

        XCTAssertEqual(style.rawValue, "fade")
        XCTAssertEqual(style.displayName, "渐隐")
        XCTAssertEqual(style.baseGlassStyle, .clear)
        XCTAssertEqual(style.fadeOverlayStops, [
            AppearancePreferences.FadeOverlayStop(location: 0.0, opacity: 0.96),
            AppearancePreferences.FadeOverlayStop(location: 0.25, opacity: 0.94),
            AppearancePreferences.FadeOverlayStop(location: 0.5, opacity: 0.9),
            AppearancePreferences.FadeOverlayStop(location: 0.68, opacity: 0.82),
            AppearancePreferences.FadeOverlayStop(location: 0.8, opacity: 0.62),
            AppearancePreferences.FadeOverlayStop(location: 0.9, opacity: 0.34),
            AppearancePreferences.FadeOverlayStop(location: 0.96, opacity: 0.16),
            AppearancePreferences.FadeOverlayStop(location: 1.0, opacity: 0.06)
        ])
        XCTAssertTrue(style.usesLightForeground)
        XCTAssertFalse(AppearancePreferences.GlassStyle.regular.usesLightForeground)
        XCTAssertFalse(AppearancePreferences.GlassStyle.clear.usesLightForeground)
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
