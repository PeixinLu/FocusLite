import Foundation

enum GeneralPreferences {
    private static let launcherHotKeyKey = "general.launcherHotKey"

    static var launcherHotKeyText: String {
        get {
            let stored = UserDefaults.standard.string(forKey: launcherHotKeyKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stored?.isEmpty == false ? stored! : "option+space"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = trimmed.isEmpty ? "option+space" : trimmed
            UserDefaults.standard.set(value, forKey: launcherHotKeyKey)
        }
    }
}
