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
        case fade

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .regular: return "常规"
            case .clear: return "通透"
            case .fade: return "渐隐"
            }
        }

        var baseGlassStyle: GlassStyle {
            switch self {
            case .regular:
                return .regular
            case .clear, .fade:
                return .clear
            }
        }

        var fadeOverlayStops: [FadeOverlayStop] {
            guard self == .fade else { return [] }
            return Self.defaultFadeOverlayStops
        }

        var usesLightForeground: Bool {
            self == .fade
        }

        static let defaultFadeOverlayStops: [FadeOverlayStop] = [
            FadeOverlayStop(location: 0.0, opacity: 0.96),
            FadeOverlayStop(location: 0.25, opacity: 0.94),
            FadeOverlayStop(location: 0.5, opacity: 0.9),
            FadeOverlayStop(location: 0.68, opacity: 0.82),
            FadeOverlayStop(location: 0.8, opacity: 0.62),
            FadeOverlayStop(location: 0.9, opacity: 0.34),
            FadeOverlayStop(location: 0.96, opacity: 0.16),
            FadeOverlayStop(location: 1.0, opacity: 0.06)
        ]
    }

    struct FadeOverlayStop: Equatable {
        let location: Double
        let opacity: Double
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
                return style.baseGlassStyle
            }
            return glassStyle.baseGlassStyle
        }
        set {
            UserDefaults.standard.set(newValue.baseGlassStyle.rawValue, forKey: rowGlassStyleKey)
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
        switch style.baseGlassStyle {
        case .regular:
            return glassTintModeRegular == .off ? .off : glassTintModeRegular
        case .clear, .fade:
            return glassTintModeClear == .off ? .systemDefault : glassTintModeClear
        }
    }

    static func setGlassTintMode(_ mode: TintMode, for style: GlassStyle) {
        switch style.baseGlassStyle {
        case .regular:
            glassTintModeRegular = mode
        case .clear, .fade:
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
        switch style.baseGlassStyle {
        case .regular:
            return glassTintRegular
        case .clear, .fade:
            return glassTintClear
        }
    }

    static func setGlassTint(_ value: String, for style: GlassStyle) {
        switch style.baseGlassStyle {
        case .regular:
            glassTintRegular = value
        case .clear, .fade:
            glassTintClear = value
        }
    }

    static func defaultTintMode(for style: GlassStyle) -> TintMode {
        style.baseGlassStyle == .regular ? .off : .systemDefault
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
