import Foundation

enum SnippetsPreferences {
    private static let prefixKey = "snippets.searchPrefix"
    private static let autoPasteKey = "snippets.autoPasteAfterSelect"
    private static let hotKeyTextKey = "snippets.hotKeyText"

    static var searchPrefix: String {
        get {
            UserDefaults.standard.string(forKey: prefixKey) ?? "sn"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: prefixKey)
        }
    }

    static var autoPasteAfterSelect: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoPasteKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: autoPasteKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoPasteKey)
        }
    }

    static var hotKeyText: String {
        get { UserDefaults.standard.string(forKey: hotKeyTextKey) ?? "" }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: hotKeyTextKey)
        }
    }
}
