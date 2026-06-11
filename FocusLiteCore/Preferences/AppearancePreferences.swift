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
    static let sunglassesTopSolidHeightKey = "appearance.sunglasses.topSolidHeight"
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
        case sunglasses

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .regular: return "常规"
            case .clear: return "通透"
            case .sunglasses: return "太阳眼镜"
            }
        }

        var baseGlassStyle: GlassStyle {
            switch self {
            case .regular:
                return .regular
            case .clear, .sunglasses:
                return .clear
            }
        }

        var usesLightForeground: Bool {
            self == .sunglasses
        }
    }

    enum SunglassesTheme: String, CaseIterable, Identifiable {
        case `default`    // 系统默认
        case warmAmber    // 暖琥珀
        case warmSilver   // 暖灰银
        case champagne    // 香槟金
        case lightBeige   // 浅裸色
        case coolPlatinum // 冷铂金

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .default:       return "默认"
            case .warmAmber:     return "暖琥珀"
            case .warmSilver:    return "暖灰银"
            case .champagne:     return "香槟金"
            case .lightBeige:    return "浅裸色"
            case .coolPlatinum:  return "冷铂金"
            }
        }

        /// Returns nil for default (use system accent), otherwise the theme color
        var nsColor: NSColor? {
            switch self {
            case .default:       return nil
            case .warmAmber:     return NSColor(calibratedRed: 0.788, green: 0.608, blue: 0.361, alpha: 1.0)
            case .warmSilver:    return NSColor(calibratedRed: 0.627, green: 0.604, blue: 0.573, alpha: 1.0)
            case .champagne:     return NSColor(calibratedRed: 0.769, green: 0.659, blue: 0.510, alpha: 1.0)
            case .lightBeige:    return NSColor(calibratedRed: 0.784, green: 0.659, blue: 0.588, alpha: 1.0)
            case .coolPlatinum:  return NSColor(calibratedRed: 0.659, green: 0.659, blue: 0.690, alpha: 1.0)
            }
        }

        /// RGBA for HDR scaling (nil for default)
        var rgba: (r: Double, g: Double, b: Double, a: Double)? {
            guard let c = nsColor else { return nil }
            return (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent))
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
        case .clear, .sunglasses:
            return glassTintModeClear == .off ? .systemDefault : glassTintModeClear
        }
    }

    static func setGlassTintMode(_ mode: TintMode, for style: GlassStyle) {
        switch style.baseGlassStyle {
        case .regular:
            glassTintModeRegular = mode
        case .clear, .sunglasses:
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
        case .clear, .sunglasses:
            return glassTintClear
        }
    }

    static func setGlassTint(_ value: String, for style: GlassStyle) {
        switch style.baseGlassStyle {
        case .regular:
            glassTintRegular = value
        case .clear, .sunglasses:
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

    static let sunglassesTopSolidKey = "appearance.sunglasses.topSolid"
    static let sunglassesTopFadeKey = "appearance.sunglasses.topFade"
    static let sunglassesMidTopAlphaKey = "appearance.sunglasses.midTopAlpha"
    static let sunglassesMidBottomAlphaKey = "appearance.sunglasses.midBottomAlpha"
    static let sunglassesBottomFadeKey = "appearance.sunglasses.bottomFade"
    static let sunglassesCornerInfluenceKey = "appearance.sunglasses.cornerInfluence"
    static let sunglassesThemeKey = "appearance.sunglasses.theme"
    static let sunglassesHDRKey = "appearance.sunglasses.hdr"

    static var defaultSunglassesTopSolid: Double { 18.0 }
    static var defaultSunglassesTopFade: Double { 40.0 }
    static var defaultSunglassesMidTopAlpha: Double { 0.9 }
    static var defaultSunglassesMidBottomAlpha: Double { 0.15 }
    static var defaultSunglassesBottomFade: Double { 18.0 }
    static var defaultSunglassesCornerInfluence: Double { 0.4 }
    static var defaultSunglassesTheme: SunglassesTheme { .default }
    static var sunglassesModeTheme: SunglassesTheme { .warmAmber }
    static var defaultSunglassesHDR: Bool { true }

    static var sunglassesTopSolid: Double {
        get { udDouble(sunglassesTopSolidKey, defaultSunglassesTopSolid) }
        set { UserDefaults.standard.set(newValue, forKey: sunglassesTopSolidKey) }
    }
    static var sunglassesTopFade: Double {
        get { udDouble(sunglassesTopFadeKey, defaultSunglassesTopFade) }
        set { UserDefaults.standard.set(newValue, forKey: sunglassesTopFadeKey) }
    }
    static var sunglassesMidTopAlpha: Double {
        get { udDouble(sunglassesMidTopAlphaKey, defaultSunglassesMidTopAlpha) }
        set { UserDefaults.standard.set(newValue, forKey: sunglassesMidTopAlphaKey) }
    }
    static var sunglassesMidBottomAlpha: Double {
        get { udDouble(sunglassesMidBottomAlphaKey, defaultSunglassesMidBottomAlpha) }
        set { UserDefaults.standard.set(newValue, forKey: sunglassesMidBottomAlphaKey) }
    }
    static var sunglassesBottomFade: Double {
        get { udDouble(sunglassesBottomFadeKey, defaultSunglassesBottomFade) }
        set { UserDefaults.standard.set(newValue, forKey: sunglassesBottomFadeKey) }
    }
    static var sunglassesCornerInfluence: Double {
        get { udDouble(sunglassesCornerInfluenceKey, defaultSunglassesCornerInfluence) }
        set { UserDefaults.standard.set(newValue, forKey: sunglassesCornerInfluenceKey) }
    }
    static var sunglassesTheme: SunglassesTheme {
        get {
            if let raw = UserDefaults.standard.string(forKey: sunglassesThemeKey),
               let theme = SunglassesTheme(rawValue: raw) { return theme }
            return defaultSunglassesTheme
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sunglassesThemeKey) }
    }
    static var sunglassesHDR: Bool {
        get {
            if UserDefaults.standard.object(forKey: sunglassesHDRKey) != nil {
                return UserDefaults.standard.bool(forKey: sunglassesHDRKey)
            }
            return defaultSunglassesHDR
        }
        set { UserDefaults.standard.set(newValue, forKey: sunglassesHDRKey) }
    }

    private static func udDouble(_ key: String, _ defaultVal: Double) -> Double {
        UserDefaults.standard.object(forKey: key) != nil
            ? UserDefaults.standard.double(forKey: key)
            : defaultVal
    }

    static func defaultTintColor(isDarkMode: Bool) -> NSColor {
        let base = isDarkMode ? NSColor.black : NSColor.white
        return base.withAlphaComponent(0.618)
    }
}
