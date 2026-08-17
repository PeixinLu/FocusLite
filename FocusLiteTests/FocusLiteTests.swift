import XCTest
@testable import FocusLite

final class FocusLiteTests: XCTestCase {
    func testAppIndexAllowsSystemPasswordsPackageType() {
        XCTAssertTrue(AppIndex.AppEntry.isSupportedPackageType("APPL", bundleID: "com.example.app"))
        XCTAssertTrue(AppIndex.AppEntry.isSupportedPackageType("FNDR", bundleID: "com.apple.finder"))
        XCTAssertTrue(AppIndex.AppEntry.isSupportedPackageType("XPC!", bundleID: "com.apple.Passwords"))
        XCTAssertFalse(AppIndex.AppEntry.isSupportedPackageType("XPC!", bundleID: "com.example.service"))
    }

    func testAppIndexEntryIdentityUsesPath() {
        let nameIndex = AppNameIndex(name: "Example", aliasEntry: nil, pinyinProvider: nil)
        let first = AppIndex.AppEntry(
            name: "Example",
            path: "/Applications/Example.app",
            bundleID: "com.example.app",
            nameIndex: nameIndex
        )
        let second = AppIndex.AppEntry(
            name: "Example Beta",
            path: "/Applications/Example Beta.app",
            bundleID: "com.example.app",
            nameIndex: nameIndex
        )

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.id, first.path)
        XCTAssertEqual(second.id, second.path)
    }

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

    func testTranslationBubblePlacementPrefersBelowSelection() {
        let frame = TranslationBubblePlacement.bestFrame(
            size: NSSize(width: 300, height: 100),
            anchorRect: NSRect(x: 490, y: 500, width: 20, height: 20),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_000, height: 800)
        )

        XCTAssertEqual(frame, NSRect(x: 350, y: 392, width: 300, height: 100))
    }

    func testTranslationBubblePlacementUsesAboveWhenBelowDoesNotFit() {
        let frame = TranslationBubblePlacement.bestFrame(
            size: NSSize(width: 300, height: 100),
            anchorRect: NSRect(x: 490, y: 50, width: 20, height: 20),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_000, height: 800)
        )

        XCTAssertEqual(frame, NSRect(x: 350, y: 78, width: 300, height: 100))
    }

    func testTranslationBubblePlacementClampsOversizedCandidatesIntoVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 400, height: 300)
        let frame = TranslationBubblePlacement.bestFrame(
            size: NSSize(width: 300, height: 200),
            anchorRect: NSRect(x: 190, y: 140, width: 20, height: 20),
            visibleFrame: visibleFrame
        )

        XCTAssertTrue(visibleFrame.insetBy(dx: 8, dy: 8).contains(frame))
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

    func testPreferredPrimaryLanguageUsesFirstSupportedMacOSLanguage() {
        XCTAssertEqual(
            TranslatePreferences.preferredPrimaryLanguage(from: ["xx-YY", "ja-JP", "en-US"]),
            "ja"
        )
        XCTAssertEqual(
            TranslatePreferences.preferredPrimaryLanguage(from: ["zh-Hans-CN", "en-US"]),
            "zh-Hans"
        )
        XCTAssertEqual(
            TranslatePreferences.preferredPrimaryLanguage(from: ["zh-Hant-TW"]),
            "zh-Hans"
        )
        XCTAssertEqual(
            TranslatePreferences.preferredPrimaryLanguage(from: ["zh-Hant-TW", "en-US"]),
            "zh-Hans"
        )
    }

    func testTranslationDirectionUsesPrimaryLanguageAsTheReadingTarget() {
        let project = TranslateProject(
            id: UUID(),
            serviceID: TranslateServiceID.deepseekAPI.rawValue,
            primaryLanguage: "zh-Hans",
            secondaryLanguage: "en"
        )

        let primaryText = TranslationDirection.resolve(
            for: project,
            detected: DetectedLanguage(code: "zh-Hans", isMixed: false)
        )
        XCTAssertEqual(primaryText.source, "zh-Hans")
        XCTAssertEqual(primaryText.target, "en")

        let secondaryText = TranslationDirection.resolve(
            for: project,
            detected: DetectedLanguage(code: "en", isMixed: false)
        )
        XCTAssertEqual(secondaryText.source, "en")
        XCTAssertEqual(secondaryText.target, "zh-Hans")

        let thirdLanguageText = TranslationDirection.resolve(
            for: project,
            detected: DetectedLanguage(code: "ja", isMixed: false)
        )
        XCTAssertEqual(thirdLanguageText.source, "ja")
        XCTAssertEqual(thirdLanguageText.target, "zh-Hans")
        XCTAssertFalse(thirdLanguageText.usedFallback)
    }

    func testLanguageDetectorPrefersCommonForeignLanguageForAmbiguousShortLatinText() {
        let resolved = LanguageDetector.resolveAmbiguousShortText(
            "transition",
            dominantLanguage: .french,
            hypotheses: [
                .french: 0.4787,
                .english: 0.2286,
                .danish: 0.1095
            ],
            preferredLanguage: "en"
        )

        XCTAssertEqual(resolved, "en")
    }

    func testLanguageDetectorKeepsConfidentOrNonShortLanguageRecognition() {
        let confidentFrench = LanguageDetector.resolveAmbiguousShortText(
            "bonjour",
            dominantLanguage: .french,
            hypotheses: [.french: 0.92, .english: 0.03],
            preferredLanguage: "en"
        )
        XCTAssertEqual(confidentFrench, "fr")

        let longFrench = LanguageDetector.resolveAmbiguousShortText(
            "Cette phrase contient suffisamment de contexte pour identifier sa langue.",
            dominantLanguage: .french,
            hypotheses: [.french: 0.52, .english: 0.30],
            preferredLanguage: "en"
        )
        XCTAssertEqual(longFrench, "fr")

        let weakEnglishCandidate = LanguageDetector.resolveAmbiguousShortText(
            "transition",
            dominantLanguage: .french,
            hypotheses: [.french: 0.55, .english: 0.10],
            preferredLanguage: "en"
        )
        XCTAssertEqual(weakEnglishCandidate, "fr")
    }

    func testAppleNativeFallbackProjectUsesPrimaryLanguageModelWhenNoProjectsAreAvailable() {
        let chineseFallback = AppleNativeTranslationFallback.project(
            detected: DetectedLanguage(code: "zh-Hans", isMixed: false),
            existingProjects: []
        )
        XCTAssertEqual(chineseFallback?.serviceID, TranslateServiceID.appleNative.rawValue)
        XCTAssertEqual(chineseFallback?.primaryLanguage, "zh-Hans")
        XCTAssertEqual(
            chineseFallback?.secondaryLanguage,
            TranslatePreferences.automaticTargetLanguage(for: "zh-Hans")
        )

        let englishFallback = AppleNativeTranslationFallback.project(
            detected: DetectedLanguage(code: "en", isMixed: false),
            existingProjects: []
        )
        XCTAssertEqual(englishFallback?.primaryLanguage, "en")
        XCTAssertEqual(
            englishFallback?.secondaryLanguage,
            TranslatePreferences.automaticTargetLanguage(for: "en")
        )

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

    func testClipboardTitleStopsAtConfiguredLengthAndCollapsesWhitespace() {
        let text = "  hello\n\tworld  " + String(repeating: "x", count: 1_000_000)

        let title = ClipboardTextProcessor.makeTitle(from: text)

        XCTAssertTrue(title.hasPrefix("hello world "))
        XCTAssertTrue(title.hasSuffix("…"))
        XCTAssertLessThanOrEqual(title.count, ClipboardTextPolicy.titleCharacterLimit + 1)
    }

    func testClipboardMetadataBoundsPreviewAndSearchIndex() {
        let headMarker = "HEAD-MARKER"
        let tailMarker = "TAIL-MARKER"
        let text = headMarker
            + String(repeating: "a", count: ClipboardTextPolicy.searchHeadByteLimit + 8_192)
            + tailMarker

        let item = ClipboardTextProcessor.makeItem(text: text, storage: .inline(text))

        XCTAssertTrue(item.isPreviewTruncated)
        XCTAssertLessThanOrEqual(item.previewText.utf8.count, ClipboardTextPolicy.previewByteLimit)
        XCTAssertTrue(item.searchText.contains("head marker"))
        XCTAssertTrue(item.searchText.contains("tail marker"))
        XCTAssertLessThanOrEqual(
            item.searchText.utf8.count,
            ClipboardTextPolicy.searchHeadByteLimit + ClipboardTextPolicy.searchTailByteLimit + 1
        )
    }

    func testLegacyClipboardJSONDecodesIntoTextMetadata() throws {
        let id = UUID()
        let text = "legacy clipboard text"
        let json: [[String: Any]] = [[
            "id": id.uuidString,
            "content": ["kind": "text", "text": text],
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "contentHash": "legacy-hash"
        ]]
        let data = try JSONSerialization.data(withJSONObject: json)

        let entries = try JSONDecoder().decode([ClipboardEntry].self, from: data)

        XCTAssertEqual(entries.first?.id, id)
        guard case .text(let item) = entries.first?.content,
              case .inline(let decodedText) = item.storage else {
            XCTFail("Expected migrated inline text metadata")
            return
        }
        XCTAssertEqual(decodedText, text)
        XCTAssertEqual(item.previewText, text)
        XCTAssertEqual(item.title, text)
    }

    func testClipboardStoreExternalizesLargeTextAndLoadsItOnDemand() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ClipboardStore(baseDirectory: directory)
        let text = "large\n" + String(repeating: "内容", count: ClipboardTextPolicy.inlineStorageByteLimit)

        await store.addText(text, sourceBundleID: "test.bundle", sourceAppName: "Tests")
        let entries = await store.snapshot()

        guard let entry = entries.first,
              case .text(let item) = entry.content,
              case .file(let filename) = item.storage else {
            XCTFail("Expected externally stored text")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("clipboard_text").appendingPathComponent(filename).path
        ))
        guard case .text(let loadedText) = await store.resolvedContent(for: entry.id) else {
            XCTFail("Expected resolved clipboard text")
            return
        }
        XCTAssertEqual(loadedText, text)
    }

    func testClipboardStoreClearHistoryRemovesManagedTextFiles() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ClipboardStore(baseDirectory: directory)
        let text = String(repeating: "clear me", count: ClipboardTextPolicy.inlineStorageByteLimit)
        await store.addText(text, sourceBundleID: nil, sourceAppName: nil)

        let removedCount = await store.clearHistory()
        let entries = await store.snapshot()
        let textDirectory = directory.appendingPathComponent("clipboard_text", isDirectory: true)
        let remainingFiles = try FileManager.default.contentsOfDirectory(atPath: textDirectory.path)

        XCTAssertEqual(removedCount, 1)
        XCTAssertTrue(entries.isEmpty)
        XCTAssertTrue(remainingFiles.isEmpty)
    }

    func testClipboardStoreMigratesLegacyLargeTextAndRemovesOrphanFiles() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let textDirectory = directory.appendingPathComponent("clipboard_text", isDirectory: true)
        try FileManager.default.createDirectory(at: textDirectory, withIntermediateDirectories: true)
        let orphanURL = textDirectory.appendingPathComponent("orphan.txt")
        try "orphan".write(to: orphanURL, atomically: true, encoding: .utf8)

        let id = UUID()
        let text = String(repeating: "z", count: ClipboardTextPolicy.inlineStorageByteLimit + 1)
        let json: [[String: Any]] = [[
            "id": id.uuidString,
            "content": ["kind": "text", "text": text],
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "contentHash": "legacy-large-hash"
        ]]
        try JSONSerialization.data(withJSONObject: json)
            .write(to: directory.appendingPathComponent("clipboard_history.json"), options: [.atomic])

        let store = ClipboardStore(baseDirectory: directory)
        let entries = await store.snapshot()

        guard case .text(let item) = entries.first?.content,
              case .file(let filename) = item.storage else {
            XCTFail("Expected legacy text to migrate to a file")
            return
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanURL.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: textDirectory.appendingPathComponent(filename).path
        ))
        let migratedText = await store.text(for: id)
        XCTAssertEqual(migratedText, text)
    }

    func testClipboardStoreRewritesLegacySmallTextMetadataOnLoad() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let historyURL = directory.appendingPathComponent("clipboard_history.json")
        let text = "small legacy text"
        let json: [[String: Any]] = [[
            "id": UUID().uuidString,
            "content": ["kind": "text", "text": text],
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "contentHash": "legacy-small-hash"
        ]]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json).write(to: historyURL, options: [.atomic])

        let store = ClipboardStore(baseDirectory: directory)
        _ = await store.snapshot()

        let rewritten = try JSONSerialization.jsonObject(with: Data(contentsOf: historyURL))
        let entries = try XCTUnwrap(rewritten as? [[String: Any]])
        let content = try XCTUnwrap(entries.first?["content"] as? [String: Any])
        XCTAssertNil(content["text"])
        XCTAssertNotNil(content["textItem"])
    }

    func testClipboardMetadataGenerationPerformance() {
        let text = String(repeating: "long clipboard line with searchable content\n", count: 25_000)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = ClipboardTextProcessor.makeItem(text: text, storage: .file("fixture.txt"))
        }
    }

    func testClipboardProviderKeepsFullBodyOutOfResultItem() async {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ClipboardStore(baseDirectory: directory)
        let text = String(repeating: "body ", count: 10_000)
        await store.addText(text, sourceBundleID: "com.apple.TextEdit", sourceAppName: "TextEdit")

        let results = await ClipboardProvider(store: store).results(for: "", isScoped: true)

        guard let result = results.first,
              case .clipboardEntry(let id, _) = result.action,
              case .clipboardText(let preview) = result.preview else {
            XCTFail("Expected an ID-based clipboard result")
            return
        }
        XCTAssertEqual(id, preview.entryID)
        XCTAssertLessThan(preview.text.utf8.count, text.utf8.count)
        XCTAssertEqual(result.clipboardMetadata?.sourceAppName, "TextEdit")
        XCTAssertEqual(result.clipboardMetadata?.sourceBundleID, "com.apple.TextEdit")
        XCTAssertEqual(result.clipboardMetadata?.typeText, "文本")
        XCTAssertNotEqual(result.clipboardMetadata?.sizeText, "大小未知")
    }

    func testClipboardProviderUsesFourFileCategoryIcons() async {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ClipboardStore(baseDirectory: directory)
        let fixtures: [(String, ItemIcon)] = [
            ("notes.txt", .system("doc.text")),
            ("clip.mp4", .system("film")),
            ("picture.png", .system("photo")),
            ("installer.pkg", .system("doc"))
        ]

        for (name, _) in fixtures {
            await store.add(
                content: .files([FilePreviewItem(path: "/tmp/\(name)", name: name, byteCount: 1)]),
                sourceBundleID: "com.apple.finder",
                sourceAppName: "Finder"
            )
        }

        let results = await ClipboardProvider(store: store).results(for: "", isScoped: true)
        let iconsByTitle = Dictionary(uniqueKeysWithValues: results.compactMap { result -> (String, ItemIcon)? in
            guard let icon = result.icon else { return nil }
            return (result.title, icon)
        })
        for (name, expectedIcon) in fixtures {
            XCTAssertEqual(iconsByTitle[name], expectedIcon)
        }
    }

    func testClipboardClickActivationRules() {
        XCTAssertFalse(LauncherViewModel.shouldActivateClipboardResult(wasSelected: false))
        XCTAssertTrue(LauncherViewModel.shouldActivateClipboardResult(wasSelected: true))

        let firstClickActivates = LauncherViewModel.shouldActivateClipboardResult(wasSelected: false)
        let secondClickActivates = LauncherViewModel.shouldActivateClipboardResult(wasSelected: true)
        XCTAssertFalse(firstClickActivates)
        XCTAssertTrue(secondClickActivates)
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusLiteTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
