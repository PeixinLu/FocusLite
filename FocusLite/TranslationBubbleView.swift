import AppKit
import SwiftUI

// MARK: - Translation Bubble View

struct TranslationBubbleView: View {
    let sourceText: String
    let translationResult: TranslationResult?
    let isLoading: Bool
    let isPinned: Bool

    var onCopy: ((String) -> Void)?
    var onTogglePinned: (() -> Void)?
    var onSwapDirection: (() -> Void)?
    var onOpenInLauncher: (() -> Void)?
    var onPrepareSettings: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.defaultMaterialStyle.rawValue
    @AppStorage(AppearancePreferences.glassStyleKey)
    private var glassStyleRaw = AppearancePreferences.defaultGlassStyle.rawValue
    @AppStorage(AppearancePreferences.glassTintModeRegularKey)
    private var regularTintModeRaw = AppearancePreferences.defaultTintMode(for: .regular).rawValue
    @AppStorage(AppearancePreferences.glassTintModeClearKey)
    private var clearTintModeRaw = AppearancePreferences.defaultTintMode(for: .clear).rawValue
    @AppStorage(AppearancePreferences.glassTintRegularKey)
    private var regularTintRaw = AppearancePreferences.glassTintRegular
    @AppStorage(AppearancePreferences.glassTintClearKey)
    private var clearTintRaw = AppearancePreferences.glassTintClear
    @AppStorage(AppearancePreferences.liquidGlassCornerRadiusKey)
    private var cornerRadiusKey = AppearancePreferences.defaultCornerRadius

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? AppearancePreferences.defaultMaterialStyle
    }

    private var glassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: glassStyleRaw) ?? AppearancePreferences.defaultGlassStyle
    }

    private var glassTint: NSColor? {
        let mode = glassStyle.baseGlassStyle == .regular ? regularTintModeRaw : clearTintModeRaw
        let tintRaw = glassStyle.baseGlassStyle == .regular ? regularTintRaw : clearTintRaw
        let modeEnum = AppearancePreferences.TintMode(rawValue: mode) ?? .systemDefault
        switch modeEnum {
        case .off: return nil
        case .custom: return colorFromRGBA(tintRaw) ?? defaultTintColor
        case .systemDefault: return defaultTintColor
        }
    }

    private var defaultTintColor: NSColor {
        let base = colorScheme == .dark ? NSColor.black : NSColor.white
        return base.withAlphaComponent(0.618)
    }

    private var bubbleColorScheme: ColorScheme {
        materialStyle == .sunglasses ? .dark : colorScheme
    }

    private var bubbleCornerRadius: CGFloat { min(CGFloat(cornerRadiusKey), 16) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(sourceText)
                    .font(.system(size: 11))
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let translationResult {
                    directionButton(for: translationResult)
                }
                closeButton
            }

            if isLoading, translationResult == nil {
                loadingView
            } else if let result = translationResult {
                resultContent(result)
                actionBar(for: result)
            }
        }
        .frame(width: 300)
        .fixedSize(horizontal: true, vertical: true)
        .padding(12)
        .background(
            LiquidGlassBackground(
                cornerRadius: bubbleCornerRadius,
                isHighlighted: true,
                style: materialStyle,
                glassStyle: glassStyle,
                glassTint: glassTint,
                animationDuration: 0.18
            )
        )
        .environment(\.colorScheme, bubbleColorScheme)
    }

    // MARK: - Controls

    private var closeButton: some View {
        Button(action: { onDismiss?() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("关闭 (Esc)")
    }

    private func directionButton(for result: TranslationResult) -> some View {
        Button(action: { onSwapDirection?() }) {
            Text(result.compactDirectionLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 5)
                .frame(height: 18)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .help("切换翻译方向")
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 16, height: 16)
            Text("正在翻译…")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Result

    private func resultContent(_ result: TranslationResult) -> some View {
        Text(result.translatedText)
            .font(.system(size: 15, weight: .regular))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Bar

    private func actionBar(for result: TranslationResult) -> some View {
        HStack(spacing: 6) {
            Spacer()
            iconButton(systemName: "doc.on.doc", help: "复制") {
                onCopy?(result.translatedText)
            }
            pinButton
            iconButton(systemName: "magnifyingglass", help: "打开翻译搜索框") {
                onOpenInLauncher?()
            }
            settingsButton
        }
    }

    private var pinButton: some View {
        Button(action: { onTogglePinned?() }) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isPinned ? .accentColor : .secondary)
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.plain)
        .help(isPinned ? "取消置顶" : "置顶")
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14, *) {
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                onPrepareSettings?()
            })
            .help("翻译设置")
        } else {
            iconButton(systemName: "gearshape", help: "翻译设置") {
                onOpenSettings?()
            }
        }
    }

    private func iconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
