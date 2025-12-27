import Foundation

enum ClipboardPreferences {
    private static let pausedKey = "clipboard.paused"
    private static let maxEntriesKey = "clipboard.maxEntries"
    private static let ignoredAppsKey = "clipboard.ignoredApps"
    private static let hotKeyKey = "clipboard.hotKey"
    private static let prefixKey = "clipboard.searchPrefix"
    private static let retentionDaysKey = "clipboard.retentionDays"
    private static let retentionHoursKey = "clipboard.retentionHours"

    static var isPaused: Bool {
        get {
            UserDefaults.standard.bool(forKey: pausedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: pausedKey)
        }
    }

    static var maxEntries: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: maxEntriesKey)
            return stored > 0 ? stored : 200
        }
        set {
            let clamped = max(10, min(newValue, 1000))
            UserDefaults.standard.set(clamped, forKey: maxEntriesKey)
        }
    }

    static var ignoredBundleIDs: [String] {
        get {
            guard let values = UserDefaults.standard.array(forKey: ignoredAppsKey) as? [String] else {
                let fallback = [Bundle.main.bundleIdentifier].compactMap { $0 }
                UserDefaults.standard.set(fallback, forKey: ignoredAppsKey)
                return fallback
            }
            return values
        }
        set {
            let cleaned = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            UserDefaults.standard.set(cleaned, forKey: ignoredAppsKey)
        }
    }

    static var hotKeyText: String {
        get {
            UserDefaults.standard.string(forKey: hotKeyKey) ?? "option+v"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: hotKeyKey)
        }
    }

    static var searchPrefix: String {
        get {
            UserDefaults.standard.string(forKey: prefixKey) ?? "c"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: prefixKey)
        }
    }

    static var historyRetentionHours: Int {
        get {
            if let stored = UserDefaults.standard.object(forKey: retentionHoursKey) as? Int {
                return stored
            }
            if let legacyDays = UserDefaults.standard.object(forKey: retentionDaysKey) as? Int {
                let hours = max(0, legacyDays) * 24
                UserDefaults.standard.set(hours, forKey: retentionHoursKey)
                return hours
            }
            return 168
        }
        set {
            UserDefaults.standard.set(max(0, newValue), forKey: retentionHoursKey)
        }
    }
}
