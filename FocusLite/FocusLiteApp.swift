import SwiftUI

@main
struct FocusLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        menuBarScene()
        Settings {
            SettingsView(viewModel: appDelegate.settingsViewModel)
        }
    }

    private func menuBarScene() -> some Scene {
        MenuBarExtra("FocusLite", systemImage: "magnifyingglass.circle.fill") {
            menuContent
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuContent: some View {
        Group {
            Button("进入 FocusLite 搜索") {
                appDelegate.toggleLauncherFromMenu()
            }
            Divider()
            Button("外观") {
                appDelegate.openStylePrefix()
            }
            Button("操作指引") {
                appDelegate.presentOnboarding()
            }
            Divider()
            if #available(macOS 14, *) {
                SettingsLink {
                    Text("偏好设置")
                }
                .keyboardShortcut(",", modifiers: .command)
                .simultaneousGesture(TapGesture().onEnded {
                    appDelegate.prepareSettingsTab(.general)
                })
            } else {
                Button("偏好设置") {
                    appDelegate.openSettingsFromMenu()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            Divider()
            Button("退出 FocusLite") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
