import AppKit
import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.MaterialStyle.liquid.rawValue
    @AppStorage(AppearancePreferences.glassStyleKey)
    private var glassStyleRaw = AppearancePreferences.GlassStyle.regular.rawValue
    @AppStorage(AppearancePreferences.glassTintKey)
    private var glassTintRaw = ""
    @AppStorage(AppearancePreferences.liquidGlassExtraBlurMaterialKey)
    private var extraBlurMaterialRaw = AppearancePreferences.ExtraBlurMaterial.system.rawValue
    
    // Liquid Glass 微调参数
    @AppStorage(AppearancePreferences.liquidGlassBlurRadiusKey)
    private var blurRadius = 30.0
    @AppStorage(AppearancePreferences.liquidGlassGradientStartOpacityKey)
    private var gradientStartOpacity = 0.45
    @AppStorage(AppearancePreferences.liquidGlassGradientEndOpacityKey)
    private var gradientEndOpacity = 0.14
    @AppStorage(AppearancePreferences.liquidGlassAnimationDurationKey)
    private var animationDuration = 0.18
    @AppStorage(AppearancePreferences.liquidGlassCornerRadiusKey)
    private var cornerRadius = 16.0
    
    @State private var showAdvancedSettings = false

    private var materialStyle: AppearancePreferences.MaterialStyle {
        AppearancePreferences.MaterialStyle(rawValue: materialStyleRaw) ?? .liquid
    }

    private var tintEnabledBinding: Binding<Bool> {
        Binding(
            get: { !glassTintRaw.isEmpty },
            set: { newValue in
                if newValue, glassTintRaw.isEmpty {
                    glassTintRaw = rgbaString(from: .white.opacity(0.2))
                }
                if !newValue {
                    glassTintRaw = ""
                }
            }
        )
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
                SettingsSection("液态玻璃基础参数") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 玻璃风格
                        Picker("玻璃风格", selection: $glassStyleRaw) {
                            Text("Regular").tag(AppearancePreferences.GlassStyle.regular.rawValue)
                            Text("Clear").tag(AppearancePreferences.GlassStyle.clear.rawValue)
                        }
                        .pickerStyle(.segmented)

                        Divider()
                        
                        // 色调
                        HStack(spacing: 12) {
                            Toggle("色调", isOn: tintEnabledBinding)
                            .toggleStyle(.switch)

                            ColorPicker(
                                "",
                                selection: Binding(
                                    get: { colorFromRGBA(glassTintRaw) ?? .white.opacity(0.2) },
                                    set: { glassTintRaw = rgbaString(from: $0) }
                                ),
                                supportsOpacity: true
                            )
                            .labelsHidden()
                            .disabled(!tintEnabledBinding.wrappedValue)

                            Spacer()
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
                
                // 高级调试参数（折叠）
                SettingsSection {
                    DisclosureGroup(
                        isExpanded: $showAdvancedSettings,
                        content: {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("这些参数用于精细调试 Liquid Glass 效果，调整到满意后会隐藏复杂选项。")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                                
                                Divider()
                                
                                // 高光与渐变
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("高光与渐变")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    
                                    LabeledSlider(
                                        title: "渐变起始透明度",
                                        value: $gradientStartOpacity,
                                        range: 0.0...1.0,
                                        step: 0.01,
                                        unit: ""
                                    )
                                    
                                    LabeledSlider(
                                        title: "渐变结束透明度",
                                        value: $gradientEndOpacity,
                                        range: 0.0...1.0,
                                        step: 0.01,
                                        unit: ""
                                    )
                                    
                                    LabeledSlider(
                                        title: "额外模糊强度",
                                        value: $blurRadius,
                                        range: 0...100,
                                        step: 1,
                                        unit: "%"
                                    )
                                    Picker("模糊材质", selection: $extraBlurMaterialRaw) {
                                        Text("系统").tag(AppearancePreferences.ExtraBlurMaterial.system.rawValue)
                                        Text("超薄").tag(AppearancePreferences.ExtraBlurMaterial.ultraThin.rawValue)
                                        Text("薄").tag(AppearancePreferences.ExtraBlurMaterial.thin.rawValue)
                                        Text("常规").tag(AppearancePreferences.ExtraBlurMaterial.regular.rawValue)
                                        Text("厚").tag(AppearancePreferences.ExtraBlurMaterial.thick.rawValue)
                                        Text("超厚").tag(AppearancePreferences.ExtraBlurMaterial.ultraThick.rawValue)
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                Divider()
                                
                                // 动画
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("动画")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    
                                    LabeledSlider(
                                        title: "候选项过渡动画时长",
                                        value: $animationDuration,
                                        range: 0.05...0.5,
                                        step: 0.01,
                                        unit: "s"
                                    )
                                }
                                
                                Divider()
                                
                                // 重置按钮
                                HStack {
                                    Spacer()
                                    Button("重置为默认值") {
                                        resetToDefaults()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("高级调试参数")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                            }
                        }
                    )
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

    private func rgbaString(from color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        return String(format: "%.3f,%.3f,%.3f,%.3f",
                      nsColor.redComponent,
                      nsColor.greenComponent,
                      nsColor.blueComponent,
                      nsColor.alphaComponent)
    }
    
    private func resetToDefaults() {
        gradientStartOpacity = 0.45
        gradientEndOpacity = 0.14
        blurRadius = 30.0
        extraBlurMaterialRaw = AppearancePreferences.ExtraBlurMaterial.system.rawValue
        animationDuration = 0.18
        cornerRadius = 16.0
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
