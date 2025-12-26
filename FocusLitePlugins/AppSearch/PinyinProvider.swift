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
