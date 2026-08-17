import AppKit
import SwiftUI

// MARK: - Private NSGlassEffectView API helpers

/// Call the private `set_variant:` method on NSGlassEffectView.
/// Variant is the specific glass recipe within a style class (0-19+).
func setGlassVariant(_ view: NSView, _ value: Int) {
    let selector = NSSelectorFromString("set_variant:")
    guard view.responds(to: selector) else { return }
    typealias Fn = @convention(c) (AnyObject, Selector, Int) -> Void
    let imp = view.method(for: selector)
    let fn = unsafeBitCast(imp, to: Fn.self)
    fn(view, selector, value)
}

func setGlassScrimState(_ view: NSView, _ value: Bool) {
    let selector = NSSelectorFromString("set_scrimState:")
    guard view.responds(to: selector) else { return }
    typealias Fn = @convention(c) (AnyObject, Selector, Bool) -> Void
    let imp = view.method(for: selector)
    let fn = unsafeBitCast(imp, to: Fn.self)
    fn(view, selector, value)
}

func setGlassSubduedState(_ view: NSView, _ value: Bool) {
    let selector = NSSelectorFromString("set_subduedState:")
    guard view.responds(to: selector) else { return }
    typealias Fn = @convention(c) (AnyObject, Selector, Bool) -> Void
    let imp = view.method(for: selector)
    let fn = unsafeBitCast(imp, to: Fn.self)
    fn(view, selector, value)
}

// MARK: - Shared Glass / Liquid Glass rendering views

/// NSVisualEffectView wrapper for pre-macOS 26 fallback.
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

/// NSGlassEffectView wrapper for macOS 26+ Liquid Glass.
/// Stable styles (regular/clear) use .style; experimental styles use .clear + set_variant:.
@available(macOS 26, *)
struct GlassBackgroundView: NSViewRepresentable {
    let cornerRadius: CGFloat
    let style: AppearancePreferences.GlassStyle
    let tintColor: NSColor?
    var scrimState: Bool = false
    var subduedState: Bool = false

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        view.style = style.nsStyle
        view.tintColor = tintColor
        applyPrivateAPIs(view)
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style.nsStyle
        nsView.tintColor = tintColor
        applyPrivateAPIs(nsView)
    }

    private func applyPrivateAPIs(_ view: NSGlassEffectView) {
        if style.variantValue != 0 {
            setGlassVariant(view, style.variantValue)
        }
        setGlassScrimState(view, scrimState)
        setGlassSubduedState(view, subduedState)
    }
}

/// NSGlassEffectView wrapper that places SwiftUI content inside `contentView`.
@available(macOS 26, *)
struct GlassContentView<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let style: AppearancePreferences.GlassStyle
    let tintColor: NSColor?
    var scrimState: Bool = false
    var subduedState: Bool = false
    let content: Content

    init(
        cornerRadius: CGFloat,
        style: AppearancePreferences.GlassStyle,
        tintColor: NSColor?,
        scrimState: Bool = false,
        subduedState: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.style = style
        self.tintColor = tintColor
        self.scrimState = scrimState
        self.subduedState = subduedState
        self.content = content()
    }

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        view.style = style.nsStyle
        view.tintColor = tintColor
        applyPrivateAPIs(view)

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        view.contentView = hostingView
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style.nsStyle
        nsView.tintColor = tintColor
        applyPrivateAPIs(nsView)

        if let hostingView = nsView.contentView as? NSHostingView<Content> {
            hostingView.rootView = content
        } else {
            let hostingView = NSHostingView(rootView: content)
            hostingView.frame = nsView.bounds
            hostingView.autoresizingMask = [.width, .height]
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            nsView.contentView = hostingView
        }
    }

    private func applyPrivateAPIs(_ view: NSGlassEffectView) {
        if style.variantValue != 0 {
            setGlassVariant(view, style.variantValue)
        }
        setGlassScrimState(view, scrimState)
        setGlassSubduedState(view, subduedState)
    }
}

