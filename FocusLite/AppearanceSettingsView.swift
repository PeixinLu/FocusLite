import AppKit
import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(AppearancePreferences.materialStyleKey)
    private var materialStyleRaw = AppearancePreferences.MaterialStyle.liquid.rawValue
    @AppStorage(AppearancePreferences.glassStyleKey)
    private var glassStyleRaw = AppearancePreferences.GlassStyle.regular.rawValue
    @AppStorage(AppearancePreferences.glassTintKey)
    private var glassTintRaw = ""

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
            SettingsSection("材质") {
                Picker("材质", selection: $materialStyleRaw) {
                    Text("经典").tag(AppearancePreferences.MaterialStyle.classic.rawValue)
                    Text("液态玻璃").tag(AppearancePreferences.MaterialStyle.liquid.rawValue)
                    Text("纯净").tag(AppearancePreferences.MaterialStyle.pure.rawValue)
                }
                .pickerStyle(.segmented)
            }

            if materialStyle == .liquid {
                SettingsSection("液态玻璃参数") {
                    Picker("玻璃风格", selection: $glassStyleRaw) {
                        Text("Regular").tag(AppearancePreferences.GlassStyle.regular.rawValue)
                        Text("Clear").tag(AppearancePreferences.GlassStyle.clear.rawValue)
                    }
                    .pickerStyle(.segmented)

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
                }
            }

            SettingsSection(note: "经典：轻度模糊。液态玻璃：动态折射与高光。纯净：不透明背景。") {
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
}
