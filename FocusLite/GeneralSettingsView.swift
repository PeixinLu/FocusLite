import SwiftUI

#if arch(arm64)
import LaunchAtLogin
#else
import ServiceManagement
#endif

final class GeneralSettingsViewModel: ObservableObject {
    @Published var launchAtLoginEnabled: Bool
    @Published var launcherHotKeyText: String

    init() {
        launchAtLoginEnabled = LaunchAtLoginProvider.isEnabled
        launcherHotKeyText = GeneralPreferences.launcherHotKeyText
    }

    func applyChanges() {
        LaunchAtLoginProvider.isEnabled = launchAtLoginEnabled
        GeneralPreferences.launcherHotKeyText = launcherHotKeyText
    }
}

struct GeneralSettingsView: View {
    @StateObject var viewModel: GeneralSettingsViewModel
    let onSaved: (() -> Void)?

    init(viewModel: GeneralSettingsViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            header
                .padding(.bottom, SettingsLayout.headerBottomPadding)

            VStack(spacing: SettingsLayout.sectionSpacing) {
                SettingsSection("启动") {
                    SettingsFieldRow(title: "登录后自动启动") {
                        Toggle("", isOn: $viewModel.launchAtLoginEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: viewModel.launchAtLoginEnabled) { _ in
                                applyAndNotify()
                            }
                    }
                }

                SettingsSection(
                    "快捷键",
                    note: "必须包含 command/option/control 中的至少一个。示例：command+space 或 option+k。"
                ) {
                    SettingsFieldRow(title: "唤起搜索") {
                        HotKeyRecorderField(
                            text: $viewModel.launcherHotKeyText,
                            conflictHotKeys: [ClipboardPreferences.hotKeyText]
                        ) {
                            applyAndNotify()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("通用设置")
                .font(.system(size: 20, weight: .semibold))
            Text("配置唤起搜索框的全局快捷键。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func applyAndNotify() {
        viewModel.applyChanges()
        onSaved?()
    }
}

private enum LaunchAtLoginProvider {
    static var isEnabled: Bool {
        get {
            #if arch(arm64)
            LaunchAtLogin.isEnabled
            #else
            SMAppService.mainApp.status == .enabled
            #endif
        }
        set {
            #if arch(arm64)
            LaunchAtLogin.isEnabled = newValue
            #else
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                #if DEBUG
                print("Launch at login update failed: \(error.localizedDescription)")
                #endif
            }
            #endif
        }
    }
}
