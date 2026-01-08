import Foundation

enum AppearancePreferences {
    static let materialStyleKey = "appearance.materialStyle"
    static let glassStyleKey = "appearance.glassStyle"
    static let glassTintKey = "appearance.glassTint"
    
    // Liquid Glass 精细调节参数
    static let liquidGlassHighlightIntensityKey = "appearance.liquidGlass.highlightIntensity"
    static let liquidGlassBlurRadiusKey = "appearance.liquidGlass.blurRadius"
    static let liquidGlassRefractionStrengthKey = "appearance.liquidGlass.refractionStrength"
    static let liquidGlassBorderOpacityKey = "appearance.liquidGlass.borderOpacity"
    static let liquidGlassGradientStartOpacityKey = "appearance.liquidGlass.gradientStartOpacity"
    static let liquidGlassGradientEndOpacityKey = "appearance.liquidGlass.gradientEndOpacity"
    static let liquidGlassAnimationDurationKey = "appearance.liquidGlass.animationDuration"
    static let liquidGlassCornerRadiusKey = "appearance.liquidGlass.cornerRadius"

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
    
    // MARK: - Liquid Glass 微调参数
    
    /// 高光强度（聚焦时顶部渐变的起始透明度，范围 0.0-1.0）
    static var liquidGlassHighlightIntensity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassHighlightIntensityKey)
            return value > 0 ? value : 0.45 // 默认 0.45
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassHighlightIntensityKey)
        }
    }
    
    /// 模糊半径（背景模糊程度，范围 0-100）
    static var liquidGlassBlurRadius: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassBlurRadiusKey)
            return value > 0 ? value : 30.0 // 默认 30
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassBlurRadiusKey)
        }
    }
    
    /// 折射强度（玻璃折射效果，范围 0.0-1.0）
    static var liquidGlassRefractionStrength: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassRefractionStrengthKey)
            return value > 0 ? value : 0.6 // 默认 0.6
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassRefractionStrengthKey)
        }
    }
    
    /// 边框透明度（聚焦时，范围 0.0-1.0）
    static var liquidGlassBorderOpacity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassBorderOpacityKey)
            return value > 0 ? value : 0.6 // 默认 0.6
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassBorderOpacityKey)
        }
    }
    
    /// 渐变起始透明度（聚焦时顶部）
    static var liquidGlassGradientStartOpacity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassGradientStartOpacityKey)
            return value > 0 ? value : 0.45 // 默认 0.45
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassGradientStartOpacityKey)
        }
    }
    
    /// 渐变结束透明度（聚焦时底部）
    static var liquidGlassGradientEndOpacity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassGradientEndOpacityKey)
            return value > 0 ? value : 0.14 // 默认 0.14
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassGradientEndOpacityKey)
        }
    }
    
    /// 动画时长（秒）
    static var liquidGlassAnimationDuration: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassAnimationDurationKey)
            return value > 0 ? value : 0.18 // 默认 0.18s
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassAnimationDurationKey)
        }
    }
    
    /// 圆角半径
    static var liquidGlassCornerRadius: Double {
        get {
            let value = UserDefaults.standard.double(forKey: liquidGlassCornerRadiusKey)
            return value > 0 ? value : 16.0 // 默认 16
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liquidGlassCornerRadiusKey)
        }
    }
}
