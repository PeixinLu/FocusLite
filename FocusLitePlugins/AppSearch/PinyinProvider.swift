import Foundation

protocol PinyinProvider: Sendable {
    func pinyin(for name: String) -> (full: String, initials: String)?
}

struct SystemPinyinProvider: PinyinProvider {
    func pinyin(for name: String) -> (full: String, initials: String)? {
        guard containsHan(name) else { return nil }
        let mutable = NSMutableString(string: name) as CFMutableString
        guard CFStringTransform(mutable, nil, kCFStringTransformToLatin, false) else {
            return nil
        }
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)

        let latin = (mutable as String).lowercased()
        let parts = latin.split { !$0.isLetter && !$0.isNumber }
        let full = MatchingNormalizer.normalize(latin)
        var initials = ""
        initials.reserveCapacity(parts.count)

        for part in parts {
            if let first = part.first {
                initials.append(first)
            }
        }

        let initialsFolded = MatchingNormalizer.normalize(initials)
        if full.isEmpty || initialsFolded.isEmpty {
            return nil
        }
        return (full, initialsFolded)
    }

    private func containsHan(_ string: String) -> Bool {
        for scalar in string.unicodeScalars {
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }
}

final class Pinyin4SwiftProvider: PinyinProvider, @unchecked Sendable {
    private var cache: [String: (full: String, initials: String)] = [:]
    private let lock = NSLock()

    func pinyin(for name: String) -> (full: String, initials: String)? {
        guard containsHan(name) else { return nil }

        lock.lock()
        if let cached = cache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let fullRaw = pinyinFullRaw(name) else { return nil }
        let full = MatchingNormalizer.normalize(fullRaw)
        let initials = MatchingNormalizer.normalize(pinyinInitialsRaw(from: fullRaw))
        guard !full.isEmpty, !initials.isEmpty else { return nil }

        lock.lock()
        cache[name] = (full: full, initials: initials)
        lock.unlock()
        return (full, initials)
    }

    private func pinyinFullRaw(_ name: String) -> String? {
        let format = OutputFormat(vCharType: .v, caseType: .lower, toneType: .noTone)
        let raw = PinyinHelper.getPinyinStringWithString(name, outputFormat: format, seperater: " ")
        let trimmed = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func pinyinInitialsRaw(from full: String) -> String {
        let parts = full.split { !$0.isLetter && !$0.isNumber }
        var initials = ""
        initials.reserveCapacity(parts.count)
        for part in parts {
            if let first = part.first {
                initials.append(first)
            }
        }
        return initials
    }

    private func containsHan(_ string: String) -> Bool {
        for scalar in string.unicodeScalars {
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }
}

enum PinyinProviderFactory {
    static func make() -> PinyinProvider {
        return Pinyin4SwiftProvider()
    }
}
