import AppKit
import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.MaterialStyle.liquid.rawValue
    @AppStorage(AppearancePreferences.glassStyleKey)
    private var glassStyleRaw = AppearancePreferences.GlassStyle.regular.rawValue
    @AppStorage(AppearancePreferences.rowGlassStyleKey)
    private var rowGlassStyleRaw = AppearancePreferences.glassStyle.rawValue
    @AppStorage(AppearancePreferences.glassTintModeRegularKey)
    private var regularTintModeRaw = AppearancePreferences.defaultTintMode(for: .regular).rawValue
    @AppStorage(AppearancePreferences.glassTintModeClearKey)
    private var clearTintModeRaw = AppearancePreferences.defaultTintMode(for: .clear).rawValue
    @AppStorage(AppearancePreferences.glassTintRegularKey)
    private var regularTintRaw = AppearancePreferences.glassTintRegular
    @AppStorage(AppearancePreferences.glassTintClearKey)
    private var clearTintRaw = AppearancePreferences.glassTintClear
    
    @AppStorage(AppearancePreferences.liquidGlassAnimationDurationKey)
    private var animationDuration = 0.18
    @AppStorage(AppearancePreferences.liquidGlassCornerRadiusKey)
    private var cornerRadius = 16.0

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? .liquid
    }

    private var glassStyle: AppearancePreferences.GlassStyle {
        AppearancePreferences.GlassStyle(rawValue: glassStyleRaw) ?? .regular
    }

    private var activeTintMode: AppearancePreferences.TintMode {
        get {
            let raw = glassStyle == .regular ? regularTintModeRaw : clearTintModeRaw
            return AppearancePreferences.TintMode(rawValue: raw)
            ?? AppearancePreferences.defaultTintMode(for: glassStyle)
        }
        nonmutating set {
            if glassStyle == .regular {
                regularTintModeRaw = newValue.rawValue
            } else {
                clearTintModeRaw = newValue.rawValue
            }
        }
    }

    private var tintEnabledBinding: Binding<Bool> {
        Binding(
            get: { activeTintMode != .off },
            set: { isOn in
                if isOn {
                    if activeTintMode == .off {
                        activeTintMode = AppearancePreferences.defaultTintMode(for: glassStyle)
                        if activeTintMode == .custom && activeTintRaw.isEmpty {
                            activeTintRaw = rgbaString(from: defaultTintColor)
                        }
                    }
                } else {
                    activeTintMode = .off
                }
            }
        )
    }

    private var activeTintRaw: String {
        get {
            glassStyle == .regular ? regularTintRaw : clearTintRaw
        }
        nonmutating set {
            if glassStyle == .regular {
                regularTintRaw = newValue
            } else {
                clearTintRaw = newValue
            }
        }
    }

    private var defaultTintColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.618) : Color.white.opacity(0.618)
    }

    private var activeTintColor: Color {
        colorFromRGBA(activeTintRaw) ?? defaultTintColor
    }

    private var activeTintOpacity: Double {
        alphaFromRGBA(activeTintRaw) ?? 0.618
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            // 材质选择
            SettingsSection("材质") {
                Picker("材质", selection: $materialStyleRaw) {
                    Text("经典").tag(AppearancePreferences.MaterialStyle.classic.rawValue)
                    Text("液态玻璃").tag(AppearancePreferences.MaterialStyle.liquid.rawValue)
                    Text("纯净").tag(AppearancePreferences.MaterialStyle.pure.rawValue)
                }
                .pickerStyle(.segmented)
            }

            // Liquid Glass 基础设置
            if materialStyle == .liquid {
                SettingsSection("搜索框外观") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("液态玻璃风格", selection: $glassStyleRaw) {
                            Text("Regular").tag(AppearancePreferences.GlassStyle.regular.rawValue)
                            Text("Clear").tag(AppearancePreferences.GlassStyle.clear.rawValue)
                        }
                        .pickerStyle(.segmented)

                        Divider()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: tintEnabledBinding) {
                                HStack {
                                    Text("色调")
                                    Spacer()
                                    Text(glassStyle == .regular ? "Regular 独立色调" : "Clear 独立色调")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)

                            Picker("色调模式", selection: Binding(
                                get: { activeTintMode.rawValue },
                                set: { newValue in
                                    let mode = AppearancePreferences.TintMode(rawValue: newValue) ?? .systemDefault
                                    activeTintMode = mode
                                    if mode == .custom && activeTintRaw.isEmpty {
                                        activeTintRaw = rgbaString(from: defaultTintColor)
                                    }
                                }
                            )) {
                                Text("默认").tag(AppearancePreferences.TintMode.systemDefault.rawValue)
                                Text("自定义").tag(AppearancePreferences.TintMode.custom.rawValue)
                            }
                            .pickerStyle(.segmented)
                            .disabled(!tintEnabledBinding.wrappedValue)

                            if tintEnabledBinding.wrappedValue && activeTintMode == .custom {
                                HStack(spacing: 12) {
                                    ColorPicker(
                                        "",
                                        selection: Binding(
                                            get: { activeTintColor },
                                            set: { newValue in
                                                activeTintRaw = rgbaString(from: newValue, overrideAlpha: activeTintOpacity)
                                            }
                                        ),
                                        supportsOpacity: false
                                    )
                                    .labelsHidden()

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("透明度")
                                            Spacer()
                                            Text(String(format: "%.0f%%", activeTintOpacity * 100))
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        Slider(
                                            value: Binding(
                                                get: { activeTintOpacity },
                                                set: { newValue in
                                                    activeTintRaw = rgbaString(from: activeTintColor, overrideAlpha: newValue)
                                                }
                                            ),
                                            in: 0...1,
                                            step: 0.01
                                        )
                                        .controlSize(.small)
                                    }
                                }
                            } else if tintEnabledBinding.wrappedValue {
                                Text("默认：浅色模式白色 61.8% 透明度；深色模式黑色 61.8% 透明度。")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("已关闭色调，使用系统默认透明玻璃。")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // 圆角半径
                        LabeledSlider(
                            title: "搜索框圆角大小",
                            value: $cornerRadius,
                            range: 8...24,
                            step: 1,
                            unit: "pt"
                        )

                    }
                }

                SettingsSection("候选项外观") {
                    Picker("液态玻璃风格", selection: $rowGlassStyleRaw) {
                        Text("Regular").tag(AppearancePreferences.GlassStyle.regular.rawValue)
                        Text("Clear").tag(AppearancePreferences.GlassStyle.clear.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

                SettingsSection("过渡动画") {
                    LabeledSlider(
                        title: "候选项过渡速度",
                        value: $animationDuration,
                        range: 0.05...0.5,
                        step: 0.01,
                        unit: "s"
                    )

                    Divider()

                    Button {
                        if let delegate = NSApp.delegate as? AppDelegate {
                            delegate.openLiquidTuning()
                        }
                    } label: {
                        Label("调试液态玻璃…", systemImage: "paintbrush")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // 提示信息
            SettingsSection(note: "经典：轻度模糊。液态玻璃：macOS 26+ 原生效果，动态折射与高光。纯净：不透明背景。") {
                Text("选中的材质会应用到搜索面板背景。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func colorFromRGBA(_ raw: String) -> Color? {
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return Color(.sRGB, red: parts[0], green: parts[1], blue: parts[2], opacity: parts[3])
    }

    private func alphaFromRGBA(_ raw: String) -> Double? {
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return parts[3]
    }

    private func rgbaString(from color: Color, overrideAlpha: Double? = nil) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        let alpha = overrideAlpha ?? nsColor.alphaComponent
        return String(format: "%.3f,%.3f,%.3f,%.3f",
                      nsColor.redComponent,
                      nsColor.greenComponent,
                      nsColor.blueComponent,
                      alpha)
    }
}

// MARK: - 带标签的滑块控件
private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.2f", value) + unit)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
        }
    }
}