/// Experimental launcher container that lets NSGlassEffectView own its content.
struct LiquidGlassContentContainer<Content: View>: View {
    let cornerRadius: CGFloat
    let isHighlighted: Bool
    let style: AppearancePreferences.MaterialStyle
    let glassStyle: AppearancePreferences.GlassStyle
    let glassTint: NSColor?
    let animationDuration: Double
    var sunglassesTopSolid: CGFloat = AppearancePreferences.defaultSunglassesTopSolid
    var sunglassesTopFade: CGFloat = AppearancePreferences.defaultSunglassesTopFade
    var sunglassesMidTopAlpha: CGFloat = AppearancePreferences.defaultSunglassesMidTopAlpha
    var sunglassesMidBottomAlpha: CGFloat = AppearancePreferences.defaultSunglassesMidBottomAlpha
    var sunglassesBottomFade: CGFloat = AppearancePreferences.defaultSunglassesBottomFade
    var sunglassesCornerInfluence: CGFloat = AppearancePreferences.defaultSunglassesCornerInfluence
    var scrimState: Bool = false
    var subduedState: Bool = false
    let content: Content

    init(
        cornerRadius: CGFloat,
        isHighlighted: Bool,
        style: AppearancePreferences.MaterialStyle,
        glassStyle: AppearancePreferences.GlassStyle,
        glassTint: NSColor?,
        animationDuration: Double,
        sunglassesTopSolid: CGFloat = AppearancePreferences.defaultSunglassesTopSolid,
        sunglassesTopFade: CGFloat = AppearancePreferences.defaultSunglassesTopFade,
        sunglassesMidTopAlpha: CGFloat = AppearancePreferences.defaultSunglassesMidTopAlpha,
        sunglassesMidBottomAlpha: CGFloat = AppearancePreferences.defaultSunglassesMidBottomAlpha,
        sunglassesBottomFade: CGFloat = AppearancePreferences.defaultSunglassesBottomFade,
        sunglassesCornerInfluence: CGFloat = AppearancePreferences.defaultSunglassesCornerInfluence,
        scrimState: Bool = false,
        subduedState: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.style = style
        self.glassStyle = glassStyle
        self.glassTint = glassTint
        self.animationDuration = animationDuration
        self.sunglassesTopSolid = sunglassesTopSolid
        self.sunglassesTopFade = sunglassesTopFade
        self.sunglassesMidTopAlpha = sunglassesMidTopAlpha
        self.sunglassesMidBottomAlpha = sunglassesMidBottomAlpha
        self.sunglassesBottomFade = sunglassesBottomFade
        self.sunglassesCornerInfluence = sunglassesCornerInfluence
        self.scrimState = scrimState
        self.subduedState = subduedState
        self.content = content()
    }

    var body: some View {
        if style == .liquid, #available(macOS 26, *) {
            GlassContentView(
                cornerRadius: cornerRadius,
                style: glassStyle,
                tintColor: glassTint,
                scrimState: scrimState,
                subduedState: subduedState
            ) {
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(.easeInOut(duration: animationDuration), value: isHighlighted && style.isLiquid)
        } else {
            content
                .background(
                    LiquidGlassBackground(
                        cornerRadius: cornerRadius,
                        isHighlighted: isHighlighted,
                        style: style,
                        glassStyle: glassStyle,
                        glassTint: glassTint,
                        animationDuration: animationDuration,
                        sunglassesTopSolid: sunglassesTopSolid,
                        sunglassesTopFade: sunglassesTopFade,
                        sunglassesMidTopAlpha: sunglassesMidTopAlpha,
                        sunglassesMidBottomAlpha: sunglassesMidBottomAlpha,
                        sunglassesBottomFade: sunglassesBottomFade,
                        sunglassesCornerInfluence: sunglassesCornerInfluence,
                        scrimState: scrimState,
                        subduedState: subduedState
                    )
                )
        }
    }
}

