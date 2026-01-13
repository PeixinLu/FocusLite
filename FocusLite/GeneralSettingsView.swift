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
                    note: "需包含 ⌘/⌥/⌃ 中至少一个。示例：⌥+Space 或 ⌥+K。"
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
