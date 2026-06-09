import AppKit
import SwiftUI

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
@available(macOS 26, *)
struct GlassBackgroundView: NSViewRepresentable {
    let cornerRadius: CGFloat
    let style: AppearancePreferences.GlassStyle
    let tintColor: NSColor?

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        view.style = style.nsStyle
        view.tintColor = tintColor
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style.nsStyle
        nsView.tintColor = tintColor
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

    var body: some View {
        ZStack {
            backgroundBase
            fadeGradientOverlay
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(.easeInOut(duration: animationDuration), value: isHighlighted && style == .liquid)
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
        case .liquid:
            if #available(macOS 26, *) {
                GlassBackgroundView(
                    cornerRadius: cornerRadius,
                    style: glassStyle.baseGlassStyle,
                    tintColor: glassTint
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
        if style == .liquid, glassStyle == .fade {
            LinearGradient(
                stops: glassStyle.fadeOverlayStops.map { stop in
                    Gradient.Stop(
                        color: Color.black.opacity(stop.opacity),
                        location: stop.location
                    )
                },
                startPoint: .top,
                endPoint: .bottom
            )
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
    var nsStyle: NSGlassEffectView.Style {
        switch self {
        case .regular:
            return .regular
        case .clear, .fade:
            return .clear
        }
    }
}
