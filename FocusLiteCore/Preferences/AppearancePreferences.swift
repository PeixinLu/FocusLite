import AppKit
import Foundation

enum AppearancePreferences {
    static let materialStyleKey = "appearance.materialStyle"
    static let glassStyleKey = "appearance.glassStyle" // 搜索框
    static let rowGlassStyleKey = "appearance.rowGlassStyle" // 候选项
    static let legacyGlassTintKey = "appearance.glassTint"
    static let glassTintRegularKey = "appearance.glassTint.regular"
    static let glassTintClearKey = "appearance.glassTint.clear"
    static let glassTintModeRegularKey = "appearance.glassTintMode.regular"
    static let glassTintModeClearKey = "appearance.glassTintMode.clear"
    static let liquidGlassAnimationDurationKey = "appearance.liquidGlass.animationDuration"
    static let liquidGlassCornerRadiusKey = "appearance.liquidGlass.cornerRadius"
    private static let modernGlassOSVersion = OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)

    enum MaterialStyle: String, CaseIterable, Identifiable {
        case classic
        case liquid
        case pure

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .classic: return "macOS经典"
            case .liquid: return "液态玻璃"
            case .pure: return "纯色"
            }
        }
    }

    enum GlassStyle: String, CaseIterable, Identifiable {
        case regular
        case clear

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .regular: return "常规"
            case .clear: return "通透"
            }
        }
    }

    enum TintMode: String, CaseIterable, Identifiable {
        case off
        case systemDefault
        case custom

        var id: String { rawValue }
    }

    static var defaultMaterialStyle: MaterialStyle {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(modernGlassOSVersion) ? .liquid : .classic
    }

    static var defaultGlassStyle: GlassStyle {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(modernGlassOSVersion) ? .clear : .regular
    }

    static var defaultAnimationDuration: Double { 0.08 }

    static var defaultCornerRadius: Double { 20.0 }

    static var materialStyle: MaterialStyle {
        get {
            let value = UserDefaults.standard.string(forKey: materialStyleKey)
            return MaterialStyle(rawValue: value ?? "") ?? defaultMaterialStyle
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: materialStyleKey)
        }
    }

    static var glassStyle: GlassStyle {
        get {
            let value = UserDefaults.standard.string(forKey: glassStyleKey)
            return GlassStyle(rawValue: value ?? "") ?? defaultGlassStyle
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: glassStyleKey)
        }
    }

    static var rowGlassStyle: GlassStyle {
        get {
            if let value = UserDefaults.standard.string(forKey: rowGlassStyleKey),
               let style = GlassStyle(rawValue: value) {
                return style
            }
            return glassStyle
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: rowGlassStyleKey)
        }
    }

    static var glassTintModeRegular: TintMode {
        get {
            let value = UserDefaults.standard.string(forKey: glassTintModeRegularKey)
            return TintMode(rawValue: value ?? "") ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: glassTintModeRegularKey)
        }
    }

    static var glassTintModeClear: TintMode {
        get {
            let value = UserDefaults.standard.string(forKey: glassTintModeClearKey)
            return TintMode(rawValue: value ?? "") ?? .systemDefault
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: glassTintModeClearKey)
        }
    }

    static func glassTintMode(for style: GlassStyle) -> TintMode {
        switch style {
        case .regular:
            return glassTintModeRegular == .off ? .off : glassTintModeRegular
        case .clear:
            return glassTintModeClear == .off ? .systemDefault : glassTintModeClear
        }
    }

    static func setGlassTintMode(_ mode: TintMode, for style: GlassStyle) {
        switch style {
        case .regular:
            glassTintModeRegular = mode
        case .clear:
            glassTintModeClear = mode
        }
    }

    static var glassTintRegular: String {
        get {
            UserDefaults.standard.string(forKey: glassTintRegularKey)
            ?? UserDefaults.standard.string(forKey: legacyGlassTintKey)
            ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: glassTintRegularKey)
        }
    }

    static var glassTintClear: String {
        get {
            UserDefaults.standard.string(forKey: glassTintClearKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: glassTintClearKey)
        }
    }

    static func glassTint(for style: GlassStyle) -> String {
        switch style {
        case .regular:
            return glassTintRegular
        case .clear:
            return glassTintClear
        }
    }

    static func setGlassTint(_ value: String, for style: GlassStyle) {
        switch style {
        case .regular:
            glassTintRegular = value
        case .clear:
            glassTintClear = value
        }
    }

    static func defaultTintMode(for style: GlassStyle) -> TintMode {
        style == .regular ? .off : .systemDefault
    }

    static var liquidGlassAnimationDuration: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassAnimationDurationKey)
            return value > 0 ? value : defaultAnimationDuration
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassAnimationDurationKey)
        }
    }

    static var liquidGlassCornerRadius: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassCornerRadiusKey)
            return value > 0 ? value : defaultCornerRadius
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassCornerRadiusKey)
        }
    }

    static func defaultTintColor(isDarkMode: Bool) -> NSColor {
        let base = isDarkMode ? NSColor.black : NSColor.white
        return base.withAlphaComponent(0.618)
    }
}
