import Foundation
import NaturalLanguage

enum TranslateServiceID: String, CaseIterable {
    case youdaoAPI
    case baiduAPI
    case googleAPI
    case bingAPI
    case deepseekAPI
    case appleNative
}

struct TranslationResult: Hashable, Sendable {
    let projectID: UUID
    let serviceID: TranslateServiceID
    let serviceName: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let usedFallback: Bool
}

extension TranslationResult {
    var compactDirectionLabel: String {
        "\(Self.compactLanguageName(for: sourceLanguage))->\(Self.compactLanguageName(for: targetLanguage))"
    }

    private static func compactLanguageName(for code: String) -> String {
        let normalized = TranslatePreferences.normalizedLanguageCode(code)
        switch normalized {
        case "zh":
            return "中"
        case "en":
            return "英"
        case "ja":
            return "日"
        case "ko":
            return "韩"
        case "fr":
            return "法"
        case "de":
            return "德"
        case "es":
            return "西"
        case "it":
            return "意"
        case "pt":
            return "葡"
        case "ru":
            return "俄"
        case "th":
            return "泰"
        case "vi":
            return "越"
        case "id":
            return "印"
        default:
            return code
        }
    }
}

struct TranslationRequest: Hashable, Sendable {
    let text: String
    let sourceLanguage: String
    let targetLanguage: String
    let projectID: UUID
    let usedFallback: Bool
}

protocol TranslationService: Sendable {
    var id: TranslateServiceID { get }
    var displayName: String { get }
    func translate(request: TranslationRequest) async -> TranslationResult?
}

struct DetectedLanguage: Hashable, Sendable {
    let code: String
    let isMixed: Bool
}

enum LanguageDetector {
    private static let ambiguousDominantConfidence = 0.60
    private static let minimumPreferredConfidence = 0.15
    private static let minimumRelativePreferredConfidence = 0.40
    private static let maximumShortTextScalarCount = 32
    private static let maximumShortTextLetterCount = 24

    static func detect(_ text: String) -> DetectedLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cjkCount = trimmed.unicodeScalars.filter { isCJK($0) }.count
        let latinCount = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) && !isCJK($0) }.count
        let total = max(1, cjkCount + latinCount)
        let cjkRatio = Double(cjkCount) / Double(total)
        let latinRatio = Double(latinCount) / Double(total)
        let isMixed = cjkCount > 0 && latinCount > 0 && abs(cjkRatio - latinRatio) < 0.5

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        let language = recognizer.dominantLanguage

        if let language {
            let hypotheses = recognizer.languageHypotheses(withMaximum: 8)
            let resolved = resolveAmbiguousShortText(
                trimmed,
                dominantLanguage: language,
                hypotheses: hypotheses,
                preferredLanguage: TranslatePreferences.secondaryLanguage
            )
            return DetectedLanguage(code: resolved, isMixed: isMixed)
        }

        // Fallback to character-based detection for short texts or when NL detection is unreliable
        if cjkCount > latinCount {
            return DetectedLanguage(code: "zh-Hans", isMixed: isMixed)
        }
        if latinCount > 0 {
            return DetectedLanguage(code: "en", isMixed: isMixed)
        }
        return nil
    }

    static func resolveAmbiguousShortText(
        _ text: String,
        dominantLanguage: NLLanguage,
        hypotheses: [NLLanguage: Double],
        preferredLanguage: String
    ) -> String {
        let dominantCode = TranslatePreferences.normalizedLanguageCode(dominantLanguage.rawValue)
        let preferredCode = TranslatePreferences.normalizedLanguageCode(preferredLanguage)
        guard dominantCode != preferredCode,
              isShortASCIILatinText(text),
              let dominantConfidence = confidence(
                  for: dominantCode,
                  in: hypotheses
              ),
              let preferredConfidence = confidence(
                  for: preferredCode,
                  in: hypotheses
              ),
              dominantConfidence < ambiguousDominantConfidence,
              preferredConfidence >= minimumPreferredConfidence,
              preferredConfidence >= dominantConfidence * minimumRelativePreferredConfidence else {
            return dominantLanguage.rawValue
        }
        return preferredLanguage
    }

    private static func confidence(
        for normalizedLanguage: String,
        in hypotheses: [NLLanguage: Double]
    ) -> Double? {
        hypotheses
            .filter {
                TranslatePreferences.normalizedLanguageCode($0.key.rawValue) == normalizedLanguage
            }
            .map(\.value)
            .max()
    }

    private static func isShortASCIILatinText(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        guard scalars.count <= maximumShortTextScalarCount,
              scalars.allSatisfy({ $0.value < 128 }) else { return false }
        let letterCount = scalars.filter {
            (65...90).contains($0.value) || (97...122).contains($0.value)
        }.count
        return letterCount > 0 && letterCount <= maximumShortTextLetterCount
    }

    private static func isCJK(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}
