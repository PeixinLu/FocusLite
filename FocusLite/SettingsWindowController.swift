import Cocoa
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    func show(tab: SettingsTab = .general) {
        viewModel.selectedTab = tab
        createWindowIfNeeded()
        guard let window else {
            Log.info("Settings window was not created.")
            return
        }
        // 打开设置窗口时，切换到 regular 模式，显示 Dock 图标
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func close() {
        window?.close()
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: SettingsLayout.windowWidth,
            height: SettingsLayout.windowHeight
        )
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FocusLite 设置"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unifiedCompact
        }
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        let rootView = SettingsView(viewModel: self.viewModel)
        window.contentView = NSHostingView(rootView: rootView)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        // 关闭设置窗口时，切换回 accessory 模式，隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        window = nil
    }
}
