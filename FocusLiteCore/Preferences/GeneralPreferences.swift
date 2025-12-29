import Foundation

enum GeneralPreferences {
    private static let launcherHotKeyKey = "general.launcherHotKey"

    static var launcherHotKeyText: String {
        get {
            let stored = UserDefaults.standard.string(forKey: launcherHotKeyKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stored?.isEmpty == false ? stored! : "command+space"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = trimmed.isEmpty ? "command+space" : trimmed
            UserDefaults.standard.set(value, forKey: launcherHotKeyKey)
        }
    }
}
