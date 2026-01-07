import Foundation

enum AppearancePreferences {
    static let materialStyleKey = "appearance.materialStyle"
    static let glassStyleKey = "appearance.glassStyle"
    static let glassTintKey = "appearance.glassTint"

    enum MaterialStyle: String, CaseIterable, Identifiable {
        case classic
        case liquid
        case pure

        var id: String { rawValue }
    }

    enum GlassStyle: String, CaseIterable, Identifiable {
        case regular
        case clear

        var id: String { rawValue }
    }

    static var materialStyle: MaterialStyle {
        get {
            let value = UserDefaults.standard.string(forKey: materialStyleKey)
            return MaterialStyle(rawValue: value ?? "") ?? .liquid
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: materialStyleKey)
        }
    }

    static var glassStyle: GlassStyle {
        get {
            let value = UserDefaults.standard.string(forKey: glassStyleKey)
            return GlassStyle(rawValue: value ?? "") ?? .regular
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: glassStyleKey)
        }
    }

    static var glassTint: String {
        get {
            UserDefaults.standard.string(forKey: glassTintKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: glassTintKey)
        }
    }
}
