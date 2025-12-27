import Foundation
import NaturalLanguage

enum TranslateServiceID: String, CaseIterable {
    case system
    case youdaoAPI
    case baiduAPI
    case googleAPI
    case bingAPI
    case mock
}

struct TranslationResult: Hashable, Sendable {
    let serviceID: TranslateServiceID
    let serviceName: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
}

struct TranslationRequest: Hashable, Sendable {
    let text: String
    let sourceLanguage: String
    let targetLanguage: String
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
            return DetectedLanguage(code: language.rawValue, isMixed: isMixed)
        }

        if cjkCount > latinCount {
            return DetectedLanguage(code: "zh-Hans", isMixed: isMixed)
        }
        if latinCount > 0 {
            return DetectedLanguage(code: "en", isMixed: isMixed)
        }
        return nil
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
