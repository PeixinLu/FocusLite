import Foundation

enum AppSearchPreferences {
    private static let excludedBundleIDsKey = "appSearch.excludedBundleIDs"
    private static let excludedPathsKey = "appSearch.excludedPaths"

    static var excludedBundleIDs: Set<String> {
        get {
            guard let values = UserDefaults.standard.array(forKey: excludedBundleIDsKey) as? [String] else {
                return []
            }
            return Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        }
        set {
            let cleaned = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            UserDefaults.standard.set(Array(Set(cleaned)).sorted(), forKey: excludedBundleIDsKey)
        }
    }

    static var excludedPaths: Set<String> {
        get {
            guard let values = UserDefaults.standard.array(forKey: excludedPathsKey) as? [String] else {
                return []
            }
            return Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        }
        set {
            let cleaned = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            UserDefaults.standard.set(Array(Set(cleaned)).sorted(), forKey: excludedPathsKey)
        }
    }

    static func isExcluded(bundleID: String?, path: String, excludedBundleIDs: Set<String>, excludedPaths: Set<String>) -> Bool {
        if let bundleID, excludedBundleIDs.contains(bundleID) {
            return true
        }
        return excludedPaths.contains(path)
    }
}