/// Full liquid glass / classic / pure background used for the launcher window.
struct LiquidGlassBackground: View {
    let cornerRadius: CGFloat
    let isHighlighted: Bool
    let style: AppearancePreferences.MaterialStyle
    let glassStyle: AppearancePreferences.GlassStyle
    let glassTint: NSColor?
    let animationDuration: Double
    var sunglassesTopSolid: CGFloat = AppearancePreferences.defaultSunglassesTopSolid
    var sunglassesTopFade: CGFloat = AppearancePreferences.defaultSunglassesTopFade
    var sunglassesMidTopAlpha: CGFloat = AppearancePreferences.defaultSunglassesMidTopAlpha
    var sunglassesMidBottomAlpha: CGFloat = AppearancePreferences.defaultSunglassesMidBottomAlpha
    var sunglassesBottomFade: CGFloat = AppearancePreferences.defaultSunglassesBottomFade
    var sunglassesCornerInfluence: CGFloat = AppearancePreferences.defaultSunglassesCornerInfluence
    var scrimState: Bool = false
    var subduedState: Bool = false

    var body: some View {
        ZStack {
            backgroundBase
            fadeGradientOverlay
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(.easeInOut(duration: animationDuration), value: isHighlighted && style.isLiquid)
    }

    @ViewBuilder
    private var backgroundBase: some View {
        switch style {
        case .classic:
            VisualEffectView(
                material: .popover,
                blendingMode: .behindWindow,
                state: .active
            )
        case .liquid, .sunglasses:
            if #available(macOS 26, *) {
                GlassBackgroundView(
                    cornerRadius: cornerRadius,
                    style: glassStyle,
                    tintColor: glassTint,
                    scrimState: scrimState,
                    subduedState: subduedState
                )
            } else {
                VisualEffectView(
                    material: glassMaterial,
                    blendingMode: .behindWindow,
                    state: .active
                )
            }
        case .pure:
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private var glassMaterial: NSVisualEffectView.Material {
        if #available(macOS 26, *) {
            return .hudWindow
        }
        if #available(macOS 13, *) {
            return glassStyle.baseGlassStyle == .clear ? .hudWindow : .popover
        }
        return glassStyle.baseGlassStyle == .clear ? .hudWindow : .hudWindow
    }

    @ViewBuilder
    private var fadeGradientOverlay: some View {
        if style == .sunglasses {
            if #available(macOS 15, *) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black)
                    .colorEffect(
                        ShaderLibrary.sunglassesFade(
                            .boundingRect,
                            .float(Float(cornerRadius)),
                            .float(Float(sunglassesTopSolid)),
                            .float(Float(sunglassesTopFade)),
                            .float(Float(sunglassesMidTopAlpha)),
                            .float(Float(sunglassesMidBottomAlpha)),
                            .float(Float(sunglassesBottomFade)),
                            .float(Float(sunglassesCornerInfluence))
                        )
                    )
            } else {
                // Fallback for macOS <15: simple top-to-bottom fade
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .black, location: 0.0),
                        Gradient.Stop(color: .black.opacity(0.9), location: 0.15),
                        Gradient.Stop(color: .black.opacity(0.6), location: 0.3),
                        Gradient.Stop(color: .black.opacity(0.15), location: 0.85),
                        Gradient.Stop(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

/// Liquid glass background for selected/highlighted result rows.
struct LiquidGlassRowBackground: View {
    let cornerRadius: CGFloat
    let glassStyle: AppearancePreferences.GlassStyle
    let glassTint: NSColor?

    var body: some View {
        ZStack {
            if #available(macOS 26, *) {
                GlassBackgroundView(
                    cornerRadius: cornerRadius,
                    style: glassStyle.baseGlassStyle,
                    tintColor: glassTint
                )
            } else {
                VisualEffectView(
                    material: glassStyle.baseGlassStyle == .clear ? .hudWindow : .popover,
                    blendingMode: .behindWindow,
                    state: .active
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
        )
    }
}

/// Parse RGBA color string "r,g,b,a" into NSColor.
func colorFromRGBA(_ raw: String) -> NSColor? {
    let parts = raw.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 4 else { return nil }
    return NSColor(
        calibratedRed: parts[0],
        green: parts[1],
        blue: parts[2],
        alpha: parts[3]
    )
}

@available(macOS 26, *)
extension AppearancePreferences.GlassStyle {
    /// Maps to the public NSGlassEffectView.Style. Experimental styles all use .clear base;
    /// the difference is driven by set_variant:.
    var nsStyle: NSGlassEffectView.Style {
        switch self {
        case .regular:
            return .regular
        default:
            return .clear
        }
    }
}
