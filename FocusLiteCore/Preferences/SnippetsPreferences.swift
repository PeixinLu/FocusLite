import Foundation

enum SnippetsPreferences {
    private static let prefixKey = "snippets.searchPrefix"

    static var searchPrefix: String {
        get {
            UserDefaults.standard.string(forKey: prefixKey) ?? "sn"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: prefixKey)
        }
    }
}
